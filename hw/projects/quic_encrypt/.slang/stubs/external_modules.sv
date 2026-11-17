// Editor-only interface declarations for VHDL / Vivado-generated modules.
// Never add this file to the Vivado synthesis or simulation source lists.
// top_aes_gcm mirrors aes-gcm/src/gen_rtl/top_aes_gcm.vhd (AES-128).
`timescale 1ns / 1ps
// These declarations intentionally contain no implementation.
`pragma diagnostic push
`pragma diagnostic ignore=("unused-port", "undriven-port")

(* blackbox *)
module top_aes_gcm (
    input rst_i,
    input clk_i,
    input [1:0] aes_gcm_mode_i,
    input aes_gcm_enc_dec_i,
    input aes_gcm_pipe_reset_i,
    input [3:0] aes_gcm_key_word_val_i,
    input [255:0] aes_gcm_key_word_i,
    input aes_gcm_iv_val_i,
    input [95:0] aes_gcm_iv_i,
    input aes_gcm_icb_start_cnt_i,
    input aes_gcm_icb_stop_cnt_i,
    input aes_gcm_ghash_pkt_val_i,
    input [15:0] aes_gcm_ghash_aad_bval_i,
    input [127:0] aes_gcm_ghash_aad_i,
    input [15:0] aes_gcm_data_in_bval_i,
    input [127:0] aes_gcm_data_in_i,
    output aes_gcm_ready_o,
    output aes_gcm_data_out_val_o,
    output [15:0] aes_gcm_data_out_bval_o,
    output [127:0] aes_gcm_data_out_o,
    output aes_gcm_ghash_tag_val_o,
    output [127:0] aes_gcm_ghash_tag_o,
    output aes_gcm_icb_cnt_overflow_o
);
endmodule

// Interfaces configured by hw/tcl/quic_encrypt_sim.tcl for a 512-bit stream.
(* blackbox *)
module axis_sim_stim_ip0 (
    input ACLK,
    input ARESETN,
    output [511:0] M_AXIS_TDATA,
    output [63:0] M_AXIS_TKEEP,
    output [127:0] M_AXIS_TUSER,
    output M_AXIS_TVALID,
    input M_AXIS_TREADY,
    output M_AXIS_TLAST,
    input [31:0] counter,
    output activity_stim,
    output barrier_req,
    input barrier_proceed
);
endmodule

(* blackbox *)
module axis_sim_record_ip0 (
    input axi_aclk,
    input [511:0] s_axis_tdata,
    input [63:0] s_axis_tkeep,
    input [127:0] s_axis_tuser,
    input s_axis_tvalid,
    output s_axis_tready,
    input s_axis_tlast,
    output [31:0] counter,
    output activity_rec
);
endmodule
`pragma diagnostic pop
