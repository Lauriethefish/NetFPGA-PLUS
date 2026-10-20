module udp_set_checksum
#(
    // Master/slave AXI Stream Data Width
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
    output [C_M_AXIS_DATA_WIDTH - 1:0] m_axis_tdata,
    output [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] m_axis_tkeep,
    output [C_M_AXIS_TUSER_WIDTH-1:0] m_axis_tuser,
    output m_axis_tvalid,
    input  m_axis_tready,
    output m_axis_tlast,

    // Slave Stream Ports (read packet data)
    // Register these inputs
    // And compute checksum of the first half
    input [C_S_AXIS_DATA_WIDTH - 1:0] s_axis_tdata,
    input [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_tkeep,
    input [C_S_AXIS_TUSER_WIDTH-1:0] s_axis_tuser,
    input  s_axis_tvalid,
    output s_axis_tready,
    input  s_axis_tlast
);
    reg [C_S_AXIS_DATA_WIDTH - 1:0] s_axis_tdata_buf;
    reg [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_tkeep_buf;
    reg [C_S_AXIS_TUSER_WIDTH-1:0] s_axis_tuser_buf;
    reg  s_axis_tvalid_buf;
    reg  s_axis_tlast_buf;

    import inter_structs::*;

    // Essentially need to send to either of the udp checksum calculators,
    // depending on which one is ready.
    wire [C_M_AXIS_DATA_WIDTH - 1:0] m_axis_tdata_c0;
    wire [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] m_axis_tkeep_c0;
    wire [C_M_AXIS_TUSER_WIDTH-1:0] m_axis_tuser_c0;
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

    // Ready if the current acceptor is ready or if there is nothing in the buffer
    assign s_axis_tready = !s_axis_tvalid_buf ||
        (current_acceptor ? s_axis_tready_c1 : s_axis_tready_c0);

    assign s_axis_tvalid_c0 = (current_acceptor == 0) && s_axis_tvalid_buf;
    assign s_axis_tvalid_c1 = (current_acceptor == 1) && s_axis_tvalid_buf;

    
    assign m_axis_tdata = current_dumper ? m_axis_tdata_c1 : m_axis_tdata_c0;
    assign m_axis_tuser = current_dumper ? m_axis_tuser_c1 : m_axis_tuser_c0;
    assign m_axis_tkeep = current_dumper ? m_axis_tkeep_c1 : m_axis_tkeep_c0;
    assign m_axis_tlast = current_dumper ? m_axis_tlast_c1 : m_axis_tlast_c0;
    // Ready to put data downstream if either checksum calculator is
    assign m_axis_tvalid = current_dumper ? m_axis_tvalid_c1 : m_axis_tvalid_c0;
    assign m_axis_tready_c0 = m_axis_tready && !current_dumper;
    assign m_axis_tready_c1 = m_axis_tready && current_dumper;

    udp_checksum_calculator
    #(
      .C_M_AXIS_DATA_WIDTH (C_M_AXIS_DATA_WIDTH),
      .C_S_AXIS_DATA_WIDTH (C_S_AXIS_DATA_WIDTH),
      .C_M_AXIS_TUSER_WIDTH (C_M_AXIS_TUSER_WIDTH),
      .C_S_AXIS_TUSER_WIDTH (C_M_AXIS_TUSER_WIDTH)
    )
    c0
    (
        .axis_aclk(axis_aclk),
        .axis_resetn(axis_resetn),

        .m_axis_tdata(m_axis_tdata_c0),
        .m_axis_tkeep(m_axis_tkeep_c0),
        .m_axis_tuser(m_axis_tuser_c0),
        .m_axis_tvalid(m_axis_tvalid_c0),
        .m_axis_tready(m_axis_tready_c0),
        .m_axis_tlast(m_axis_tlast_c0),

        .s_axis_tdata(s_axis_tdata_buf),
        .s_axis_tkeep(s_axis_tkeep_buf),
        .s_axis_tuser(s_axis_tuser_buf),
        .s_axis_tvalid(s_axis_tvalid_c0),
        .s_axis_tready(s_axis_tready_c0),
        .s_axis_tlast(s_axis_tlast_buf)
    );

    udp_checksum_calculator
    #(
      .C_M_AXIS_DATA_WIDTH (C_M_AXIS_DATA_WIDTH),
      .C_S_AXIS_DATA_WIDTH (C_S_AXIS_DATA_WIDTH),
      .C_M_AXIS_TUSER_WIDTH (C_M_AXIS_TUSER_WIDTH),
      .C_S_AXIS_TUSER_WIDTH (C_M_AXIS_TUSER_WIDTH)
    )
    c1
    (
        .axis_aclk(axis_aclk),
        .axis_resetn(axis_resetn),

        .m_axis_tdata(m_axis_tdata_c1),
        .m_axis_tkeep(m_axis_tkeep_c1),
        .m_axis_tuser(m_axis_tuser_c1),
        .m_axis_tvalid(m_axis_tvalid_c1),
        .m_axis_tready(m_axis_tready_c1),
        .m_axis_tlast(m_axis_tlast_c1),

        .s_axis_tdata(s_axis_tdata_buf),
        .s_axis_tkeep(s_axis_tkeep_buf),
        .s_axis_tuser(s_axis_tuser_buf),
        .s_axis_tvalid(s_axis_tvalid_c1),
        .s_axis_tready(s_axis_tready_c1),
        .s_axis_tlast(s_axis_tlast_buf)
    );

    always_ff @(posedge axis_aclk) begin
        // Alternate the acceptor and dumper
        if(axis_resetn) begin
            // If we're finishing a packet from the dumper
            if(m_axis_tlast && m_axis_tvalid) begin
                current_dumper <= ~current_dumper;
            end

            // If we're finishing a packet from the input
            if(s_axis_tlast_buf && s_axis_tvalid_buf) begin
                current_acceptor <= ~current_acceptor;
            end

            // If ready and there is data, move it into the buffer
            if(s_axis_tready && s_axis_tvalid) begin
                s_axis_tdata_buf <= s_axis_tdata;
                s_axis_tkeep_buf <= s_axis_tkeep;
                s_axis_tuser_buf <= s_axis_tuser;
                s_axis_tvalid_buf <= s_axis_tvalid;
                s_axis_tlast_buf <= s_axis_tlast;
            end else if(current_acceptor ? s_axis_tready_c1 : s_axis_tready_c0) begin
                s_axis_tvalid_buf <= 0;
                s_axis_tlast_buf <= 0;
            end
        end else begin
            s_axis_tvalid_buf <= 0;
            s_axis_tlast_buf <= 0;
            current_dumper <= 0;
            current_acceptor <= 0;
        end
    end
endmodule