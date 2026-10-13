// Buffers a packet and computes its checksum.
// NB is either buffering a packet or outputting the result, not both.
module udp_checksum_calculator
#(
    parameter C_M_AXIS_DATA_WIDTH=512,
    parameter C_S_AXIS_DATA_WIDTH=512,
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
    output reg m_axis_tvalid,
    input  m_axis_tready,
    output reg m_axis_tlast,

    // Slave Stream Ports (read packet data)
    input [C_S_AXIS_DATA_WIDTH - 1:0] s_axis_tdata,
    input [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_tkeep,
    input [C_S_AXIS_TUSER_WIDTH-1:0] s_axis_tuser,
    input  s_axis_tvalid,
    output s_axis_tready,
    input  s_axis_tlast
);
    // 0: waiting for data to form packet
    // 1: outputting packet data
    reg state;

    // Ready for data assuming we're still reading the packet
    assign s_axis_tready = state <= 1;

    reg [31:0] running_checksum;
    wire [15:0] trimmed_checksum;
    wire [15:0] final_checksum;

    // Each carry (i.e. the upper 16 bits) needs to be accounted for as a single
    // unit in the lower bits.
    assign trimmed_checksum = (running_checksum & 16'hffff) + (running_checksum[31:16]);
    // If the computed checksum is 0, then we need to set it to FFFF as 0
    // indicates no checksum is present.
    assign final_checksum = |trimmed_checksum ? trimmed_checksum : 16'hffff;

    reg [$clog2(BUFFER_SIZE)-1:0] buffer_pos;
    reg [$clog2(BUFFER_SIZE)-1:0] buffer_len;
    reg [C_M_AXIS_DATA_WIDTH + (C_M_AXIS_DATA_WIDTH/8) + C_M_AXIS_TUSER_WIDTH:0]
        buffered_stream[BUFFER_SIZE-1:0];

    wire [C_M_AXIS_DATA_WIDTH - 1:0] masked_tdata;
    generate
        for(i = 0; i < C_M_AXIS_DATA_WIDTH/8; i++) begin
            assign masked_tdata[i*8+7:i*8] = s_axis_tkeep[i] ? s_axis_tdata[i*8+7:i*8] : 0;
        end
    endgenerate


    wire udp_header buffered_header;
    wire [C_M_AXIS_DATA_WIDTH - 1:0] buffered_tdata;
    wire [C_M_AXIS_DATA_WIDTH - 1:0] buffered_tdata_with_header_update;


    wire [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] buffered_tkeep;
    wire [C_M_AXIS_TUSER_WIDTH-1:0] buffered_tuser;
    assign {buffered_tdata, buffered_tkeep, buffered_tuser} = buffered_stream[buffer_pos];
    assign buffered_header = {<<8{buffered_tdata[$bits(udp_header)-1:0]}};

    assign checksum_set_header = '{
        buffered_header.ether,
        buffered_header.ipv4,
        buffered_header.src_port,
        buffered_header.dst_port,
        buffered_header.length,
        final_checksum};
    assign checksum_set_header_bits = {<<8{checksum_set_header}};

    // Overwrite the header if this is the first transfer of the packet.
    assign buffered_tdata_with_header_update = buffer_pos == 0 ?
        {buffered_tdata[C_M_AXIS_DATA_WIDTH - 1:$bits(udp_header)],checksum_set_header_bits}
        : buffered_tdata;

    // Output the data held in the buffer
    assign m_axis_tdata = buffered_tdata_with_header_update;
    assign m_axis_tuser = buffered_tuser;
    assign m_axis_tkeep = buffered_tkeep;
    // Valid if currently outputting the packet we have stored.
    assign m_axis_tvalid = state;

    // Computing the checksum of the data
    // 128 bits is 8x16 bit words. We add all these words up
    // Datapath is 1024 bits wide
    // So need to add up 8 of these words
    wire [31:0] segment_sums [C_M_AXIS_DATA_WIDTH/128];
    wire [31:0] transfer_checksum;

    generate
        for(i = 0; i < C_M_AXIS_DATA_WIDTH/128; i++) begin
            // Select each of the 16 bit blocks and sum them up
            // Noting that the 8 bit blocks need to be reshuffled due to bit order.
            assign segment_sums[i] =  {<<8{masked_tdata[i*128+16*1-1: i*128+16*0]}} +
                + {<<8{masked_tdata[i*128+16*2-1: i*128+16*1]}}
                + {<<8{masked_tdata[i*128+16*3-1: i*128+16*2]}}
                + {<<8{masked_tdata[i*128+16*4-1: i*128+16*3]}}
                + {<<8{masked_tdata[i*128+16*5-1: i*128+16*4]}}
                + {<<8{masked_tdata[i*128+16*6-1: i*128+16*5]}}
                + {<<8{masked_tdata[i*128+16*7-1: i*128+16*6]}}
                + {<<8{masked_tdata[i*128+16*8-1: i*128+16*7]}};
        end
    endgenerate

    // Sum all the individual checksums to get the transfer checksum
    assign transfer_checksum = segment_sums[0]
        + segment_sums[1]
        + segment_sums[2]
        + segment_sums[3]
        + segment_sums[4]
        + segment_sums[5]
        + segment_sums[6]
        + segment_sums[7];

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
                end
                // If this is the last packet, then next time, we're in sending mode
                if(s_axis_tlast) begin
                    state <= 1;
                    buffer_len <= buffer_pos;
                    buffer_pos <= 0;
                end
            end else begin
                // Check if a transfer is going to occur
                if(m_axis_tready && m_axis_tvalid) begin
                    if(buffer_pos == buffer_len) begin
                        // At the end of the buffer, move back to receiving mode
                        state <= 0;
                        buffer_len <= 0;
                        buffer_pos <= 0;
                    end else begin
                        // Not at the end, move to the next transfer
                        buffer_pos <= buffer_pos + 1;
                    end
                end
            end
        end
    end
endmodule