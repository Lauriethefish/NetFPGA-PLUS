`timescale 1ns / 1ps

module top_tb #(
    // Match udp_segmentation and quic_accel simulation clocks (about 344.8 MHz).
    parameter real CORE_PERIOD = 2.9
);
    reg axis_aclk = 0;
    reg axis_resetn = 0;

    always #(CORE_PERIOD / 2) axis_aclk = ~axis_aclk;

    initial begin
        repeat (20) @(negedge axis_aclk);
        axis_resetn = 1;
    end

    top_sim dut (
        .axis_aclk(axis_aclk),
        .axis_resetn(axis_resetn)
    );
endmodule
