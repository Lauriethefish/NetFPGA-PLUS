`define C_M_AXIS_DATA_WIDTH 512
`define C_S_AXIS_DATA_WIDTH 512
`define C_M_AXIS_TUSER_WIDTH 128
`define C_S_AXIS_TUSER_WIDTH 128

// Total width of ethernet/IP/UDP header stack in bytes
`define UDP_HEADERS_SIZE 42

module udp_splitter
(
    // Global clock/reset
    input axis_aclk,
    // Active low
    input axis_resetn,

    // Master Stream Ports (write packet data)
    output reg [`C_M_AXIS_DATA_WIDTH - 1:0] m_axis_tdata,
    output reg [((`C_M_AXIS_DATA_WIDTH / 8)) - 1:0] m_axis_tkeep,
    output reg [`C_M_AXIS_TUSER_WIDTH-1:0] m_axis_tuser,
    output reg m_axis_tvalid,
    input  m_axis_tready,
    output reg m_axis_tlast,

    // Slave Stream Ports (read packet data)
    input [`C_S_AXIS_DATA_WIDTH - 1:0] s_axis_tdata,
    input [((`C_S_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_tkeep,
    input [`C_S_AXIS_TUSER_WIDTH-1:0] s_axis_tuser,
    input  s_axis_tvalid,
    output s_axis_tready,
    input  s_axis_tlast
);
    import inter_structs::*;

    parameter BUFFER_LENTH_WIDTH_BITS = $clog2(`C_M_AXIS_DATA_WIDTH/8);

    // INPUT BUFFERING

    // Maintain two buffers of the tdata.
    // Occasionally, lookahead into the other buffer will be needed
    // to maximize the output throughput.
    reg [`C_M_AXIS_DATA_WIDTH - 1:0] tdata_buf_high;
    reg [BUFFER_LENTH_WIDTH_BITS-1:0] buf_high_bytes;

    reg [`C_M_AXIS_DATA_WIDTH - 1:0] tdata_buf_low;
    reg [BUFFER_LENTH_WIDTH_BITS-1:0] buf_low_bytes;

    // Number of bytes the next stage would like to remove from the two
    // buffers.
    wire [BUFFER_LENTH_WIDTH_BITS:0] buf_take_bytes;
    wire [BUFFER_LENTH_WIDTH_BITS-1:0] buf_take_bytes_low;
    wire [BUFFER_LENTH_WIDTH_BITS-1:0] buf_take_bytes_high;

    // Work out how many bytes to take from each buffer.
    assign buf_take_bytes_low = buf_take_bytes > `C_M_AXIS_DATA_WIDTH/8
        ? `C_M_AXIS_DATA_WIDTH/8 : buf_take_bytes;

    assign buf_take_bytes_high = buf_take_bytes > `C_M_AXIS_DATA_WIDTH/8
        ? buf_take_bytes - `C_M_AXIS_DATA_WIDTH/8 : 0;

    wire have_enough_buffered;
    assign have_enough_buffered = buf_take_bytes_low >= buf_low_bytes
        && buf_take_bytes_high > buf_high_bytes;

    wire empty_low, empty_high;
    assign empty_low = buf_take_bytes_low == buf_low_bytes;
    assign empty_high = buf_take_bytes_high == buf_high_bytes;

    // NB empty_high is always true if empty_low is true.
    assign m_axis_tready = empty_high;
    

    always_ff @(posedge axis_aclk) begin
        if(!axis_resetn) begin
            buf_low_bytes <= '0;
            buf_high_bytes <= '0;
            tdata_buf_high <= '0;
            tdata_buf_low <= '0;
        end else begin
            if(m_axis_tready && m_axis_tvalid) begin
                // TODO compute size information
                if(empty_low) begin
                    tdata_buf_low <= m_axis_tdata;
                    buf_low_bytes <= $countones(m_axis_tkeep);
                    // Implication is that high buffer is empty if we're dumping
                    // into low buffer
                    buf_high_bytes <= '0;
                end else if(empty_high) begin
                    tdata_buf_high <= m_axis_tdata;
                    buf_high_bytes <= $countones(m_axis_tkeep);
                end

                // TODO: work out how many bytes actually remaining based
                // upon how many taken.
            end
        end
    end

    reg [15:0] bytes_left_in_segment;
    reg is_new_segment;
    reg is_new_packet;

    always_ff @(posedge axis_aclk) begin
        if(!axis_resetn) begin
            is_new_segment <= 1'b1;
            is_new_packet <= 1'b1;
            bytes_left_in_segment <= '0;
        end else begin
            
        end
    end




endmodule