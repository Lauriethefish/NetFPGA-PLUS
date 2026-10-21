module sum_16_bit_words
#(
    // Must be multiple of 16
    parameter DATA_START=0,
    parameter DATA_WIDTH=128,
    parameter INPUT_WIDTH=128
)
(
    input [INPUT_WIDTH-1:0] s_axis_tdata,
    input [(INPUT_WIDTH/8)-1:0] s_axis_tkeep,

    output [31:0] sum
);

    wire [DATA_WIDTH-1:0] segment_to_add;

    genvar i;
    generate
        for(i = DATA_START/8; i < (DATA_START+DATA_LENGTH)/8; i++) begin
            assign segment_to_add[i*8+7-DATA_START:i*8-DATA_START]
                = s_axis_tkeep[i] ? s_axis_tdata[i*8+7:i*8] : 0;
        end
    endgenerate

    wire [DATA_WIDTH-1:0] ordered_segment_to_add;
    assign ordered_segment_to_add = {<<8{segment_to_add}};

    // Compute sum of 16 bit words
    wire [31:0] partial_sums [(DATA_WIDTH/16)+1];
    assign partial_sums[0] = 0;

    generate
        for(i = 1; i <= DATA_WIDTH/16; i++) begin
            // Select each of the 16 bit blocks and sum them up
            assign partial_sums[i] = partial_sums[i-1] + ordered_segment_to_add[i*16-1:(i-1)*16];
        end
    endgenerate

    assign sum = partial_sums[DATA_WIDTH/16];
endmodule