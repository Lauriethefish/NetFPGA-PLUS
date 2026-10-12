

module udp_port_change
#(
    // Master/slave AXI Stream Data Width
    parameter C_M_AXIS_DATA_WIDTH=512,
    parameter C_S_AXIS_DATA_WIDTH=512,
    parameter C_M_AXIS_TUSER_WIDTH=128,
    parameter C_S_AXIS_TUSER_WIDTH=128,

    parameter IPV4_HEADER_SIZE=160,
    parameter UDP_HEADER_SIZE=64
)
(
    // Global clock/reset
    input axis_aclk,
    input axis_resetn,

    // Master Stream Ports (write packet data)
    output reg [C_M_AXIS_DATA_WIDTH - 1:0] m_axis_tdata,
    output reg [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] m_axis_tkeep,
    output reg [C_M_AXIS_TUSER_WIDTH-1:0] m_axis_tuser,
    output m_axis_tvalid,
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
    // Records if this is the first transfer in the packet
    reg is_first_in_packet;

    wire [IPV4_HEADER_SIZE-1:0] ipv4_header;
    wire [7:0] ipv4_protocol;

    wire [UDP_HEADER_SIZE:0] udp_header;
    wire [15:0] udp_src_port;
    wire [15:0] udp_dest_port;
    wire [15:0] udp_len;
    wire [15:0] udp_checksum;

    wire [512-IPV4_HEADER_SIZE-UDP_HEADER_SIZE-1:0] payload;

    // Extract IPv4 header and protocol
    assign ipv4_header = m_axis_tdata[C_M_AXIS_DATA_WIDTH-1:C_M_AXIS_DATA_WIDTH-IPV4_HEADER_SIZE];
    assign ipv4_protocol = ipv4_header[87:80];

    // Extract the UDP header
    assign udp_header = m_axis_tdata[C_M_AXIS_DATA_WIDTH-IPV4_HEADER_SIZE-1:C_M_AXIS_DATA_WIDTH-IPV4_HEADER_SIZE-UDP_HEADER_SIZE];
    assign {udp_src_port, udp_dest_port, udp_len, udp_checksum} = udp_header;

    assign payload = m_axis_tdata[C_M_AXIS_DATA_WIDTH-IPV4_HEADER_SIZE-UDP_HEADER_SIZE-1:0];

    // Always ready/valid if the next stage is.
    assign m_axis_tvalid = s_axis_tvalid;
    assign s_axis_tready = m_axis_tready;
    

    always_ff @(posedge axis_aclk) begin
        if(m_axis_tready && s_axis_tvalid && !axis_resetn) begin
            // Data transfer occurs assuming both ready and valid.
            m_axis_tdata <= s_axis_tdata;
            m_axis_tuser <= s_axis_tuser;
            m_axis_tkeep <= s_axis_tkeep;
            m_axis_tlast <= s_axis_tlast;
        end

        is_first_in_packet <= s_axis_tvalid && s_axis_tlast;        
    end

endmodule