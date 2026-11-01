`define C_M_AXIS_DATA_WIDTH 512
`define C_S_AXIS_DATA_WIDTH 512
`define C_M_AXIS_TUSER_WIDTH 128
`define C_S_AXIS_TUSER_WIDTH 128

module udp_set_checksum
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
    wire [`C_S_AXIS_DATA_WIDTH - 1:0] s_axis_tdata_buf;
    wire [$bits(inter_structs::udp_header):0] s_axis_orig_header_buf;
    wire [((`C_S_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_tkeep_buf;
    wire [`C_S_AXIS_TUSER_WIDTH-1:0] s_axis_tuser_buf;
    wire  s_axis_tvalid_buf;
    wire  s_axis_tlast_buf;
    wire [31:0] s_axis_checksum_buf;
    wire s_axis_tready_buf;

    import inter_structs::*;

    udp_tree_summer
    #(
        .C_M_AXIS_DATA_WIDTH(`C_M_AXIS_DATA_WIDTH),
        .C_S_AXIS_DATA_WIDTH(`C_S_AXIS_DATA_WIDTH),
        .C_M_AXIS_TUSER_WIDTH(`C_M_AXIS_TUSER_WIDTH),
        .C_S_AXIS_TUSER_WIDTH(`C_S_AXIS_TUSER_WIDTH)
    )
    summer
    (
        .axis_aclk(axis_aclk),
        .axis_resetn(axis_resetn),

        .m_axis_tdata(s_axis_tdata_buf),
        .m_axis_orig_header(s_axis_orig_header_buf),
        .m_axis_tkeep(s_axis_tkeep_buf),
        .m_axis_tuser(s_axis_tuser_buf),
        .m_axis_tvalid(s_axis_tvalid_buf),
        .m_axis_tready(s_axis_tready_buf),
        .m_axis_tlast(s_axis_tlast_buf),
        .m_axis_checksum(s_axis_checksum_buf),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tkeep(s_axis_tkeep),
        .s_axis_tuser(s_axis_tuser),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast)
    );

    udp_checksum_calculator
    #(
      .C_M_AXIS_DATA_WIDTH (`C_M_AXIS_DATA_WIDTH),
      .C_S_AXIS_DATA_WIDTH (`C_S_AXIS_DATA_WIDTH),
      .C_M_AXIS_TUSER_WIDTH (`C_M_AXIS_TUSER_WIDTH),
      .C_S_AXIS_TUSER_WIDTH (`C_M_AXIS_TUSER_WIDTH)
    )
    chksum_calc
    (
        .axis_aclk(axis_aclk),
        .axis_resetn(axis_resetn),

        .m_axis_tdata(m_axis_tdata),
        .m_axis_tkeep(m_axis_tkeep),
        .m_axis_tuser(m_axis_tuser),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast),

        .s_axis_tdata(s_axis_tdata_buf),
        .s_axis_orig_header(s_axis_orig_header_buf),
        .s_axis_tkeep(s_axis_tkeep_buf),
        .s_axis_tuser(s_axis_tuser_buf),
        .s_axis_tvalid(s_axis_tvalid_buf),
        .s_axis_tready(s_axis_tready_buf),
        .s_axis_tlast(s_axis_tlast_buf),
        .s_axis_checksum(s_axis_checksum_buf)
    );
endmodule