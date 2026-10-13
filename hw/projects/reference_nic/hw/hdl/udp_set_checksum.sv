module udp_set_checksum
#(
    // Master/slave AXI Stream Data Width
    parameter C_M_AXIS_DATA_WIDTH=512,
    parameter C_S_AXIS_DATA_WIDTH=512,
    parameter C_M_AXIS_TUSER_WIDTH=128,
    parameter C_S_AXIS_TUSER_WIDTH=128
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
    output m_axis_tvalid,
    input  m_axis_tready,
    output m_axis_tlast,

    // Slave Stream Ports (read packet data)
    input [C_S_AXIS_DATA_WIDTH - 1:0] s_axis_tdata,
    input [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_tkeep,
    input [C_S_AXIS_TUSER_WIDTH-1:0] s_axis_tuser,
    input  s_axis_tvalid,
    output s_axis_tready,
    input  s_axis_tlast
);
    // Essentially need to send to either of the udp checksum calculators,
    // depending on which one is ready.
    wire [C_M_AXIS_DATA_WIDTH - 1:0] m_axis_tdata_c0;
    wire [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] m_axis_tkeep_c0;
    wire [C_M_AXIS_TUSER_WIDTH-1:0] m_axis_tuse_c0;
    wire m_axis_tvalid_c0;
    wire m_axis_tlast_c0;
    wire s_axis_tready_c0;
    wire s_axis_tvalid_c0;

    wire [C_M_AXIS_DATA_WIDTH - 1:0] m_axis_tdata_c1;
    wire [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] m_axis_tkeep_c1;
    wire [C_M_AXIS_TUSER_WIDTH-1:0] m_axis_tuser_c1;
    wire m_axis_tvalid_c1;
    wire m_axis_tlast_c1;
    wire s_axis_tready_c1;
    wire s_axis_tvalid_c1;

    reg current_acceptor;
    reg current_dumper;

    // Ready if the current acceptor is ready
    assign s_axis_tready = current_acceptor ? s_axis_tready_c1 : s_axis_tready_c0;

    assign s_axis_tvalid_c0 = (current_acceptor == 0) && s_axis_tvalid;
    assign s_axis_tvalid_c1 = (current_acceptor == 1) && s_axis_tvalid;

    
    assign m_axis_tdata = current_dumper ? m_axis_tdata_c1 : m_axis_tdata_c0;
    assign m_axis_tuser = current_dumper ? m_axis_tuser_c1 : m_axis_tuser_c0;
    assign m_axis_tkeep = current_dumper ? m_axis_tkeep_c1 : m_axis_tkeep_c0;
    assign m_axis_tlast = current_dumper ? m_axis_tlast_c1 : m_axis_tlast_c0;
    // Ready to put data downstream if either checksum calculator is
    assign m_axis_tvalid = current_dumper ? m_axis_tvalid_c1 | m_axis_tvalid_c0;
    assign m_axis_tready_c0 = m_axis_tready && !current_dumper;
    assign m_axis_tready_c1 = m_axis_tready && current_dumper;

    udp_checksum_calculator c0 (
        .axis_aclk(axis_aclk),
        .axis_resetn(axis_resetn),

        .m_axis_tdata(m_axis_tdata_c0),
        .m_axis_tkeep(m_axis_tkeep_c0),
        .m_axis_tuser(m_axis_tuser_c0),
        .m_axis_tvalid(m_axis_tvalid_c0),
        .m_axis_tready(m_axis_tready_c0),
        .m_axis_tlast(m_axis_tlast_c0),

        .s_axis_tdata(s_axis_tdata),
        .s_axis_tkeep(s_axis_tkeep),
        .s_axis_tuser(s_axis_tuser),
        .s_axis_tvalid(s_axis_tvalid_c0),
        .s_axis_tready(s_axis_tready_c0),
        .s_axis_tlast(s_axis_tlast)
    );

    udp_checksum_calculator c1 (
        .axis_aclk(axis_aclk),
        .axis_resetn(axis_resetn),

        .m_axis_tdata(m_axis_tdata_c1),
        .m_axis_tkeep(m_axis_tkeep_c1),
        .m_axis_tuser(m_axis_tuser_c1),
        .m_axis_tvalid(m_axis_tvalid_c1),
        .m_axis_tready(m_axis_tready_c1),
        .m_axis_tlast(m_axis_tlast_c1),

        .s_axis_tdata(s_axis_tdata),
        .s_axis_tkeep(s_axis_tkeep),
        .s_axis_tuser(s_axis_tuser),
        .s_axis_tvalid(s_axis_tvalid_c1),
        .s_axis_tready(s_axis_tready_c1),
        .s_axis_tlast(s_axis_tlast)
    );

    always_ff @(posedge axis_aclk) begin
        // Alternate the acceptor and dumper

        // If we're finishing a packet from the dumper
        if(m_axis_tlast) begin
            current_dumper <= ~current_dumper;
        end

        // If we're finishing a packet from the input
        if(s_axis_tlast) begin
            current_acceptor <= ~current_acceptor;
        end
    end
endmodule