`define C_M_AXIS_DATA_WIDTH 512
`define C_S_AXIS_DATA_WIDTH 512
`define C_M_AXIS_TUSER_WIDTH 128
`define C_S_AXIS_TUSER_WIDTH 128

// Total width of ethernet/IP/UDP header stack in bytes
`define UDP_HEADERS_SIZE 42

module udp_segmentor
(
    // Global clock/reset
    input axis_aclk,
    // Active low
    input axis_resetn,

    // Master Stream Ports (write packet data)
    output [`C_M_AXIS_DATA_WIDTH - 1:0] m_axis_tdata,
    output [((`C_M_AXIS_DATA_WIDTH / 8)) - 1:0] m_axis_tkeep,
    output [`C_M_AXIS_TUSER_WIDTH-1:0] m_axis_tuser,
    output m_axis_tvalid,
    input  m_axis_tready,
    output m_axis_tlast,

    // Slave Stream Ports (read packet data)
    // Register these inputs
    // And compute checksum of the first half
    input [`C_S_AXIS_DATA_WIDTH - 1:0] s_axis_tdata,
    input [((`C_S_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_tkeep,
    input [`C_S_AXIS_TUSER_WIDTH-1:0] s_axis_tuser,
    input  s_axis_tvalid,
    output s_axis_tready,
    input  s_axis_tlast
);

    wire [`C_M_AXIS_DATA_WIDTH - 1:0] split_axis_tdata;
    wire [((`C_M_AXIS_DATA_WIDTH / 8)) - 1:0] split_axis_tkeep;
    wire [`C_M_AXIS_TUSER_WIDTH-1:0] split_axis_tuser;
    wire split_axis_tvalid;
    wire split_axis_tready;
    wire split_axis_tlast;

    // First split into segments, then recompute IP headers on the result.
    // UDP checksum calculation comes later.
    udp_splitter split
    (
        .axis_aclk(axis_aclk),
        .axis_resetn(axis_resetn),

        .m_axis_tdata(split_axis_tdata),
        .m_axis_tkeep(split_axis_tkeep),
        .m_axis_tuser(split_axis_tuser),
        .m_axis_tvalid(split_axis_tvalid),
        .m_axis_tready(split_axis_tready),
        .m_axis_tlast(split_axis_tlast),

        .s_axis_tdata(s_axis_tdata),
        .s_axis_tkeep(s_axis_tkeep),
        .s_axis_tuser(s_axis_tuser),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast)
    );

    ip_header_calc header_calc
    (
        .axis_aclk(axis_aclk),
        .axis_resetn(axis_resetn),

        .m_axis_tdata(m_axis_tdata),
        .m_axis_tkeep(m_axis_tkeep),
        .m_axis_tuser(m_axis_tuser),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast),

        .s_axis_tdata(split_axis_tdata),
        .s_axis_tkeep(split_axis_tkeep),
        .s_axis_tuser(split_axis_tuser),
        .s_axis_tvalid(split_axis_tvalid),
        .s_axis_tready(split_axis_tready),
        .s_axis_tlast(split_axis_tlast)
    );
endmodule