

module udp_port_change
#(
    // Master/slave AXI Stream Data Width
    parameter int C_M_AXIS_DATA_WIDTH=512,
    parameter int C_S_AXIS_DATA_WIDTH=512,
    parameter int C_M_AXIS_TUSER_WIDTH=128,
    parameter int C_S_AXIS_TUSER_WIDTH=128,

    parameter int IPV4_HEADER_SIZE=160,
    parameter int UDP_HEADER_SIZE=64
)
(
    // Global clock/reset
    input axis_aclk,
    input axis_resetn,

    // Master Stream Ports (write packet data)
    output [C_M_AXIS_DATA_WIDTH-1 : 0] m_axis_tdata,
    output [((C_M_AXIS_DATA_WIDTH / 8)) - 1 : 0] m_axis_tkeep,
    output [C_M_AXIS_TUSER_WIDTH-1 : 0] m_axis_tuser,
    output m_axis_tvalid,
    input  m_axis_tready,
    output m_axis_tlast,

    // Slave Stream Ports (read packet data)
    input [C_S_AXIS_DATA_WIDTH-1 : 0] s_axis_tdata,
    input [((C_S_AXIS_DATA_WIDTH / 8)) - 1 : 0] s_axis_tkeep,
    input [C_S_AXIS_TUSER_WIDTH-1 : 0] s_axis_tuser,
    input  s_axis_tvalid,
    output s_axis_tready,
    input  s_axis_tlast
);
    assign m_axis_tdata = s_axis_tdata;
    assign m_axis_tkeep = s_axis_tkeep;
    assign m_axis_tuser = s_axis_tuser;
    assign m_axis_tvalid = s_axis_tvalid;
    assign s_axis_tready = m_axis_tready;
    assign m_axis_tlast = s_axis_tlast;
endmodule