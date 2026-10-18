//-
// Copyright (c) 2015 Noa Zilberman, Georgina Kalogeridou
// Copyright (c) 2021 Yuta Tokusashi
// All rights reserved.
//
// This software was developed by Stanford University and the University of Cambridge Computer Laboratory 
// under National Science Foundation under Grant No. CNS-0855268,
// the University of Cambridge Computer Laboratory under EPSRC INTERNET Project EP/H040536/1 and
// by the University of Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-11-C-0249 ("MRC2"), 
// as part of the DARPA MRC research programme,
// and by the University of Cambridge Computer Laboratory under EPSRC EARL Project
// EP/P025374/1 alongside support from Xilinx Inc.
//
//  File:
//        top_sim.v
//
//  Module:
//        top
//
//  Author: Noa Zilberman, Georgina Kalogeridou
//
//  Description:
//        UDP checksum calculator top module
//
// @NETFPGA_LICENSE_HEADER_START@
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// @NETFPGA_LICENSE_HEADER_END@
//

`timescale 1ps / 100 fs

 module top_sim # (
  parameter          C_DATA_WIDTH                        = 1024,         // RX/TX interface data width
  parameter          C_TUSER_WIDTH                       = 128,         // RX/TX interface data width  
  parameter          C_NF_DATA_WIDTH                     = 1024,         // RX/TX interface data width
  parameter          KEEP_WIDTH                          = C_DATA_WIDTH / 32
 ) (

  //PCI Express
  input  [15:0]  pcie_rxn,
  input  [15:0]  pcie_rxp,
  output [15:0]  pcie_txn,
  output [15:0]  pcie_txp,
  //Network Interface
  input  [3:0]   qsfp0_rxp,
  input  [3:0]   qsfp0_rxn,
  output [3:0]   qsfp0_txp,
  output [3:0]   qsfp0_txn,

  input  [3:0]   qsfp1_rxp,
  input  [3:0]   qsfp1_rxn,
  output [3:0]   qsfp1_txp,
  output [3:0]   qsfp1_txn,

  // PCIe Clock
  input          pci_clk_p,
  input          pci_clk_n,

  //200MHz Clock
  input          fpga_sysclk_p,
  input          fpga_sysclk_n,

  // 156.25 MHz clock in
  input          qsfp_refclk_p,
  input          qsfp_refclk_n,

  input          sys_reset_n
);

  //----------------------------------------------------------------------------------------------------------------//
  //    System(SYS) Interface                                                                                       //
  //----------------------------------------------------------------------------------------------------------------//

  wire                                       sys_clk;
  wire                                       clk_200_i;
  wire                                       clk_200;
  wire                                       sys_rst_n_c;

    //-----------------------------------------------------------------------------------------------------------------------
  
  //----------------------------------------------------------------------------------------------------------------//
  // axis interface                                                                                                 //
  //----------------------------------------------------------------------------------------------------------------//

  wire[C_DATA_WIDTH-1:0]      p_axis_i_tdata , p_axis_o_tdata;
  wire                        p_axis_i_tvalid, p_axis_o_tvalid;
  wire                        p_axis_i_tlast , p_axis_o_tlast;
  wire[C_TUSER_WIDTH-1:0]     p_axis_i_tuser , p_axis_o_tuser;
  wire[C_DATA_WIDTH/8-1:0]    p_axis_i_tkeep , p_axis_o_tkeep;
  wire                        p_axis_i_tready, p_axis_o_tready;

  // Network Interfaces
  wire axi_aresetn;
  wire axi_clk;
  wire [10:0] counter0;

  //---------------------------------------------------------------------
  // Misc 
  //---------------------------------------------------------------------
	IBUF   sys_reset_n_ibuf (  .O(sys_rst_n_c),   .I(sys_reset_n));
  
	reg [15:0] sys_clk_count;
	always @(posedge ~sys_clk)        
		sys_clk_count  <= sys_clk_count + 1'b1;

	IBUFDS_GTE2 #(
		.CLKCM_CFG("TRUE"),   // Refer to Transceiver User Guide
		.CLKRCV_TRST("TRUE"), // Refer to Transceiver User Guide
		.CLKSWING_CFG(2'b11)  // Refer to Transceiver User Guide
	) IBUFDS_GTE2_inst (
		.O     (sys_clk),         // 1-bit output: Refer to Transceiver User Guide
		.ODIV2 (),            // 1-bit output: Refer to Transceiver User Guide
		.CEB   (1'b0),          // 1-bit input: Refer to Transceiver User Guide
		.I     (pci_clk_p),        // 1-bit input: Refer to Transceiver User Guide
		.IB    (pci_clk_n)        // 1-bit input: Refer to Transceiver User Guide
	);  


	IBUFDS_GTE2 #(
		.CLKCM_CFG("TRUE"),   // Refer to Transceiver User Guide
		.CLKRCV_TRST("TRUE"), // Refer to Transceiver User Guide
		.CLKSWING_CFG(2'b11)  // Refer to Transceiver User Guide
	) IBUFDS_GTE2_core_inst (
		.O     (clk_200),         // 1-bit output: Refer to Transceiver User Guide
		.ODIV2 (),            // 1-bit output: Refer to Transceiver User Guide
		.CEB   (1'b0),          // 1-bit input: Refer to Transceiver User Guide
		.I     (fpga_sysclk_p),        // 1-bit input: Refer to Transceiver User Guide
		.IB    (fpga_sysclk_n)        // 1-bit input: Refer to Transceiver User Guide
	);  

	// drive AXI-lite from sys_clk & sys_rst
	assign axi_clk     = sys_clk;
	assign axi_aresetn = sys_rst_n_c;

//-----------------------------------------------------------------------------------------------//
// Network modules                                                                               //
//-----------------------------------------------------------------------------------------------//

	// Instantiate checksum calculator
	udp_set_checksum
    #(
      .C_M_AXIS_DATA_WIDTH (C_NF_DATA_WIDTH),
      .C_S_AXIS_DATA_WIDTH (C_NF_DATA_WIDTH),
      .C_M_AXIS_TUSER_WIDTH (C_TUSER_WIDTH),
      .C_S_AXIS_TUSER_WIDTH (C_TUSER_WIDTH)
    )
    set_checksum
    (
      .axis_aclk(axis_aclk), 
      .axis_resetn(axis_resetn), 
      
      .s_axis_tdata (p_axis_i_tdata), 
      .s_axis_tkeep (p_axis_i_tkeep), 
      .s_axis_tuser (p_axis_i_tuser), 
      .s_axis_tvalid(p_axis_i_tvalid),
      .s_axis_tready(p_axis_i_tready), 
      .s_axis_tlast (p_axis_i_tlast),

      .m_axis_tdata (p_axis_o_tdata), 
      .m_axis_tkeep (p_axis_o_tkeep), 
      .m_axis_tuser (p_axis_o_tuser), 
      .m_axis_tvalid(p_axis_o_tvalid), 
      .m_axis_tready(p_axis_o_tready), 
      .m_axis_tlast (p_axis_o_tlast)
    );

	axis_sim_stim_ip0 axis_sim_stim_0 (
		.ACLK            (clk_200),
		.ARESETN         (sys_rst_n_c),

		//axi streaming data interface
		.M_AXIS_TDATA    (p_axis_i_tdata),
		.M_AXIS_TKEEP    (p_axis_i_tkeep),
		.M_AXIS_TUSER    (p_axis_i_tuser),
		.M_AXIS_TVALID   (p_axis_i_tvalid),
		.M_AXIS_TREADY   (p_axis_i_tready),
		.M_AXIS_TLAST    (p_axis_i_tlast),

		.counter         (counter0),
		.activity_stim   (activity_stim0),
		.barrier_req     (barrier_req0),
		.barrier_proceed (barrier_proceed)
	);

	axis_sim_record_ip0 axis_sim_record_0 (
		.axi_aclk (clk_200),
		// Slave Stream Ports (interface to data path)
		.s_axis_tdata (p_axis_o_tdata),
		.s_axis_tkeep (p_axis_o_tkeep),
		.s_axis_tuser (p_axis_o_tuser),
		.s_axis_tvalid(p_axis_o_tvalid),
		.s_axis_tready(p_axis_o_tready),
		.s_axis_tlast (p_axis_o_tlast),
	
		.counter (counter0),
		.activity_rec(activity_rec0)
	);

endmodule

