// QUIC encryption pipeline scaffold. Encryption is not implemented yet.
// Preserve the 512-bit AXI-stream interface used by udp_segmentation.
`timescale 1ns / 1ps

// Carries out QUIC payload protection on a packet, using AES-GCM AEAD
module quic_payload_protect #(
    parameter C_AXIS_DATA_WIDTH = 512,
    parameter C_AXIS_TUSER_WIDTH = 128
) (
    input axis_aclk,
    input axis_resetn,

    input [C_AXIS_DATA_WIDTH-1:0] s_axis_tdata,
    input [C_AXIS_DATA_WIDTH/8-1:0] s_axis_tkeep,
    input [C_AXIS_TUSER_WIDTH-1:0] s_axis_tuser,
    input s_axis_tvalid,
    output s_axis_tready,
    input s_axis_tlast,

    output [C_AXIS_DATA_WIDTH-1:0] m_axis_tdata,
    output [C_AXIS_DATA_WIDTH/8-1:0] m_axis_tkeep,
    output [C_AXIS_TUSER_WIDTH-1:0] m_axis_tuser,
    output m_axis_tvalid,
    input m_axis_tready,
    output m_axis_tlast
);
    import inter_structs::*;

    localparam unsigned ETHER_MTU = 1500;
    localparam unsigned FIFO_DEPTH = 1 << $clog2(ETHER_MTU/(C_AXIS_DATA_WIDTH/8) + 1);
    localparam unsigned AES_BLOCK_SIZE=128;

    // Lengths of crypto parameters in bytes.
    localparam unsigned NONCE_LENGTH=12;
    localparam unsigned KEY_LENGTH=16;

    // Constant parameters for now. TODO: Wire these in from cryptographic
    // parameter storage.
    wire [KEY_LENGTH*8-1:0] key = 'd4;
    wire [NONCE_LENGTH*8-1:0] packet_protection_iv = 'd5;

    // Length of the Ether + IP + UDP headers.
    localparam unsigned PRE_QUIC_HEADERS_LEN=42;
    // Destination connection ID length: in the future, this will have to come
    // from tuser as it can vary with each connection.
    localparam unsigned DCID_LENGTH=8;
    wire [7:0] dcid_length = 8'(DCID_LENGTH);

    // 1 byte for flags, 160 bit DCID, max 4 byte packet number
    localparam unsigned MAX_QUIC_HEADERS_LEN=1+20+4;
    localparam unsigned MAX_ALL_QUIC_HEADERS_LEN=
        MAX_QUIC_HEADERS_LEN+PRE_QUIC_HEADERS_LEN;


    // UDP/IP HEADER MODIFICATIONS
    wire [PRE_QUIC_HEADERS_LEN*8-1:0] pre_quic_headers_order_fixed =
        {<<8{s_axis_tdata[PRE_QUIC_HEADERS_LEN*8-1:0]}};

    wire udp_header pre_quic_headers = pre_quic_headers_order_fixed;
    wire udp_header pre_quic_headers_size_updated = '{
        ether: pre_quic_headers.ether,
        ipv4: '{
            version: pre_quic_headers.ipv4.version,
            ihl: pre_quic_headers.ipv4.ihl,
            dscp: pre_quic_headers.ipv4.dscp,
            ecn: pre_quic_headers.ipv4.ecn,
            total_length: pre_quic_headers.ipv4.total_length + AES_BLOCK_SIZE/8,
            identification: pre_quic_headers.ipv4.identification,
            flags: pre_quic_headers.ipv4.flags,
            frag_offset: pre_quic_headers.ipv4.frag_offset,
            ttl: pre_quic_headers.ipv4.ttl,
            protocol: pre_quic_headers.ipv4.protocol,
            // Computed later
            header_checksum: '0,
            src_addr: pre_quic_headers.ipv4.src_addr,
            dst_addr: pre_quic_headers.ipv4.dst_addr 
        },
        src_port: pre_quic_headers.src_port,
        dst_port: pre_quic_headers.dst_port,
        length: pre_quic_headers.length + AES_BLOCK_SIZE/8,
        // Computed later
        checksum: '0
    };

    wire [PRE_QUIC_HEADERS_LEN*8-1:0] pre_quic_headers_size_updated_raw =
        {<<8{pre_quic_headers_size_updated}};

    wire [C_AXIS_DATA_WIDTH-1:0] s_axis_tdata_updated_headers =
        {s_axis_tdata[C_AXIS_DATA_WIDTH-1:PRE_QUIC_HEADERS_LEN*8], pre_quic_headers_size_updated_raw};


    reg [15:0] tuser_packet_size;
    reg is_first_output_transfer;

    assign m_axis_tuser = is_first_output_transfer ? tuser_packet_size : '0;

    reg got_first_transfer_of_headers;
    reg [MAX_ALL_QUIC_HEADERS_LEN*8-1:0] headers_buf;
    reg [MAX_ALL_QUIC_HEADERS_LEN-1:0] headers_keep;
    wire [7:0] packet_type = {<<8{headers_buf[7:0]}};
    // RFC 9000. 17.3.1.
    wire [2:0] packet_number_length_bytes = 3'((packet_type & 2'b11) + 1);

    localparam PACKET_NUMBER_POS = 8 + DCID_LENGTH*8;
    wire [31:0] packet_number_raw = headers_buf[PACKET_NUMBER_POS+31:PACKET_NUMBER_POS];
    // Mask out the packet number depending on the length field
    wire [31:0] packet_number = packet_number_raw[7:0]
        | (packet_number_length_bytes > 1 ? packet_number[15:8] : 0)
        | (packet_number_length_bytes > 2 ? packet_number[23:16] : 0)
        | (packet_number_length_bytes > 3 ? packet_number[31:24] : 0);


    wire [7:0] true_header_len = 8'(PRE_QUIC_HEADERS_LEN)
        + 8'b1 // flags
        + 8'(packet_number_length_bytes)
        + dcid_length;


    wire [7:0] header_data_left = 8'(true_header_len - got_first_transfer_of_headers * C_AXIS_DATA_WIDTH/8);
    wire is_last_header_transfer = header_data_left < C_AXIS_DATA_WIDTH;

    // Leave enough space for an extra AES buffer's worth of data.
    wire packet_buf_take_block;

    reg got_last_transfer;

    localparam PACKET_BUF_SIZE_BITS = C_AXIS_DATA_WIDTH + AES_BLOCK_SIZE;
    reg [PACKET_BUF_SIZE_BITS-1:0] packet_buf;
    reg [PACKET_BUF_SIZE_BITS/8-1:0] packet_buf_keep;

    wire fifo_empty;
    assign m_axis_tvalid = !fifo_empty;
    
    reg [7:0] packet_buf_amt_valid;
    typedef enum logic [3:0] {READING_HEADERS, KEY_LOAD, IV_LOAD, POST_IV_LOAD, PENDING, ADATA_LOAD,
    CONTENTS_LOAD, WAIT_OUTPUT_TAG, RESETTING} e_state;
    e_state state;

    // TODO: Double check this condition is always correct!
    assign s_axis_tready = (state == READING_HEADERS
        || (packet_buf_amt_valid <= 16))
        && !got_last_transfer; // prevent next packet from entering until reset.
    
    // Take a block from the packet buffer if:
    // - We are loading packet contents
    // - (There is a whole block to take)
    // - OR (We have received the whole packet data)
    assign packet_buf_take_block = state == CONTENTS_LOAD &&
        (packet_buf_amt_valid >= AES_BLOCK_SIZE/8 || got_last_transfer);

    // OUTPUT BUFFERING
    // The output is provided in terms of 16 byte blocks
    // We shift these into a larger C_AXIS_DATA_WIDTH buffer before outputting
    // complete transfers.
    localparam OUTPUT_BUF_SIZE = MAX_QUIC_HEADERS_LEN*8 > C_AXIS_DATA_WIDTH+AES_BLOCK_SIZE ?
        MAX_QUIC_HEADERS_LEN*8 : C_AXIS_DATA_WIDTH+AES_BLOCK_SIZE;
    reg [OUTPUT_BUF_SIZE-1:0] m_axis_tdata_buf;
    reg [OUTPUT_BUF_SIZE/8-1:0] m_axis_tkeep_buf;
    wire [OUTPUT_BUF_SIZE-1:0] m_axis_tkeep_buf_expanded;
    generate
        for(genvar i = 0; i < OUTPUT_BUF_SIZE/8; i++) begin
           assign m_axis_tkeep_buf_expanded[i*8+7:i*8] = {8{m_axis_tkeep_buf[i]}};
        end
    endgenerate

    reg [7:0] m_axis_tdata_data_amt;
    reg got_all_output_data;
    // True if the current clock cycle will empty the output queue.
    wire end_of_packet = got_all_output_data && fifo_empty;

    wire [C_AXIS_DATA_WIDTH-1:0] m_axis_tdata_fifo_in;
    wire [C_AXIS_DATA_WIDTH/8-1:0] m_axis_tkeep_fifo_in;
    wire m_axis_tlast_fifo_in;
    wire fifo_wr_en;

    assign m_axis_tdata_fifo_in = m_axis_tdata_buf[C_AXIS_DATA_WIDTH-1:0];
    assign m_axis_tkeep_fifo_in = m_axis_tkeep_buf[C_AXIS_DATA_WIDTH/8-1:0];
    // If got_all_output_data holds, then the final tag is buffered
    // Therefore if we also have *no more data after this transfer*, then it is last. 
    assign m_axis_tlast_fifo_in = got_all_output_data && (m_axis_tkeep_buf[C_AXIS_DATA_WIDTH/8] == 0);

    assign fifo_wr_en = (m_axis_tdata_data_amt >= C_AXIS_DATA_WIDTH/8)
        || (got_all_output_data && m_axis_tdata_data_amt > 0);

    // Output from the AES GCM IP
    wire [AES_BLOCK_SIZE-1:0] next_out_block_tdata;
    wire [AES_BLOCK_SIZE/8-1:0] next_out_block_tkeep;

    wire [AES_BLOCK_SIZE-1:0] next_out_block_tdata_reordered = {<<8{next_out_block_tdata}};
    wire [AES_BLOCK_SIZE/8-1:0] next_out_block_tkeep_reordered = {<<1{next_out_block_tkeep}};

    wire [7:0] next_out_block_data_amt = $countones(next_out_block_tkeep);

    always_ff @(posedge axis_aclk) begin
        if(!axis_resetn || end_of_packet) begin
            m_axis_tdata_buf <= '0;
            m_axis_tkeep_buf <= '0;
            m_axis_tdata_data_amt <= '0;
            is_first_output_transfer <= 1'b1;
        end else begin
            if(m_axis_tready && m_axis_tvalid) begin
                is_first_output_transfer <= 1'b0;
            end

            // Trim excess data according to the amount in the buffer
            if(state == IV_LOAD) begin
                m_axis_tdata_buf <= m_axis_tdata_buf & m_axis_tkeep_buf_expanded;
            end else
            if(s_axis_tready && s_axis_tvalid && state == READING_HEADERS) begin
                // Enqueue header data for output.
                // Ensure we update the checksums to 0, and the size to the
                // new payload length, including the tag
                m_axis_tdata_buf <= 
                    got_first_transfer_of_headers ?
                        // Second transfer is part of the QUIC headers, leave these unchanged
                        (headers_buf | s_axis_tdata << C_AXIS_DATA_WIDTH)
                        : s_axis_tdata_updated_headers;

                if(is_last_header_transfer) begin
                    m_axis_tdata_data_amt <= true_header_len;
                    m_axis_tkeep_buf <= (1 << true_header_len) - 1;
                end
            end

            // TODO: no means of backpressure on the AES IP!
            // Need to add an output buffer on this IP anyway (AES IP is slow), so this can provide the backpressure.
            else if(fifo_wr_en) begin
                // Shift out old data and insert new data, if there is any
                m_axis_tdata_buf <= (m_axis_tdata_buf >> C_AXIS_DATA_WIDTH)
                    | (next_out_block_tdata_reordered << (m_axis_tdata_data_amt*8-C_AXIS_DATA_WIDTH));
                m_axis_tkeep_buf <= (m_axis_tkeep_buf >> C_AXIS_DATA_WIDTH/8)
                    | (next_out_block_tkeep_reordered << (m_axis_tdata_data_amt-C_AXIS_DATA_WIDTH/8));
                m_axis_tdata_data_amt <= (m_axis_tdata_data_amt > C_AXIS_DATA_WIDTH/8 ? (m_axis_tdata_data_amt - C_AXIS_DATA_WIDTH/8)
                    : 0) + next_out_block_data_amt;
            end else begin
                m_axis_tdata_buf <= m_axis_tdata_buf | (next_out_block_tdata_reordered << m_axis_tdata_data_amt*8);
                m_axis_tkeep_buf <= m_axis_tkeep_buf | (next_out_block_tkeep_reordered << m_axis_tdata_data_amt);
                m_axis_tdata_data_amt <= m_axis_tdata_data_amt + next_out_block_data_amt;
            end
        end
    end

    // INPUT BUFFERING
    always_ff @(posedge axis_aclk) begin
        if(!axis_resetn || end_of_packet) begin
            headers_buf <= '0;
            headers_keep <= '0;
            got_first_transfer_of_headers <= '0;
            got_last_transfer <= '0;
            packet_buf <= '0;
            packet_buf_amt_valid <= '0;
            packet_buf_keep <= '0;
            tuser_packet_size <= '0;
        end else begin
            if(s_axis_tready && s_axis_tvalid) begin
                if(s_axis_tlast) begin
                    got_last_transfer <= 1'b1;
                end

                if(state == READING_HEADERS) begin
                    // Put remaining data into packet buffer
                    if(is_last_header_transfer) begin
                        packet_buf <= s_axis_tdata >> header_data_left*8;
                        packet_buf_keep <= s_axis_tkeep >> header_data_left;
                        packet_buf_amt_valid <= 8'(C_AXIS_DATA_WIDTH/8) - header_data_left;
                        headers_keep <= (1 << true_header_len - PRE_QUIC_HEADERS_LEN) - 1;
                    end
                    // Extract packet size from tuser.
                    if(!got_first_transfer_of_headers) begin
                        tuser_packet_size <= s_axis_tuser[15:0] + AES_BLOCK_SIZE/8;
                    end

                    // Erase non-QUIC headers: these aren't used in the associated data.
                    headers_buf <= got_first_transfer_of_headers ?
                        (headers_buf | s_axis_tdata << PRE_QUIC_HEADERS_LEN*8)
                        : (s_axis_tdata >> PRE_QUIC_HEADERS_LEN*8);

                    got_first_transfer_of_headers <= 1'b1;
                end else begin
                    // Buffer new data and shift out old data
                    // TODO: These ORs aren't really correct
                    packet_buf <= (packet_buf | (s_axis_tdata << packet_buf_amt_valid*8)) >>
                        (packet_buf_take_block*AES_BLOCK_SIZE);
                    packet_buf_keep <= (packet_buf_keep | (s_axis_tkeep << packet_buf_amt_valid))
                        >> (packet_buf_take_block*AES_BLOCK_SIZE/8);

                    packet_buf_amt_valid <= packet_buf_amt_valid
                        + 8'($countones(s_axis_tkeep)) - packet_buf_take_block*16;
                end
            end else if(packet_buf_take_block) begin
                // Still allow data to be taken from buffer if no more coming in.
                packet_buf <= packet_buf >> AES_BLOCK_SIZE;
                packet_buf_keep <= packet_buf_keep >> AES_BLOCK_SIZE/8;
            end

            // Shift out header data
            if(state == ADATA_LOAD) begin
                headers_buf <= headers_buf >> AES_BLOCK_SIZE;
                headers_keep <= headers_keep >> AES_BLOCK_SIZE/8;
            end
        end
    end

    


    // Compute cryptographic parameters
    wire [12*8-1:0] nonce = packet_protection_iv ^ packet_number;
    // key is constant

    wire aes_gcm_ready;

    // AES authenticated data for QUIC 1-RTT packets is the unprotected 
    // (short) packet header (RFC 9001, 5.3)

    wire [AES_BLOCK_SIZE/8-1:0] data_in_bval_tkeep = {<<1{packet_buf_keep[AES_BLOCK_SIZE/8-1:0]}};

    wire [AES_BLOCK_SIZE-1:0] gcm_data_out;
    wire [AES_BLOCK_SIZE-1:0] gcm_tag_out;

    wire [AES_BLOCK_SIZE/8-1:0] gcm_data_out_keep;
    wire [AES_BLOCK_SIZE-1:0] gcm_data_out_keep_expanded;

    generate
        for(genvar i = 0; i < AES_BLOCK_SIZE/8; i++) begin
           assign gcm_data_out_keep_expanded[i*8+7:i*8] = {8{gcm_data_out_keep[i]}};
        end
    endgenerate

    wire gcm_data_out_val;
    wire gcm_tag_out_val;

    assign next_out_block_tdata = gcm_tag_out_val ? gcm_tag_out :
        (gcm_data_out & gcm_data_out_keep_expanded);
    assign next_out_block_tkeep = gcm_tag_out_val ? '1 : gcm_data_out_keep;

    always_ff @(posedge axis_aclk) begin
        if(!axis_resetn || end_of_packet) begin
            state <= READING_HEADERS;
            got_all_output_data <= 1'b0;
        end else begin
            if(state == READING_HEADERS) begin
                if(s_axis_tvalid) begin
                    if(is_last_header_transfer) begin
                        state <= KEY_LOAD;
                    end else begin
                        state <= READING_HEADERS;
                    end                    
                end
            end else if(state == KEY_LOAD) begin
                // Just loaded the key, now load the IV
                state <= IV_LOAD;
            end else if(state == IV_LOAD) begin
                state <= POST_IV_LOAD;
            end else if(state == POST_IV_LOAD) begin
                state <= PENDING;
                // Now waiting for the AES GCM IP to assert aes_gcm_ready_o.
            end else if(state == PENDING) begin
                if(aes_gcm_ready) begin
                    state <= ADATA_LOAD;
                end
            end else if(state == ADATA_LOAD) begin
                if(headers_keep == '0) begin // No more header to insert
                    state <= CONTENTS_LOAD;
                end
            end else if(state == CONTENTS_LOAD) begin 
                // When no more packet data, wait for 
                if(got_last_transfer && packet_buf_keep == '0) begin 
                    state <= WAIT_OUTPUT_TAG;
                end
            end else if(state == WAIT_OUTPUT_TAG) begin
                if(gcm_tag_out_val) begin
                    got_all_output_data <= 1'b1;
                    state <= RESETTING;
                end
            end
        end
    end

    wire [AES_BLOCK_SIZE-1:0] aes_gcm_aad_in = {<<8{headers_buf[AES_BLOCK_SIZE-1:0]}};
    wire [AES_BLOCK_SIZE-1:0] aes_gcm_data_in = {<<8{packet_buf[AES_BLOCK_SIZE-1:0]}};
    wire [AES_BLOCK_SIZE/8-1:0] aes_gcm_aad_in_v = {<<1{headers_keep[AES_BLOCK_SIZE/8-1:0]}};

    top_aes_gcm aes_gcm (
        .rst_i(!axis_resetn || (state == RESETTING)),
        .clk_i(axis_aclk),
        .aes_gcm_enc_dec_i(0), // Encryption mode
        .aes_gcm_pipe_reset_i(0), // Set in between packets.
        .aes_gcm_key_word_val_i((state == KEY_LOAD) * 4'b0100),
        .aes_gcm_key_word_i({key, 128'b0}), /* TODO introduce state as to whether loading key currently */
        .aes_gcm_iv_val_i(state == IV_LOAD),
        .aes_gcm_iv_i(nonce), /* TODO: as above but for nonce */
        .aes_gcm_icb_start_cnt_i(state == POST_IV_LOAD),
        .aes_gcm_icb_stop_cnt_i(1'b0), // TODO: work out when need to assert this
        .aes_gcm_ghash_pkt_val_i(state == ADATA_LOAD || state == CONTENTS_LOAD),
        .aes_gcm_ghash_aad_bval_i(aes_gcm_aad_in_v*(state == ADATA_LOAD)),
        .aes_gcm_ghash_aad_i(aes_gcm_aad_in),
        .aes_gcm_data_in_bval_i(data_in_bval_tkeep*packet_buf_take_block),
        .aes_gcm_data_in_i(aes_gcm_data_in),
        .aes_gcm_ready_o(aes_gcm_ready),
        .aes_gcm_data_out_val_o(gcm_data_out_val),
        .aes_gcm_data_out_bval_o(gcm_data_out_keep),
        .aes_gcm_data_out_o(gcm_data_out),
        .aes_gcm_ghash_tag_val_o(gcm_tag_out_val),
        .aes_gcm_ghash_tag_o(gcm_tag_out),
        .aes_gcm_icb_cnt_overflow_o() // TODO: need to connect this? probably not.
    );

    // Buffer the output in a FIFO
    // One of these modules only has (at most) 1/4 the throughput of the NFPlus
    // datapath. Therefore buffer the output so we can provide a whole output
    // packet in one rapid burst. The bursts from multiple of these modules
    // will be interleaved to produce the output packet stream.
    xpm_fifo_sync # (
       .FIFO_WRITE_DEPTH    (FIFO_DEPTH),
       .WRITE_DATA_WIDTH    (C_AXIS_DATA_WIDTH+C_AXIS_DATA_WIDTH/8+1),
       .PROG_FULL_THRESH    (FIFO_DEPTH - 5),
       .READ_MODE           ("FWFT"),
       .FIFO_READ_LATENCY   (0),
       .READ_DATA_WIDTH     (C_AXIS_DATA_WIDTH+C_AXIS_DATA_WIDTH/8+1)
    ) output_fifo (
       .sleep            (1'b0),
       .rst              (!axis_resetn),
       .wr_clk           (axis_aclk),
       .wr_en            (fifo_wr_en),
       .din              ({m_axis_tdata_fifo_in, m_axis_tkeep_fifo_in, m_axis_tlast_fifo_in}),
       .full             (), /* Should never happen, if it does happen, panic? */
       .prog_full        (), // TODO: maybe track with an AXI-Lite register?
       .wr_data_count    (),
       .overflow         (),
       .wr_rst_busy      (),
       .rd_en            (m_axis_tready),
       .dout             ({m_axis_tdata, m_axis_tkeep, m_axis_tlast}),
       .data_valid       (),
       .empty            (fifo_empty),
       .prog_empty       (),
       .rd_data_count    (),
       .underflow        (),
       .rd_rst_busy      (),
       .injectsbiterr    (1'b0),
       .injectdbiterr    (1'b0),
       .sbiterr          (),
       .dbiterr          ()
    );
endmodule
