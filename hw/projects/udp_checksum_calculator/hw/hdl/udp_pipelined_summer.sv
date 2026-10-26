
module udp_pipelined_summer
#(
    parameter C_M_AXIS_DATA_WIDTH=1024,
    parameter C_S_AXIS_DATA_WIDTH=1024,
    parameter C_M_AXIS_TUSER_WIDTH=128,
    parameter C_S_AXIS_TUSER_WIDTH=128,

    // NB must be multiple of 8
    parameter NUM_SECTIONS=16
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
    output [$bits(inter_structs::udp_header):0] m_axis_orig_header,
    output [31:0] m_axis_checksum,

    // Slave Stream Ports (read packet data)
    input [C_S_AXIS_DATA_WIDTH - 1:0] s_axis_tdata,
    input [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_tkeep,
    input [C_S_AXIS_TUSER_WIDTH-1:0] s_axis_tuser,
    input  s_axis_tvalid,
    output s_axis_tready,
    input  s_axis_tlast
);

    localparam BITS_PER_SUMMER = C_M_AXIS_DATA_WIDTH / NUM_SECTIONS;

    // Assign the first of these to the s_axis_tdata, i.e. the input
    wire [C_M_AXIS_DATA_WIDTH - 1:0] int_axis_tdata [NUM_SECTIONS:0];
    wire [$bits(inter_structs::udp_header):0] int_axis_orig_header [NUM_SECTIONS:0];
    wire [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] int_axis_tkeep [NUM_SECTIONS:0];
    wire [C_M_AXIS_TUSER_WIDTH-1:0] int_axis_tuser [NUM_SECTIONS:0];
    wire int_axis_tvalid [NUM_SECTIONS:0];
    wire int_axis_tready [NUM_SECTIONS:0];
    wire int_axis_tlast [NUM_SECTIONS:0];
    wire [31:0] int_axis_partial_sum [NUM_SECTIONS:0];

    // Insert module that will cut and paste in the pseudo header for checksum
    // calculation.
    udp_pseudo_header_inserter
    #(
        .C_M_AXIS_DATA_WIDTH(C_M_AXIS_DATA_WIDTH),
        .C_S_AXIS_DATA_WIDTH(C_S_AXIS_DATA_WIDTH),
        .C_M_AXIS_TUSER_WIDTH(C_M_AXIS_TUSER_WIDTH),
        .C_S_AXIS_TUSER_WIDTH(C_S_AXIS_TUSER_WIDTH)
    )
    header_inserter
    (
        .axis_aclk(axis_aclk),
        .axis_resetn(axis_resetn),

        // Master Stream Ports (write packet data)
        .m_axis_tdata(int_axis_tdata[0]),
        .m_axis_orig_header(int_axis_orig_header[0]),
        .m_axis_tkeep(int_axis_tkeep[0]),
        .m_axis_tuser(int_axis_tuser[0]),
        .m_axis_tvalid(int_axis_tvalid[0]),
        .m_axis_tready(int_axis_tready[0]),
        .m_axis_tlast(int_axis_tlast[0]),

        // Slave Stream Ports (read packet data)
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tkeep(s_axis_tkeep),
        .s_axis_tuser(s_axis_tuser),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast)
    );

    assign int_axis_partial_sum[0] = 32'b0;

    // Store the data in a pipeline/FIFO
    // In each stage add up a certain portion of the data


    generate
        for(genvar i = 0; i < NUM_SECTIONS; i++) begin
            udp_pipelined_summer_section
            #(
                .C_M_AXIS_DATA_WIDTH(C_M_AXIS_DATA_WIDTH),
                .C_S_AXIS_DATA_WIDTH(C_S_AXIS_DATA_WIDTH),
                .C_M_AXIS_TUSER_WIDTH(C_M_AXIS_TUSER_WIDTH),
                .C_S_AXIS_TUSER_WIDTH(C_S_AXIS_TUSER_WIDTH),

                // NB must be multiple of 8
                .DATA_ADD_START(i*BITS_PER_SUMMER),
                // as above.
                .DATA_ADD_LENGTH(BITS_PER_SUMMER)
            )
            sect
            (
                // Global clock/reset
                .axis_aclk(axis_aclk),
                // Active low
                .axis_resetn(axis_resetn),

                // Master Stream Ports (write packet data)
                .m_axis_tdata(int_axis_tdata[i+1]),
                .m_axis_orig_header(int_axis_orig_header[i+1]),
                .m_axis_tkeep(int_axis_tkeep[i+1]),
                .m_axis_tuser(int_axis_tuser[i+1]),
                .m_axis_tvalid(int_axis_tvalid[i+1]),
                .m_axis_tready(int_axis_tready[i+1]),
                .m_axis_tlast(int_axis_tlast[i+1]),
                .m_axis_partial_sum(int_axis_partial_sum[i+1]),

                // Slave Stream Ports (read packet data)
                .s_axis_tdata(int_axis_tdata[i]),
                .s_axis_orig_header(int_axis_orig_header[i]),
                .s_axis_tkeep(int_axis_tkeep[i]),
                .s_axis_tuser(int_axis_tuser[i]),
                .s_axis_tvalid(int_axis_tvalid[i]),
                .s_axis_tready(int_axis_tready[i]),
                .s_axis_tlast(int_axis_tlast[i]),
                .s_axis_partial_sum(int_axis_partial_sum[i])
            );
        end
    endgenerate

    assign m_axis_tdata = int_axis_tdata[NUM_SECTIONS];
    assign m_axis_orig_header = int_axis_orig_header[NUM_SECTIONS];
    assign m_axis_tuser = int_axis_tuser[NUM_SECTIONS];
    assign m_axis_tkeep = int_axis_tkeep[NUM_SECTIONS];
    assign m_axis_tvalid = int_axis_tvalid[NUM_SECTIONS];
    assign int_axis_tready[NUM_SECTIONS] = m_axis_tready;
    assign m_axis_tlast = int_axis_tlast[NUM_SECTIONS];
    assign m_axis_checksum = int_axis_partial_sum[NUM_SECTIONS];
endmodule