

typedef struct packed {
  logic [6*8-1:0] dst_addr;
  logic [6*8-1:0] src_addr;
  logic [15:0] ethertype;
} ether_header;

typedef struct packed {
  logic [3:0] version;
  logic [3:0] ihl;
  logic [5:0] dscp;
  logic [1:0] ecn;
  logic [15:0] total_length;
  logic [15:0] identification;
  logic [2:0] flags;
  logic [12:0] frag_offset;
  logic [7:0] ttl;
  logic [7:0] protocol;
  logic [15:0] header_checksum;
  logic [31:0] src_addr;
} ipv4_header;

typedef struct packed {
    ether_header ether;
    ipv4_header ipv4;
    logic [15:0] src_port;
    logic [15:0] dst_port;
    logic [15:0] length;
    logic [15:0] checksum;
} udp_header;

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
    // Active low
    input axis_resetn,

    // Master Stream Ports (write packet data)
    output reg [C_M_AXIS_DATA_WIDTH - 1:0] m_axis_tdata,
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
    wire should_use_modified_packet;

    wire udp_header s_udp_header;
    wire udp_header port_fixed_udp_header;
    wire [C_M_AXIS_DATA_WIDTH - 1:0] s_data_modified;

    wire [15:0] udp_src_port;
    wire [15:0] udp_dest_port;
    wire [15:0] udp_len;
    wire [15:0] udp_checksum;

    wire [512-IPV4_HEADER_SIZE-UDP_HEADER_SIZE-1:0] payload;

    // Starting a new packet if the last packet was terminating
    // Note we set tlast on reset.
    // Then should only modify the headers if this is a UDP packet
    assign should_use_modified_packet = m_axis_tlast && s_udp_header.ipv4.protocol == 17;

    // Extract UDP header from the data
    assign s_udp_header = {<<8{s_axis_tdata[$bits(udp_header)-1:0]}};
    assign port_fixed_udp_header = '{
        s_udp_header.ether,
        s_udp_header.ipv4,
        s_udp_header.src_port,
        100,
        s_udp_header.length,
        s_udp_header.checksum};

    // Data assuming we make our modifications to the headers
    assign s_data_modified = {s_axis_tdata[C_S_AXIS_DATA_WIDTH-1:$bits(udp_header)], {<<8{port_fixed_udp_header}}};

    // Change port number

    // Ready for more data if:
    // - Downstream ready for more data
    // - No data currently held.
    assign s_axis_tready = m_axis_tready || !m_axis_tvalid;
    

    always_ff @(posedge axis_aclk) begin
        if(axis_resetn) begin // Check not resetting
            // In order to change the data going out, downstream needs
            // to be ready, unless this is the first transfer i.e. we're not
            // valid yetm_axis_tready
            if((!m_axis_tvalid || m_axis_tready) && s_axis_tvalid) begin
                m_axis_tdata <= should_use_modified_packet ? s_data_modified : s_axis_tdata;
                m_axis_tuser <= s_axis_tuser;
                m_axis_tkeep <= s_axis_tkeep;
                m_axis_tlast <= s_axis_tlast;
                m_axis_tvalid <= 1; // Ready for next stage to read this data
            end else if(m_axis_tvalid && m_axis_tready) begin
                // Downstream just read the data but nothing came in to replace
                // it, thus we have nothing.
                m_axis_tvalid <= 0;
            end
        end else begin
            // Output data not valid if we're resetting.
            m_axis_tvalid <= 0;
            // Next transfer is the first transfer within a packet.
            m_axis_tlast <= 1;
        end
    end

endmodule