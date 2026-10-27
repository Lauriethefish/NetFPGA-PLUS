module udp_tree_summer
#(
    // NB this MUST be a power of two.
    parameter C_M_AXIS_DATA_WIDTH=1024,
    parameter C_S_AXIS_DATA_WIDTH=1024,
    parameter C_M_AXIS_TUSER_WIDTH=128,
    parameter C_S_AXIS_TUSER_WIDTH=128,

    parameter SUM_WIDTH=23
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
    localparam NUM_SECTIONS = $clog2(C_M_AXIS_DATA_WIDTH/16);

    wire [C_M_AXIS_DATA_WIDTH - 1:0] int_axis_tdata [NUM_SECTIONS:0];
    wire [$bits(inter_structs::udp_header):0] int_axis_orig_header [NUM_SECTIONS:0];
    wire [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] int_axis_tkeep [NUM_SECTIONS:0];
    wire [C_M_AXIS_TUSER_WIDTH-1:0] int_axis_tuser [NUM_SECTIONS:0];
    wire int_axis_tvalid [NUM_SECTIONS:0];
    wire int_axis_tready [NUM_SECTIONS:0];
    wire int_axis_tlast [NUM_SECTIONS:0];
    // Use for holding partial sums computed in each stage of calculation
    // Phase 1 needs C_M_AXIS_DATA_WIDTH/16/2
    // Phase 2 needs C_M_AXIS_DATA_WIDTH/16/4
    // Phase 3 needs C_M_AXIS_DATA_WIDTH/16/8
    // Overall need C_M_AXIS_DATA_WIDTH/16
    reg [SUM_WIDTH-1:0] int_axis_tpartial_sum [C_M_AXIS_DATA_WIDTH/16-1-1:0];


    // 1024 bits means 1024/16 = 64 x 16 bit words
    // 64 = 2^6, so we use 6 pipeline phases here.
    // Each phase corresponds to adding two values together in parallel across
    // the whole signal.

    // Cut and paste the pseudo header before computing the checksum
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
        // Can accept data if first stage is empty or its subsequent stage
        // is ready.
        .m_axis_tready(!int_axis_tvalid[0] || int_axis_tready[0]),
        .m_axis_tlast(int_axis_tlast[0]),

        // Slave Stream Ports (read packet data)
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tkeep(s_axis_tkeep),
        .s_axis_tuser(s_axis_tuser),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast)
    );

    wire [C_M_AXIS_DATA_WIDTH-1:0] s_axis_tdata_filtered;
    generate
        for(genvar i = 0; i < C_M_AXIS_DATA_WIDTH/8; i++) begin
            assign s_axis_tdata_filtered[i*8+7:i*8]
                = int_axis_tkeep[0][i] ? int_axis_tdata[0][i*8+7:i*8] : 0;
        end
    endgenerate

    wire [SUM_WIDTH-1:0] final_sum;

    generate
        // Make sure all registers are reset.
        for(genvar i = 0; i <= C_M_AXIS_DATA_WIDTH/16-1-1; i++) begin
            always_ff @(posedge axis_aclk) begin
                if(!axis_resetn) begin
                    int_axis_tpartial_sum[i] <= 0;
                end
            end
        end

        for(genvar pl_stage = 0; pl_stage < NUM_SECTIONS; pl_stage++) begin
            localparam num_partial_sums = C_M_AXIS_DATA_WIDTH/16/(2 << pl_stage);

            // Compute partial sums and output them to the right spot
            if(pl_stage == 0) begin
                for(genvar i = 0; i < num_partial_sums; i++) begin
                    wire [31:0] bits_to_add = s_axis_tdata_filtered[(i+1)*32-1:(i*32)];
                    wire [31:0] ordered_words_to_add = {<<8{bits_to_add}};
                    
                    always_ff @(posedge axis_aclk) begin
                        if(axis_resetn && int_axis_tvalid[pl_stage] && int_axis_tready[pl_stage]) begin
                            int_axis_tpartial_sum[i] <= SUM_WIDTH'(ordered_words_to_add[31:16]) + ordered_words_to_add[15:0];
                        end
                    end
                end 
            end else begin
                // For pl_stage = 1, want to read from 0
                // For pl_stage = 2, want to read from C_M_AXIS_DATA_WIDTH/16/2
                localparam read_partial_sums = pl_stage == 1 ? 0 : (C_M_AXIS_DATA_WIDTH/16 - C_M_AXIS_DATA_WIDTH/16/(2 << (pl_stage - 2)));
                // For pl_stage = 1, want to write to C_M_AXIS_DATA_WIDTH/16/2
                localparam write_partial_sums = C_M_AXIS_DATA_WIDTH/16 - C_M_AXIS_DATA_WIDTH/16/(2 << (pl_stage - 1));

                for(genvar i = 0; i < num_partial_sums; i++) begin
                    always_ff @(posedge axis_aclk) begin
                        if(axis_resetn && int_axis_tvalid[pl_stage] && int_axis_tready[pl_stage]) begin
                            int_axis_tpartial_sum[write_partial_sums+i] <=
                                int_axis_tpartial_sum[read_partial_sums+2*i] +
                                int_axis_tpartial_sum[read_partial_sums+2*i + 1];
                        end
                    end
                end
            end
        end
        assign final_sum = int_axis_tpartial_sum[C_M_AXIS_DATA_WIDTH/16-2];

        // Generate AXI pipelining logic
        for(genvar pl_stage = 1; pl_stage <= NUM_SECTIONS; pl_stage++) begin
            reg [C_M_AXIS_DATA_WIDTH - 1:0] int_axis_tdata_r;
            reg [$bits(inter_structs::udp_header):0] int_axis_orig_header_r;
            reg [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] int_axis_tkeep_r;
            reg [C_M_AXIS_TUSER_WIDTH-1:0] int_axis_tuser_r;
            reg int_axis_tvalid_r;
            reg int_axis_tlast_r;

            assign int_axis_tdata[pl_stage] = int_axis_tdata_r;
            assign int_axis_tuser[pl_stage] = int_axis_tuser_r;
            assign int_axis_tkeep[pl_stage] = int_axis_tkeep_r;
            assign int_axis_tvalid[pl_stage] = int_axis_tvalid_r;
            assign int_axis_tlast[pl_stage] = int_axis_tlast_r;
            assign int_axis_orig_header[pl_stage] = int_axis_orig_header_r;

            always_ff @(posedge axis_aclk) begin
                if(axis_resetn) begin 
                    // If previous stage has data, and this stage is ready for it,
                    // then transfer it
                    // Note: int_axis_tready indicates whether the receiver is ready for data.
                    if(int_axis_tready[pl_stage - 1] && int_axis_tvalid[pl_stage - 1]) begin
                        int_axis_tdata_r <= int_axis_tdata[pl_stage - 1];
                        int_axis_tuser_r <= int_axis_tuser[pl_stage - 1];
                        int_axis_tvalid_r <= int_axis_tvalid[pl_stage - 1];
                        int_axis_tkeep_r <= int_axis_tkeep[pl_stage - 1];
                        int_axis_tlast_r <= int_axis_tlast[pl_stage - 1];
                        int_axis_orig_header_r <= int_axis_orig_header[pl_stage - 1];
                    end

                    // Data from the previous stage becomes invalid
                    // i.e. if last stage has no data to give us, and we have data,
                    // and the next stage is ready for it
                    if(!int_axis_tvalid[pl_stage - 1] && int_axis_tvalid[pl_stage] && int_axis_tready[pl_stage]) begin
                        int_axis_tvalid_r <= 0;
                    end
                end else begin
                    int_axis_tdata_r <= '0;
                    int_axis_orig_header_r <= '0;
                    int_axis_tkeep_r <= '0;
                    int_axis_tuser_r <= '0;
                    int_axis_tvalid_r <= 0;
                    int_axis_tlast_r <= '0;
                end
            end
        end

        for(genvar pl_stage = 0; pl_stage <= NUM_SECTIONS-1; pl_stage++) begin
            // Check whether the NEXT pipeline stage is ready, i.e. has no data or
            // its subsequent stage can accept its data
            assign int_axis_tready[pl_stage] = !int_axis_tvalid[pl_stage+1] || int_axis_tready[pl_stage+1];
        end
    endgenerate

    assign m_axis_tdata = int_axis_tdata[NUM_SECTIONS];
    assign m_axis_tuser = int_axis_tuser[NUM_SECTIONS];
    assign m_axis_tkeep = int_axis_tkeep[NUM_SECTIONS];
    assign m_axis_tlast = int_axis_tlast[NUM_SECTIONS];
    assign int_axis_tready[NUM_SECTIONS] = m_axis_tready;
    assign m_axis_tvalid = int_axis_tvalid[NUM_SECTIONS];
    assign m_axis_checksum = final_sum;
    assign m_axis_orig_header = int_axis_orig_header[NUM_SECTIONS];
endmodule