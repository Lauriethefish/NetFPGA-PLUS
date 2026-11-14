`timescale 1ns / 1ps

module top_tb;
    reg axis_aclk = 0;
    reg axis_resetn = 0;

    always #2.5 axis_aclk = ~axis_aclk;

    initial begin
        repeat (20) @(negedge axis_aclk);
        axis_resetn = 1;
    end

    top_sim dut (
        .axis_aclk(axis_aclk),
        .axis_resetn(axis_resetn)
    );
endmodule
