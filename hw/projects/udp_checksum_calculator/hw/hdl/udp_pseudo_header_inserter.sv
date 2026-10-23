
// Rewires the first transaction of a UDP packet to contain the UDP pseudo
// header instead of the standard UDP header, zeroing out the leftover space
// as the standard header is larger.
// The standard header is passed along the pipeline separately and reintegrated
// later on.
module udp_pseudo_header_inserter
#(
    parameter C_M_AXIS_DATA_WIDTH=1024,
    parameter C_S_AXIS_DATA_WIDTH=1024,
    parameter C_M_AXIS_TUSER_WIDTH=128,
    parameter C_S_AXIS_TUSER_WIDTH=128
)
(
    // Global clock/reset
    input axis_aclk,
    // Active low
    input axis_resetn,

    // Master Stream Ports (write packet data)
    output reg [C_M_AXIS_DATA_WIDTH - 1:0] m_axis_tdata,
    // NOTE: highest bit is 1 if the pseudo header has been replaced.
    // Otherwise it is 0.
    output reg [$bits(inter_structs::udp_header):0] m_axis_orig_header,
    output reg [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] m_axis_tkeep,
    output reg [C_M_AXIS_TUSER_WIDTH-1:0] m_axis_tuser,
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
    import inter_structs::*;

    reg is_first_transfer;

    assign s_axis_tready = !m_axis_tvalid || m_axis_tready;

    wire [$bits(udp_header)-1:0] s_axis_orig_header;
    assign s_axis_orig_header = s_axis_tdata[$bits(udp_header)-1:0];

    wire udp_header header;
    assign header = {<<8{s_axis_orig_header}};

    wire is_udp_packet;
    assign is_udp_packet = (header.ipv4.protocol == 'd17);

    wire udp_pseudo_header pseudo_header;
    assign pseudo_header = '{
        header.ipv4.src_addr,
        header.ipv4.dst_addr,
        8'b0,
        header.ipv4.protocol,
        header.length,
        header.src_port,
        header.dst_port,
        header.length,
        16'b0 // Consider checksum as being 0 for calculation.
    };

    wire [$bits(udp_pseudo_header)-1:0] pseudo_header_bits;
    assign pseudo_header_bits = {<<8{pseudo_header}};

    wire [$bits(udp_header) - $bits(udp_pseudo_header)-1:0] zeroes_padding;
    assign zeroes_padding = '0;

    wire [C_M_AXIS_DATA_WIDTH-1:0] s_axis_tdata_with_pseudo_header;
    assign s_axis_tdata_with_pseudo_header = 
        {s_axis_tdata[C_M_AXIS_DATA_WIDTH-1:$bits(udp_header)], zeroes_padding, pseudo_header_bits};
    
    always_ff @(posedge axis_aclk) begin
        if(axis_resetn) begin
            // No reset
            if(s_axis_tready && s_axis_tvalid) begin
                // Copy all the data.
                m_axis_tdata <= (is_first_transfer && is_udp_packet) ? s_axis_tdata_with_pseudo_header : s_axis_tdata;
                m_axis_orig_header <= {(is_first_transfer && is_udp_packet) ? 1 : 0, s_axis_orig_header};
                m_axis_tkeep <= s_axis_tkeep;
                m_axis_tuser <= s_axis_tuser;
                m_axis_tvalid <= s_axis_tvalid;
                m_axis_tlast <= s_axis_tlast;
                is_first_transfer <= s_axis_tlast;
            end

            // Lost data from the buffer.
            if(m_axis_tready && !s_axis_tvalid) begin
                m_axis_tvalid <= 0;
            end

        end else begin
            // Reset
            m_axis_tvalid <= 0;
            is_first_transfer <= 1;
        end
    end

endmodule