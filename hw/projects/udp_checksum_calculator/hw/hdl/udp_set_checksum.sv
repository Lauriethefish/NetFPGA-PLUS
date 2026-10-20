`define C_M_AXIS_DATA_WIDTH 1024
`define C_S_AXIS_DATA_WIDTH 1024
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
    wire [`C_M_AXIS_DATA_WIDTH/2 - 1:0] first_half_tdata_masked;
    genvar i;
    generate
        for(i = 0; i < `C_M_AXIS_DATA_WIDTH/8 / 2; i++) begin
            assign first_half_tdata_masked[i*8+7:i*8] = s_axis_tkeep[i+(`C_M_AXIS_DATA_WIDTH/8/2)] ? s_axis_tdata[i*8+7+512:i*8+512] : 0;
        end
    endgenerate

    wire [`C_M_AXIS_DATA_WIDTH/2 - 1:0] first_half_tdata_ordered;
    assign first_half_tdata_ordered = {<<8{first_half_tdata_masked}};

    wire [31:0] partial_sums [(`C_M_AXIS_DATA_WIDTH/16/2)+1];
    assign partial_sums[0] = 0;
    generate
        for(i = 1; i <= `C_M_AXIS_DATA_WIDTH/16/2; i++) begin
            // Select each of the 16 bit blocks and sum them up
            assign partial_sums[i] = partial_sums[i-1] + first_half_tdata_ordered[i*16-1:(i-1)*16];
        end
    endgenerate

    // Compute the sum of the first half in a pipeline stage
    wire [31:0] overall_sum;
    assign overall_sum = partial_sums[(`C_M_AXIS_DATA_WIDTH/16/2)];

    reg [`C_S_AXIS_DATA_WIDTH - 1:0] s_axis_tdata_buf;
    reg [((`C_S_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_tkeep_buf;
    reg [`C_S_AXIS_TUSER_WIDTH-1:0] s_axis_tuser_buf;
    reg [31:0] s_axis_tdata_half_sum_buf;
    reg  s_axis_tvalid_buf;
    reg  s_axis_tlast_buf;

    import inter_structs::*;

    // Essentially need to send to either of the udp checksum calculators,
    // depending on which one is ready.
    wire [`C_M_AXIS_DATA_WIDTH - 1:0] m_axis_tdata_c0;
    wire [((`C_M_AXIS_DATA_WIDTH / 8)) - 1:0] m_axis_tkeep_c0;
    wire [`C_M_AXIS_TUSER_WIDTH-1:0] m_axis_tuser_c0;
    wire m_axis_tvalid_c0;
    wire m_axis_tlast_c0;
    wire s_axis_tready_c0;
    wire s_axis_tvalid_c0;

    wire [`C_M_AXIS_DATA_WIDTH - 1:0] m_axis_tdata_c1;
    wire [((`C_M_AXIS_DATA_WIDTH / 8)) - 1:0] m_axis_tkeep_c1;
    wire [`C_M_AXIS_TUSER_WIDTH-1:0] m_axis_tuser_c1;
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
      .C_M_AXIS_DATA_WIDTH (`C_M_AXIS_DATA_WIDTH),
      .C_S_AXIS_DATA_WIDTH (`C_S_AXIS_DATA_WIDTH),
      .C_M_AXIS_TUSER_WIDTH (`C_M_AXIS_TUSER_WIDTH),
      .C_S_AXIS_TUSER_WIDTH (`C_M_AXIS_TUSER_WIDTH)
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
        .s_axis_tlast(s_axis_tlast_buf),
        .tdata_half_sum(s_axis_tdata_half_sum_buf)
    );

    udp_checksum_calculator
    #(
      .C_M_AXIS_DATA_WIDTH (`C_M_AXIS_DATA_WIDTH),
      .C_S_AXIS_DATA_WIDTH (`C_S_AXIS_DATA_WIDTH),
      .C_M_AXIS_TUSER_WIDTH (`C_M_AXIS_TUSER_WIDTH),
      .C_S_AXIS_TUSER_WIDTH (`C_M_AXIS_TUSER_WIDTH)
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
        .s_axis_tlast(s_axis_tlast_buf),
        .tdata_half_sum(s_axis_tdata_half_sum_buf)
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
                s_axis_tdata_half_sum_buf <= overall_sum;
            end else if(current_acceptor ? s_axis_tready_c1 : s_axis_tready_c0) begin
                // Data has been emptied from buffer
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