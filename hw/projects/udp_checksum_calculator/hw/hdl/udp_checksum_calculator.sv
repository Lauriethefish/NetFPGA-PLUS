// Buffers a packet and computes its checksum.
// NB is either buffering a packet or outputting the result, not both.
module udp_checksum_calculator
#(
    parameter C_M_AXIS_DATA_WIDTH=1024,
    parameter C_S_AXIS_DATA_WIDTH=1024,
    parameter C_M_AXIS_TUSER_WIDTH=128,
    parameter C_S_AXIS_TUSER_WIDTH=128,
    parameter BUFFER_SIZE=16
)
(
    // Global clock/reset
    input axis_aclk,
    // Active low
    input axis_resetn,

    // Master Stream Ports (write packet data)
    output [C_M_AXIS_DATA_WIDTH - 1:0] m_axis_tdata,
    output [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] m_axis_tkeep,
    output [C_M_AXIS_TUSER_WIDTH-1:0] m_axis_tuser,
    output m_axis_tvalid,
    input  m_axis_tready,
    output m_axis_tlast,

    // Slave Stream Ports (read packet data)
    input [C_S_AXIS_DATA_WIDTH - 1:0] s_axis_tdata,
    input [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_tkeep,
    input [C_S_AXIS_TUSER_WIDTH-1:0] s_axis_tuser,
    input  s_axis_tvalid,
    output s_axis_tready,
    input  s_axis_tlast,
    input [31:0] s_axis_checksum
);
    import inter_structs::*;

    // 0: waiting for data to form packet
    // 1: outputting packet data
    reg state;

    // Ready for data assuming we're still reading the packet
    assign s_axis_tready = state <= 1;

    reg [31:0] running_checksum;
    wire [31:0] trimmed_checksum;
    wire [31:0] trimmed_checksum_2;
    wire [15:0] final_checksum;

    // Each carry (i.e. the upper 16 bits) needs to be accounted for as a single
    // unit in the lower bits.
    assign trimmed_checksum = (32'((running_checksum[15:0])) + 32'((running_checksum[31:16])));
    assign trimmed_checksum_2 = ~(32'((trimmed_checksum[15:0])) + 32'((trimmed_checksum[31:16])));
    // If the computed checksum is 0, then we need to set it to FFFF as 0
    // indicates no checksum is present.
    assign final_checksum = |trimmed_checksum_2 ? trimmed_checksum_2 : 16'hffff;

    reg [$clog2(BUFFER_SIZE)-1:0] buffer_pos;
    reg [$clog2(BUFFER_SIZE)-1:0] buffer_len;
    reg [C_M_AXIS_DATA_WIDTH + (C_M_AXIS_DATA_WIDTH/8) + C_M_AXIS_TUSER_WIDTH:0]
        buffered_stream[BUFFER_SIZE-1:0];

    wire [C_M_AXIS_DATA_WIDTH/2 - 1:0] masked_tdata;
    genvar i;
    generate
        for(i = 0; i < C_M_AXIS_DATA_WIDTH/8/2; i++) begin
            assign masked_tdata[i*8+7:i*8] = s_axis_tkeep[i] ? s_axis_tdata[i*8+7:i*8] : 0;
        end
    endgenerate

    // NB: Need to use separate set of bits if doing the pseudoheader
    // calculation.
    wire udp_header tdata_udp_header;
    assign tdata_udp_header = {<<8{masked_tdata[$bits(udp_header)-1:0]}};

    wire udp_pseudo_header pseudo_header;
    assign pseudo_header = '{
        tdata_udp_header.ipv4.src_addr,
        tdata_udp_header.ipv4.dst_addr,
        8'b0,
        tdata_udp_header.ipv4.protocol,
        tdata_udp_header.length,
        tdata_udp_header.src_port,
        tdata_udp_header.dst_port,
        tdata_udp_header.length,
        16'b0 // Consider checksum as being 0 for calculation.
    };

    wire [$bits(udp_pseudo_header)-1:0] pseudo_header_bits;
    assign pseudo_header_bits = {<<8{pseudo_header}};

    localparam TRANS_SUM_WIDTH = 22;

    wire [TRANS_SUM_WIDTH-1:0] header_sum;
    wire [TRANS_SUM_WIDTH-1:0] header_sum_to_remove;

    // Sum up the header
    sum_16_bit_words 
    #(
        .DATA_START(0),
        .DATA_WIDTH($bits(udp_pseudo_header)),
        .INPUT_WIDTH($bits(udp_pseudo_header)),
        .OUTPUT_WIDTH(TRANS_SUM_WIDTH)
    )
    header_summer(
        .s_axis_tdata(pseudo_header_bits),
        .s_axis_tkeep('1),
        .sum(header_sum)
    );

    // Sum up the data in the area occupied by the pseudo header, as these
    // should not be included.
    sum_16_bit_words 
    #(
        .DATA_START(0),
        .DATA_WIDTH($bits(udp_header)),
        .INPUT_WIDTH($bits(udp_header)),
        .OUTPUT_WIDTH(TRANS_SUM_WIDTH)
    )
    header_placeholder_summer(
        .s_axis_tdata(s_axis_tdata[$bits(udp_header)-1:0]),
        .s_axis_tkeep('1),
        .sum(header_sum_to_remove)
    );

    // Work out what to use for computing checksum based upon whether this is the header transaction.
    wire is_udp_packet;
    assign is_udp_packet = (buffered_header.ipv4.protocol == 'd17);

    wire udp_header buffered_header;
    wire [C_M_AXIS_DATA_WIDTH - 1:0] buffered_tdata;
    wire [C_M_AXIS_DATA_WIDTH - 1:0] buffered_tdata_with_header_update;


    wire [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] buffered_tkeep;
    wire [C_M_AXIS_TUSER_WIDTH-1:0] buffered_tuser;
    assign {buffered_tdata, buffered_tkeep, buffered_tuser} = buffered_stream[buffer_pos];
    assign buffered_header = {<<8{buffered_tdata[$bits(udp_header)-1:0]}};

    wire udp_header checksum_set_header;
    wire [$bits(udp_header) - 1:0] checksum_set_header_bits;

    assign checksum_set_header = '{
        buffered_header.ether,
        buffered_header.ipv4,
        buffered_header.src_port,
        buffered_header.dst_port,
        buffered_header.length,
        final_checksum};
    assign checksum_set_header_bits = {<<8{checksum_set_header}};

    // Overwrite the header if this is the first transfer of the packet.
    assign buffered_tdata_with_header_update = (is_udp_packet && buffer_pos == 0) ?
        {buffered_tdata[C_M_AXIS_DATA_WIDTH - 1:$bits(udp_header)],checksum_set_header_bits}
        : buffered_tdata;

    // Output the data held in the buffer
    assign m_axis_tdata = buffered_tdata_with_header_update;
    assign m_axis_tuser = buffered_tuser;
    assign m_axis_tkeep = buffered_tkeep;
    // Valid if currently outputting the packet we have stored.
    assign m_axis_tvalid = state;
    assign m_axis_tlast = buffer_pos == buffer_len;

    // Use the already computed sum of the whole transaction
    // Account for the sum of the pseudo header, removing the sum of the header
    // that was over-accounted for.
    wire [31:0] transfer_checksum;
    assign transfer_checksum = s_axis_checksum + (buffer_pos == 0 ? header_sum - header_sum_to_remove : 0);

    always_ff @(posedge axis_aclk) begin
        if(!axis_resetn) begin
            state <= 0;
            buffer_pos <= 0;
            buffer_len <= 0;
            running_checksum <= 0;
        end else begin
            if(state == 0) begin
                if(s_axis_tvalid) begin
                    // Data transfer occurs
                    buffered_stream[buffer_pos] <= {s_axis_tdata, s_axis_tkeep, s_axis_tuser};
                    buffer_pos <= buffer_pos + 1;
                    // Add contribution to the checksum.
                    // NOTE: the header is different and we need to deal with this fact.
                    running_checksum <= running_checksum + transfer_checksum;

                    // If this is the last packet, then next time, we're in sending mode
                    if(s_axis_tlast) begin
                        state <= 1;
                        buffer_len <= buffer_pos;
                        buffer_pos <= 0;
                    end
                end
            end else begin
                // Check if a transfer is going to occur
                if(m_axis_tready && m_axis_tvalid) begin
                    if(buffer_pos == buffer_len) begin
                        // At the end of the buffer, move back to receiving mode
                        state <= 0;
                        buffer_len <= 0;
                        buffer_pos <= 0;
                        running_checksum <= 0;
                    end else begin
                        // Not at the end, move to the next transfer
                        buffer_pos <= buffer_pos + 1;
                    end
                end
            end
        end
    end
endmodule