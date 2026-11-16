// QUIC encryption pipeline scaffold. Encryption is not implemented yet.
// Preserve the 512-bit AXI-stream interface used by udp_segmentation.
`timescale 1ns / 1ps

module quic_encrypt #(
    parameter C_AXIS_DATA_WIDTH = 512,
    parameter C_AXIS_TUSER_WIDTH = 128
) (
    input axis_aclk,
    input axis_resetn,

    input [C_AXIS_DATA_WIDTH-1:0] s_axis_tdata,
    input [C_AXIS_DATA_WIDTH/8-1:0] s_axis_tkeep,
    input [C_AXIS_TUSER_WIDTH-1:0] s_axis_tuser,
    input [7:0] s_axis_dcid_length,
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
    localparam AES_BLOCK_SIZE=128;

    // Lengths of crypto parameters in bytes.
    localparam NONCE_LENGTH=12;
    localparam KEY_LENGTH=16;

    // Constant parameters for now. TODO: Wire these in from cryptographic
    // parameter storage.
    wire [KEY_LENGTH*8-1:0] key = 'd4;
    wire [NONCE_LENGTH*8-1:0] packet_protection_iv = 'd5;

    // Length of the Ether + IP + UDP headers.
    localparam PRE_QUIC_HEADERS_LEN=42;
    // Destination connection ID length: in the future, this will have to come
    // from tuser as it can vary with each connection.
    localparam DCID_LENGTH=8;

    // 1 byte for flags, 160 bit DCID, max 4 byte packet number
    localparam MAX_QUIC_HEADERS_LEN=1+20+4;
    localparam MAX_ALL_QUIC_HEADERS_LEN=
        MAX_QUIC_HEADERS_LEN+PRE_QUIC_HEADERS_LEN;

    // After Ether + IP + UDP headers, we get to QUIC headers.

    reg got_first_transfer_of_headers;
    reg [MAX_ALL_QUIC_HEADERS_LEN-1:0] headers_buf;
    reg [MAX_ALL_QUIC_HEADERS_LEN/8-1:0] headers_keep;
    wire [7:0] packet_type = {<<8{headers_buf[7:0]}};
    // RFC 9000. 17.3.1.
    wire is_1rtt = (packet_type & 8'b11011000) == 8'b01000000;
    wire [2:0] packet_number_length_bytes = (packet_type & 2'b11) + 1;

    localparam PACKET_NUMBER_POS = 8 + DCID_LENGTH*8;
    wire [31:0] packet_number_raw = headers_buf[PACKET_NUMBER_POS+31:PACKET_NUMBER_POS];
    // Mask out the packet number depending on the length field
    wire [31:0] packet_number = packet_number_raw[7:0]
        | (packet_number_length_bytes > 1 ? packet_number[15:8] : 0)
        | (packet_number_length_bytes > 2 ? packet_number[23:16] : 0)
        | (packet_number_length_bytes > 3 ? packet_number[31:24] : 0);


    wire [7:0] true_header_len = PRE_QUIC_HEADERS_LEN
        + 1 // flags
        + packet_number_length_bytes
        + DCID_LENGTH;


    wire [7:0] header_data_left = true_header_len - got_first_transfer_of_headers * C_AXIS_DATA_WIDTH/8;
    wire is_last_header_transfer = header_data_left < C_AXIS_DATA_WIDTH;

    // Leave enough space for an extra AES buffer's worth of data.
    wire packet_buf_take_block;

    reg got_last_transfer;

    localparam PACKET_BUF_SIZE_BITS = C_AXIS_DATA_WIDTH + AES_BLOCK_SIZE;
    reg [PACKET_BUF_SIZE_BITS-1:0] packet_buf;
    reg [PACKET_BUF_SIZE_BITS/8-1:0] packet_buf_keep;
    
    reg [7:0] packet_buf_amt_valid;

    typedef enum {READING_HEADERS, KEY_LOAD, IV_LOAD, POST_IV_LOAD, PENDING, ADATA_LOAD,
    CONTENTS_LOAD, WAIT_OUTPUT_TAG} e_state;
    e_state reg state;

    // TODO: Double check this condition is always correct!
    assign s_axis_tready = state == READING_HEADERS
        || (packet_buf_amt_valid <= 16);
    

    // INPUT BUFFERING
    always_ff @(posedge axis_aclk) begin
        if(!axis_resetn) begin
            headers_buf <= '0;
            headers_keep <= '0;
            got_first_transfer_of_headers <= '0;
            got_last_transfer <= '0;
            packet_buf <= '0;
            packet_buf_amt_valid <= '0;
            packet_buf_keep <= '0;
            state <= READING_HEADERS;
        end else begin
            if(s_axis_tready && s_axis_tvalid) begin
                if(s_axis_tlast) begin
                    got_last_transfer <= 1'b1;
                end

                if(state == READING_HEADERS) begin
                    // Put remaining data into packet buffer
                    if(is_last_header_transfer) begin
                        packet_buf <= s_axis_tdata[C_AXIS_DATA_WIDTH-1:
                                header_data_left*8];
                        packet_buf_keep <= s_axis_tkeep[C_AXIS_DATA_WIDTH/8-1:header_data_left];
                        packet_buf_amt_valid <= C_AXIS_DATA_WIDTH/8 - header_data_left;
                    end

                    headers_buf <= got_first_transfer_of_headers ?
                        (headers_buf | s_axis_tdata << C_AXIS_DATA_WIDTH)
                        : s_axis_tdata;

                    got_first_transfer_of_headers <= 1'b1;
                end else begin
                    // Buffer new data and shift out old data
                    packet_buf <= (packet_buf | (s_axis_tdata << packet_buf_amt_valid*8)) >>
                        (packet_buf_take_block*AES_BLOCK_SIZE);
                    packet_buf_keep <= (packet_buf_keep | (s_axis_tkeep << packet_buf_amt_valid))
                        >> (packet_buf_take_block*AES_BLOCK_SIZE/8);

                    packet_buf_amt_valid <= packet_buf_amt_valid
                        + $countones(s_axis_tkeep) - packet_buf_take_block*16;
                end
                // Shift out header data
                if(state == ADATA_LOAD) begin
                    headers_buf >> AES_BLOCK_SIZE;
                    headers_keep >> AES_BLOCK_SIZE/8;
                end
            end
           
        end
    end


    // Compute cryptographic parameters
    wire [12*8-1:0] nonce = packet_protection_iv ^ packet_number;
    // key is constant

    wire aes_gcm_ready;

    always_ff @(posedge axis_aclk) begin
        if(!axis_resetn) begin
            state <= WAIT_INPUT;
        end else begin
            if(state == READING_HEADERS) begin
                if(s_axis_tvalid) begin
                    if(is_last_header_transfer) begin
                        headers_keep <= (1 << true_header_len) - 1;
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
            end
        end
    end

    // AES authenticated data for QUIC 1-RTT packets is the unprotected 
    // (short) packet header (RFC 9001, 5.3)

    top_aes_gcm aes_gcm (
        .rst_i(!axis_resetn),
        .clk_i(axis_aclk),
        .aes_gcm_enc_dec_i(0), // Encryption mode
        .aes_gcm_pipe_reset_i(0), // Set in between packets.
        .aes_gcm_key_word_val_i(key),
        .aes_gcm_key_word_i(state == KEY_LOAD), /* TODO introduce state as to whether loading key currently */
        .aes_gcm_iv_val_i(nonce),
        .aes_gcm_iv_i(state == IV_LOAD), /* TODO: as above but for nonce */
        .aes_gcm_icb_start_cnt_i(state == POST_IV_LOAD),
        .aes_gcm_icb_stop_cnt_i(0'b0), // TODO: work out when need to assert this
        .aes_gcm_ghash_pkt_val_i(state == ADATA_LOAD || state == CONTENTS_LOAD),
        .aes_gcm_ghash_aad_bval_i({<<1{headers_keep[AES_BLOCK_SIZE/8-1:0]}}),
        .aes_gcm_ghash_aad_i({<<8{headers_buf[AES_BLOCK_SIZE-1:0]}}),
        .aes_gcm_data_in_bval_i({<<8{packet_buf[AES_BLOCK_SIZE-1:0]}}),
        .aes_gcm_data_in_i({<<1{packet_buf_keep[AES_BLOCK_SIZE-1:0]}}),
        .aes_gcm_ready_o(aes_gcm_ready),
        .aes_gcm_data_out_val_o(),
        .aes_gcm_data_out_bval_o(),
        .aes_gcm_data_out_o(),
        .aes_gcm_ghash_tag_val_o(),
        .aes_gcm_ghash_tag_o(),
        .aes_gcm_icb_cnt_overflow_o()
    );
endmodule
