
`timescale 1ns / 1ps

// Module that multiplexes between several quic_encrypt instances.
module quic_encrypt #(
    parameter C_AXIS_DATA_WIDTH = 512,
    parameter C_AXIS_TUSER_WIDTH = 128,
    parameter NUM_MODULES=8
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
    reg [7:0] input_module;
    reg [7:0] output_module;
    reg [7:0] input_packet_number;
    reg [7:0] output_packet_number;

    wire [C_AXIS_TUSER_WIDTH-1:0] s_axis_tuser_numbered =
        {input_packet_number, s_axis_tuser[15:0]};

    wire [NUM_MODULES-1:0]                           encry_axis_s_tready;
    assign s_axis_tready = input_module == 8'hff ? 0 : encry_axis_s_tready[input_module];

    wire [NUM_MODULES-1:0][C_AXIS_DATA_WIDTH-1:0]    encry_axis_m_tdata;
    wire [NUM_MODULES-1:0][C_AXIS_TUSER_WIDTH-1:0]   encry_axis_m_tuser;
    wire [NUM_MODULES-1:0][C_AXIS_DATA_WIDTH/8-1:0] encry_axis_m_tkeep;
    wire [NUM_MODULES-1:0]                           encry_axis_m_tvalid;
    wire [NUM_MODULES-1:0]                           encry_axis_m_tlast;

    assign m_axis_tdata = output_module == 8'hff ? '0 : encry_axis_m_tdata[output_module];
    assign m_axis_tkeep = output_module == 8'hff ? '0 : encry_axis_m_tkeep[output_module];
    assign m_axis_tuser = output_module == 8'hff ? '0 : encry_axis_m_tuser[output_module];
    assign m_axis_tvalid = output_module == 8'hff ? '0 : encry_axis_m_tvalid[output_module];
    assign m_axis_tlast = output_module == 8'hff ? '0 : encry_axis_m_tlast[output_module];

    wire [7:0] next_input_module;
    generate
        wire [NUM_MODULES:0][7:0] lowest_tready_tmp;
        assign lowest_tready_tmp[NUM_MODULES] = 8'hff;
        for(genvar i = NUM_MODULES-1; i >= 0; i--) begin
            assign lowest_tready_tmp[i] = 
                (encry_axis_s_tready[i] && i != input_module) ? i : lowest_tready_tmp[i+1];
        end

        assign next_input_module = lowest_tready_tmp[0];
    endgenerate

    wire [7:0] next_output_module;
    generate
        wire [NUM_MODULES:0][7:0] matching_tmp;
        assign matching_tmp[NUM_MODULES] = 8'hff;
        for(genvar i = NUM_MODULES-1; i >= 0; i--) begin
            assign matching_tmp[i] = (encry_axis_m_tuser[i][23:16] == 8'(output_packet_number + 1)) && encry_axis_m_tvalid[i]
            && i != output_module
                ? i : matching_tmp[i+1];
        end

        assign next_output_module = matching_tmp[0];
    endgenerate


    always_ff @(posedge axis_aclk) begin
        if(!axis_resetn) begin
            input_packet_number <= '0;
            output_packet_number <= '0;
            input_module <= 8'hff;
            output_module <= 8'hff;
        end else begin
            // If completing the last transfer of a packet, move to another AES-GCM module
            // Alternatively, if we previously didn't select a module because all
            // were occupied, we can also select a module now.
            if((s_axis_tready && s_axis_tlast && s_axis_tvalid)
                || input_module == 8'hff) begin
                input_module <= next_input_module;
                if(next_input_module != 8'hff) begin
                    input_packet_number <= input_packet_number + 1;
                end
            end

            
            if((m_axis_tready && m_axis_tvalid && m_axis_tlast)
                || output_module == 8'hff) begin
                output_module <= next_output_module;
                if(next_output_module != 8'hff) begin
                    output_packet_number <= output_packet_number + 1;
                end
            end
        end
    end
    generate
        for(genvar i = 0; i < NUM_MODULES; i++) begin
            quic_encrypt_single #(
                .C_AXIS_DATA_WIDTH (C_AXIS_DATA_WIDTH),
                .C_AXIS_TUSER_WIDTH(C_AXIS_TUSER_WIDTH)
            ) quic_encrypt_single (
                .axis_aclk    (axis_aclk),
                .axis_resetn  (axis_resetn),
                .s_axis_tdata (s_axis_tdata),
                .s_axis_tkeep (s_axis_tkeep),
                .s_axis_tuser (s_axis_tuser_numbered),
                .s_axis_tvalid(s_axis_tvalid && (input_module == i)),
                .s_axis_tready(encry_axis_s_tready[i]),
                .s_axis_tlast (s_axis_tlast),
                // Output needs arbitration.
                .m_axis_tdata (encry_axis_m_tdata[i]),
                .m_axis_tkeep (encry_axis_m_tkeep[i]),
                .m_axis_tuser (encry_axis_m_tuser[i]),
                .m_axis_tvalid(encry_axis_m_tvalid[i]),
                .m_axis_tready(m_axis_tready && (output_module == i)),
                .m_axis_tlast (encry_axis_m_tlast[i])
            );
        end
    endgenerate
endmodule
