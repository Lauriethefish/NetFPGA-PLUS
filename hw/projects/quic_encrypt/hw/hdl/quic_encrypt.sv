
`timescale 1ns / 1ps

module quic_encrypt #(
    parameter C_AXIS_DATA_WIDTH = 512,
    parameter C_AXIS_TUSER_WIDTH = 128
) (
    input axis_aclk,
    input axis_resetn,

    input [C_AXIS_DATA_WIDTH-1:0] s_axis_tdata,
    input [C_AXIS_DATA_WIDTH/8-1:0] s_axis_tkeep,
    input [C_AXIS_TUSER_WIDTH-1:0] s_axis_tuser,
    input s_axis_tvalid,
    output s_axis_tready,
    input s_axis_tlast,

    output [C_AXIS_DATA_WIDTH-1:0] m_axis_tdata,
    output [C_AXIS_DATA_WIDTH/8-1:0] m_axis_tkeep,
    output [C_AXIS_TUSER_WIDTH-1:0] m_axis_tuser,
    output m_axis_tvalid,
    input m_axis_tready,
    output m_axis_tlast
);
    localparam ETHER_MTU=1500;
    localparam unsigned FIFO_DEPTH = 1 << $clog2(ETHER_MTU/(C_AXIS_DATA_WIDTH/8) + 1);

    // AEAD operations run at a lower clock speed as the AES GCM IP is only
    // so fast.
    wire aead_clk;
    BUFGCE_DIV #(.BUFGCE_DIVIDE(2)) divider (
        .I(axis_aclk),
        .CE(1'b1),
        .CLR(1'b0),
        .O(aead_clk)
    );
    wire aead_resetp;
    wire aead_resetn = ~aead_resetp;
    xpm_cdc_sync_rst #(.DEST_SYNC_FF(4)) reset_slow_sync (
        .src_rst(~axis_resetn),
        .dest_clk(aead_clk),
        .dest_rst(aead_resetp)
    );

    wire [C_AXIS_DATA_WIDTH-1:0]   in_buf_tdata;
    wire [C_AXIS_DATA_WIDTH/8-1:0] in_buf_tkeep;
    wire [C_AXIS_TUSER_WIDTH-1:0]  in_buf_tuser;
    wire                           in_buf_tlast;
    wire                           in_buf_tready;
    wire                           in_buf_tvalid;

    wire [C_AXIS_DATA_WIDTH-1:0]   aead_tdata;
    wire [C_AXIS_DATA_WIDTH/8-1:0] aead_tkeep;
    wire [C_AXIS_TUSER_WIDTH-1:0]  aead_tuser;
    wire                           aead_tlast;
    wire                           aead_tready;
    wire                           aead_tvalid;

    wire [C_AXIS_DATA_WIDTH-1:0]   post_aead_tdata;
    wire [C_AXIS_DATA_WIDTH/8-1:0] post_aead_tkeep;
    wire [C_AXIS_TUSER_WIDTH-1:0]  post_aead_tuser;
    wire                           post_aead_tlast;
    wire                           post_aead_tready;
    wire                           post_aead_tvalid;

    wire [C_AXIS_DATA_WIDTH-1:0]   out_buf_tdata;
    wire [C_AXIS_DATA_WIDTH/8-1:0] out_buf_tkeep;
    wire [C_AXIS_TUSER_WIDTH-1:0]  out_buf_tuser;
    wire                           out_buf_tlast;
    wire                           out_buf_tready;
    wire                           out_buf_tvalid;

    // Input buffer for one packet

    wire in_fifo_full;
    assign s_axis_tready = !in_fifo_full;
    
    wire in_fifo_empty;
    assign in_buf_tvalid = ~in_fifo_empty;

    xpm_fifo_sync # (
       .FIFO_WRITE_DEPTH    (FIFO_DEPTH),
       .WRITE_DATA_WIDTH    (C_AXIS_DATA_WIDTH+C_AXIS_DATA_WIDTH/8+C_AXIS_TUSER_WIDTH+1),
       .PROG_FULL_THRESH    (FIFO_DEPTH - 5),
       .READ_MODE           ("FWFT"),
       .FIFO_READ_LATENCY   (0),
       .READ_DATA_WIDTH     (C_AXIS_DATA_WIDTH+C_AXIS_DATA_WIDTH/8+C_AXIS_TUSER_WIDTH+1)
    ) input_fifo (
       .sleep            (1'b0),
       .rst              (!axis_resetn),
       .wr_clk           (axis_aclk),
       .wr_en            (s_axis_tvalid && s_axis_tready),
       .din              ({s_axis_tdata, s_axis_tkeep, s_axis_tuser, s_axis_tlast}),
       .full             (in_fifo_full), /* Should never happen, if it does happen, panic? */
       .prog_full        (), // TODO: maybe track with an AXI-Lite register?
       .wr_data_count    (),
       .overflow         (),
       .wr_rst_busy      (),
       .rd_en            (in_buf_tvalid && in_buf_tready),
       .dout             ({in_buf_tdata, in_buf_tkeep, in_buf_tuser, in_buf_tlast}),
       .data_valid       (),
       .empty            (in_fifo_empty),
       .prog_empty       (),
       .rd_data_count    (),
       .underflow        (),
       .rd_rst_busy      (),
       .injectsbiterr    (1'b0),
       .injectdbiterr    (1'b0),
       .sbiterr          (),
       .dbiterr          ()
    );

    axis_clock_converter_high_to_low high_to_low(
        .s_axis_aclk   (axis_aclk),
        .s_axis_aresetn(axis_resetn),
        .s_axis_tdata  (in_buf_tdata),
        .s_axis_tready (in_buf_tready),
        .s_axis_tkeep  (in_buf_tkeep),
        .s_axis_tuser  (in_buf_tuser),
        .s_axis_tvalid (in_buf_tvalid),
        .s_axis_tlast  (in_buf_tlast),

        .m_axis_aclk(aead_clk),
        .m_axis_aresetn(aead_resetn),
        .m_axis_tdata(aead_tdata),
        .m_axis_tready(aead_tready),
        .m_axis_tkeep(aead_tkeep),
        .m_axis_tuser(aead_tuser),
        .m_axis_tvalid(aead_tvalid),
        .m_axis_tlast(aead_tlast)
    );

    quic_payload_protect #(
        .C_AXIS_DATA_WIDTH (C_AXIS_DATA_WIDTH),
        .C_AXIS_TUSER_WIDTH(C_AXIS_TUSER_WIDTH)
     ) quic_payload_protect (
        .axis_aclk         (aead_clk),
        .axis_resetn       (aead_resetn),
        .s_axis_tdata      (aead_tdata),
        .s_axis_tkeep      (aead_tkeep),
        .s_axis_tuser      (aead_tuser),
        .s_axis_tvalid     (aead_tvalid),
        .s_axis_tready     (aead_tready),
        .s_axis_tlast      (aead_tlast),
        .m_axis_tdata      (post_aead_tdata),
        .m_axis_tkeep      (post_aead_tkeep),
        .m_axis_tuser      (post_aead_tuser),
        .m_axis_tvalid     (post_aead_tvalid),
        .m_axis_tready     (post_aead_tready),
        .m_axis_tlast      (post_aead_tlast)
    );

    axis_clock_converter_low_to_high low_to_high (
        .s_axis_aclk    (aead_clk),
        .s_axis_aresetn (aead_resetn),
        .s_axis_tdata   (post_aead_tdata),
        .s_axis_tready  (post_aead_tready),
        .s_axis_tkeep   (post_aead_tkeep),
        .s_axis_tuser   (post_aead_tuser),
        .s_axis_tvalid  (post_aead_tvalid),
        .s_axis_tlast   (post_aead_tlast),

        .m_axis_aclk   (axis_aclk),
        .m_axis_aresetn(axis_resetn),
        .m_axis_tdata  (out_buf_tdata),
        .m_axis_tready (out_buf_tready),
        .m_axis_tkeep  (out_buf_tkeep),
        .m_axis_tuser  (out_buf_tuser),
        .m_axis_tvalid (out_buf_tvalid),
        .m_axis_tlast  (out_buf_tlast)
    );

    wire out_fifo_full, out_fifo_empty;
    assign out_buf_tready = ~out_fifo_full;
    assign m_axis_tvalid = ~out_fifo_empty;
    xpm_fifo_sync # (
       .FIFO_WRITE_DEPTH    (FIFO_DEPTH),
       .WRITE_DATA_WIDTH    (C_AXIS_DATA_WIDTH+C_AXIS_DATA_WIDTH/8+C_AXIS_TUSER_WIDTH+1),
       .PROG_FULL_THRESH    (FIFO_DEPTH - 5),
       .READ_MODE           ("FWFT"),
       .FIFO_READ_LATENCY   (0),
       .READ_DATA_WIDTH     (C_AXIS_DATA_WIDTH+C_AXIS_DATA_WIDTH/8+C_AXIS_TUSER_WIDTH+1)
    ) output_fifo (
       .sleep            (1'b0),
       .rst              (!axis_resetn),
       .wr_clk           (axis_aclk),
       .wr_en            (out_buf_tvalid && out_buf_tvalid),
       .din              ({out_buf_tdata, out_buf_tkeep, out_buf_tuser, out_buf_tlast}),
       .full             (out_fifo_full), /* Should never happen, if it does happen, panic? */
       .prog_full        (), // TODO: maybe track with an AXI-Lite register?
       .wr_data_count    (),
       .overflow         (),
       .wr_rst_busy      (),
       .rd_en            (m_axis_tvalid && m_axis_tready),
       .dout             ({m_axis_tdata, m_axis_tkeep, m_axis_tuser, m_axis_tlast}),
       .data_valid       (),
       .empty            (out_fifo_empty),
       .prog_empty       (),
       .rd_data_count    (),
       .underflow        (),
       .rd_rst_busy      (),
       .injectsbiterr    (1'b0),
       .injectdbiterr    (1'b0),
       .sbiterr          (),
       .dbiterr          ()
    );
endmodule
