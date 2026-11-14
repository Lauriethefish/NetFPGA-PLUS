// Single-stream simulation harness, following udp_segmentation.
`timescale 1ns / 1ps

module top_sim (
    input axis_aclk,
    input axis_resetn
);
    wire [511:0] axis_i_tdata, axis_o_tdata;
    wire [63:0] axis_i_tkeep, axis_o_tkeep;
    wire [127:0] axis_i_tuser, axis_o_tuser;
    wire axis_i_tvalid, axis_o_tvalid;
    wire axis_i_tready, axis_o_tready;
    wire axis_i_tlast, axis_o_tlast;
    wire [31:0] packet_count;
    wire barrier_req;

    quic_encrypt dut (
        .axis_aclk(axis_aclk),
        .axis_resetn(axis_resetn),
        .s_axis_tdata(axis_i_tdata),
        .s_axis_tkeep(axis_i_tkeep),
        .s_axis_tuser(axis_i_tuser),
        .s_axis_tvalid(axis_i_tvalid),
        .s_axis_tready(axis_i_tready),
        .s_axis_tlast(axis_i_tlast),
        .m_axis_tdata(axis_o_tdata),
        .m_axis_tkeep(axis_o_tkeep),
        .m_axis_tuser(axis_o_tuser),
        .m_axis_tvalid(axis_o_tvalid),
        .m_axis_tready(axis_o_tready),
        .m_axis_tlast(axis_o_tlast)
    );

    axis_sim_stim_ip0 stimulus (
        .ACLK(axis_aclk),
        .ARESETN(axis_resetn),
        .M_AXIS_TDATA(axis_i_tdata),
        .M_AXIS_TKEEP(axis_i_tkeep),
        .M_AXIS_TUSER(axis_i_tuser),
        .M_AXIS_TVALID(axis_i_tvalid),
        .M_AXIS_TREADY(axis_i_tready),
        .M_AXIS_TLAST(axis_i_tlast),
        .counter(packet_count[10:0]),
        .activity_stim(),
        .barrier_req(barrier_req),
        .barrier_proceed(barrier_req)
    );

    axis_sim_record_ip0 recorder (
        .axi_aclk(axis_aclk),
        .s_axis_tdata(axis_o_tdata),
        .s_axis_tkeep(axis_o_tkeep),
        .s_axis_tuser(axis_o_tuser),
        .s_axis_tvalid(axis_o_tvalid),
        .s_axis_tready(axis_o_tready),
        .s_axis_tlast(axis_o_tlast),
        .counter(packet_count),
        .activity_rec()
    );
endmodule
