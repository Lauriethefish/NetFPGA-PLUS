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
//        reference nic top module
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
  parameter          C_DATA_WIDTH                        = 512,         // RX/TX interface data width
  parameter          C_TUSER_WIDTH                       = 128,         // RX/TX interface data width  
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

  // Ports to CMAC interface
  wire[C_DATA_WIDTH-1:0]      axis_phy_i_0_tdata , axis_phy_o_0_tdata;
  wire                        axis_phy_i_0_tvalid, axis_phy_o_0_tvalid;
  wire                        axis_phy_i_0_tlast , axis_phy_o_0_tlast;
  wire[C_TUSER_WIDTH-1:0]     axis_phy_i_0_tuser , axis_phy_o_0_tuser;
  wire[C_DATA_WIDTH/8-1:0]    axis_phy_i_0_tkeep , axis_phy_o_0_tkeep;
  wire                        axis_phy_i_0_tready, axis_phy_o_0_tready;

  wire[C_DATA_WIDTH-1:0]      axis_phy_i_1_tdata , axis_phy_o_1_tdata;
  wire                        axis_phy_i_1_tvalid, axis_phy_o_1_tvalid;
  wire                        axis_phy_i_1_tlast , axis_phy_o_1_tlast;
  wire[C_TUSER_WIDTH-1:0]     axis_phy_i_1_tuser , axis_phy_o_1_tuser;
  wire[C_DATA_WIDTH/8-1:0]    axis_phy_i_1_tkeep , axis_phy_o_1_tkeep;
  wire                        axis_phy_i_1_tready, axis_phy_o_1_tready;

  wire[C_DATA_WIDTH-1:0]      axis_phy_stim_0_tdata , axis_phy_rec_0_tdata;
  wire                        axis_phy_stim_0_tvalid, axis_phy_rec_0_tvalid;
  wire                        axis_phy_stim_0_tlast , axis_phy_rec_0_tlast;
  wire[C_TUSER_WIDTH-1:0]     axis_phy_stim_0_tuser , axis_phy_rec_0_tuser;
  wire[C_DATA_WIDTH/8-1:0]    axis_phy_stim_0_tkeep , axis_phy_rec_0_tkeep;
  wire                        axis_phy_stim_0_tready, axis_phy_rec_0_tready;

  wire[C_DATA_WIDTH-1:0]      axis_phy_stim_1_tdata , axis_phy_rec_1_tdata;
  wire                        axis_phy_stim_1_tvalid, axis_phy_rec_1_tvalid;
  wire                        axis_phy_stim_1_tlast , axis_phy_rec_1_tlast;
  wire[C_TUSER_WIDTH-1:0]     axis_phy_stim_1_tuser , axis_phy_rec_1_tuser;
  wire[C_DATA_WIDTH/8-1:0]    axis_phy_stim_1_tkeep , axis_phy_rec_1_tkeep;
  wire                        axis_phy_stim_1_tready, axis_phy_rec_1_tready;

  // Raw == before (or after in the case of output) nf_mac_attachment_dma_ip
  wire[C_DATA_WIDTH-1:0]      axis_dma_i_0_raw_tdata , axis_dma_o_0_raw_tdata;
  wire                        axis_dma_i_0_raw_tvalid, axis_dma_o_0_raw_tvalid;
  wire                        axis_dma_i_0_raw_tlast , axis_dma_o_0_raw_tlast;
  wire[C_TUSER_WIDTH-1:0]     axis_dma_i_0_raw_tuser , axis_dma_o_0_raw_tuser;
  wire[C_DATA_WIDTH/8-1:0]    axis_dma_i_0_raw_tkeep , axis_dma_o_0_raw_tkeep;
  wire                        axis_dma_i_0_raw_tready, axis_dma_o_0_raw_tready;
  // Input to DMA assumes no backpressure.
  assign axis_dma_i_0_raw_tready = 1'b1;
  assign axis_dma_i_1_raw_tready = 1'b1;

  wire[C_DATA_WIDTH-1:0]      axis_dma_i_1_raw_tdata , axis_dma_o_1_raw_tdata;
  wire                        axis_dma_i_1_raw_tvalid, axis_dma_o_1_raw_tvalid;
  wire                        axis_dma_i_1_raw_tlast , axis_dma_o_1_raw_tlast;
  wire[C_TUSER_WIDTH-1:0]     axis_dma_i_1_raw_tuser , axis_dma_o_1_raw_tuser;
  wire[C_DATA_WIDTH/8-1:0]    axis_dma_i_1_raw_tkeep , axis_dma_o_1_raw_tkeep;
  wire                        axis_dma_i_1_raw_tready, axis_dma_o_1_raw_tready;

  wire[C_DATA_WIDTH-1:0]      axis_dma_i_0_tdata , axis_dma_o_0_tdata;
  wire                        axis_dma_i_0_tvalid, axis_dma_o_0_tvalid;
  wire                        axis_dma_i_0_tlast , axis_dma_o_0_tlast;
  wire[C_TUSER_WIDTH-1:0]     axis_dma_i_0_tuser , axis_dma_o_0_tuser;
  wire[C_DATA_WIDTH/8-1:0]    axis_dma_i_0_tkeep , axis_dma_o_0_tkeep;
  wire                        axis_dma_i_0_tready, axis_dma_o_0_tready;

  wire[C_DATA_WIDTH-1:0]      axis_dma_i_1_tdata , axis_dma_o_1_tdata;
  wire                        axis_dma_i_1_tvalid, axis_dma_o_1_tvalid;
  wire                        axis_dma_i_1_tlast , axis_dma_o_1_tlast;
  wire[C_TUSER_WIDTH-1:0]     axis_dma_i_1_tuser , axis_dma_o_1_tuser;
  wire[C_DATA_WIDTH/8-1:0]    axis_dma_i_1_tkeep , axis_dma_o_1_tkeep;
  wire                        axis_dma_i_1_tready, axis_dma_o_1_tready;

  wire[C_DATA_WIDTH-1:0]      axis_dma_stim_tdata , axis_dma_rec_tdata;
  wire                        axis_dma_stim_tvalid, axis_dma_rec_tvalid;
  wire                        axis_dma_stim_tlast , axis_dma_rec_tlast;
  wire[C_TUSER_WIDTH-1:0]     axis_dma_stim_tuser , axis_dma_rec_tuser;
  wire[C_DATA_WIDTH/8-1:0]    axis_dma_stim_tkeep , axis_dma_rec_tkeep;
  wire                        axis_dma_stim_tready, axis_dma_rec_tready;

 //----------------------------------------------------------------------------------------------------------------//
 // AXI Lite interface                                                                                                 //
 //----------------------------------------------------------------------------------------------------------------//
  wire [31:0]   M0_AXI_araddr , M1_AXI_araddr ;
  wire [2:0]    M0_AXI_arprot , M1_AXI_arprot ;
  wire          M0_AXI_arready, M1_AXI_arready;
  wire          M0_AXI_arvalid, M1_AXI_arvalid;
  wire [31:0]   M0_AXI_awaddr , M1_AXI_awaddr ;
  wire [2:0]    M0_AXI_awprot , M1_AXI_awprot ;
  wire          M0_AXI_awready, M1_AXI_awready;
  wire          M0_AXI_awvalid, M1_AXI_awvalid;
  wire          M0_AXI_bready , M1_AXI_bready ;
  wire [1:0]    M0_AXI_bresp  , M1_AXI_bresp  ;
  wire          M0_AXI_bvalid , M1_AXI_bvalid ; 
  wire [31:0]   M0_AXI_rdata  , M1_AXI_rdata  ;
  wire          M0_AXI_rready , M1_AXI_rready ; 
  wire [1:0]    M0_AXI_rresp  , M1_AXI_rresp  ;
  wire          M0_AXI_rvalid , M1_AXI_rvalid ; 
  wire [31:0]   M0_AXI_wdata  , M1_AXI_wdata  ;
  wire          M0_AXI_wready , M1_AXI_wready ; 
  wire [3:0]    M0_AXI_wstrb  , M1_AXI_wstrb  ;
  wire          M0_AXI_wvalid , M1_AXI_wvalid ; 

  wire [31:0]   M2_AXI_araddr , M3_AXI_araddr ;
  wire [2:0]    M2_AXI_arprot , M3_AXI_arprot ;
  wire          M2_AXI_arready, M3_AXI_arready;
  wire          M2_AXI_arvalid, M3_AXI_arvalid;
  wire [31:0]   M2_AXI_awaddr , M3_AXI_awaddr ;
  wire [2:0]    M2_AXI_awprot , M3_AXI_awprot ;
  wire          M2_AXI_awready, M3_AXI_awready;
  wire          M2_AXI_awvalid, M3_AXI_awvalid;
  wire          M2_AXI_bready , M3_AXI_bready ;
  wire [1:0]    M2_AXI_bresp  , M3_AXI_bresp  ;
  wire          M2_AXI_bvalid , M3_AXI_bvalid ; 
  wire [31:0]   M2_AXI_rdata  , M3_AXI_rdata  ;
  wire          M2_AXI_rready , M3_AXI_rready ; 
  wire [1:0]    M2_AXI_rresp  , M3_AXI_rresp  ;
  wire          M2_AXI_rvalid , M3_AXI_rvalid ; 
  wire [31:0]   M2_AXI_wdata  , M3_AXI_wdata  ;
  wire          M2_AXI_wready , M3_AXI_wready ; 
  wire [3:0]    M2_AXI_wstrb  , M3_AXI_wstrb  ;
  wire          M2_AXI_wvalid , M3_AXI_wvalid ; 

  wire [31:0]   M4_AXI_araddr , M5_AXI_araddr ;
  wire [2:0]    M4_AXI_arprot , M5_AXI_arprot ;
  wire          M4_AXI_arready, M5_AXI_arready;
  wire          M4_AXI_arvalid, M5_AXI_arvalid;
  wire [31:0]   M4_AXI_awaddr , M5_AXI_awaddr ;
  wire [2:0]    M4_AXI_awprot , M5_AXI_awprot ;
  wire          M4_AXI_awready, M5_AXI_awready;
  wire          M4_AXI_awvalid, M5_AXI_awvalid;
  wire          M4_AXI_bready , M5_AXI_bready ;
  wire [1:0]    M4_AXI_bresp  , M5_AXI_bresp  ;
  wire          M4_AXI_bvalid , M5_AXI_bvalid ; 
  wire [31:0]   M4_AXI_rdata  , M5_AXI_rdata  ;
  wire          M4_AXI_rready , M5_AXI_rready ; 
  wire [1:0]    M4_AXI_rresp  , M5_AXI_rresp  ;
  wire          M4_AXI_rvalid , M5_AXI_rvalid ; 
  wire [31:0]   M4_AXI_wdata  , M5_AXI_wdata  ;
  wire          M4_AXI_wready , M5_AXI_wready ; 
  wire [3:0]    M4_AXI_wstrb  , M5_AXI_wstrb  ;
  wire          M4_AXI_wvalid , M5_AXI_wvalid ; 

  wire [31:0]   S00_AXI_araddr;
  wire [2:0]    S00_AXI_arprot /*= 3'b010*/;
  wire          S00_AXI_arready;
  wire          S00_AXI_arvalid;
  wire [31:0]   S00_AXI_awaddr;
  wire [2:0]    S00_AXI_awprot /*= 3'b010*/;
  wire          S00_AXI_awready;
  wire          S00_AXI_awvalid;
  wire          S00_AXI_bready;
  wire [1:0]    S00_AXI_bresp;
  wire          S00_AXI_bvalid;
  wire [31:0]   S00_AXI_rdata;
  wire          S00_AXI_rready;
  wire [1:0]    S00_AXI_rresp;
  wire          S00_AXI_rvalid;
  wire [31:0]   S00_AXI_wdata;
  wire          S00_AXI_wready;
  wire [3:0]    S00_AXI_wstrb;
  wire          S00_AXI_wvalid;

  // Network Interfaces
  wire axi_aresetn;
  wire axi_clk;
  wire [10:0] counter0,counter1,counter2,counter3,counter4;
  wire activity_stim4, activity_stim3, activity_stim2, activity_stim1, activity_stim0;
  wire activity_rec4, activity_rec3, activity_rec2, activity_rec1, activity_rec0;
  wire barrier_req0, barrier_req1, barrier_req2, barrier_req3, barrier_req4;
  wire barrier_proceed;
  wire activity_trans_sim;
  wire activity_trans_log;
  wire barrier_req_trans;

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

	// NB: two datapaths, one for each port.
	// This allows each datapath to remain at a manageable width of 512 bits,
	// which is much kinder to the router.

	nf_datapath #(
		.C_S_AXI_DATA_WIDTH(32),          
		.C_S_AXI_ADDR_WIDTH(32),          
		.C_BASEADDR(32'h00000000),

		.C_AXIS_DATA_WIDTH(C_DATA_WIDTH),
		.C_AXIS_TUSER_WIDTH(C_TUSER_WIDTH)
	) datapath_0 (
    //Datapath clock
	.axis_aclk                      (clk_200),
	.axis_resetn                    (sys_rst_n_c),
	.axi_aclk                       (axi_clk),
	.axi_resetn                     (axi_aresetn),

    // Slave AXI Port
	.S_AXI_AWADDR                  (M0_AXI_awaddr),
	.S_AXI_AWVALID                 (M0_AXI_awvalid),
	.S_AXI_WDATA                   (M0_AXI_wdata),
	.S_AXI_WSTRB                   (M0_AXI_wstrb),
	.S_AXI_WVALID                  (M0_AXI_wvalid),
	.S_AXI_BREADY                  (M0_AXI_bready),
	.S_AXI_ARADDR                  (M0_AXI_araddr),
	.S_AXI_ARVALID                 (M0_AXI_arvalid),
	.S_AXI_RREADY                  (M0_AXI_rready),
	.S_AXI_ARREADY                 (M0_AXI_arready),
	.S_AXI_RDATA                   (M0_AXI_rdata),
	.S_AXI_RRESP                   (M0_AXI_rresp),
	.S_AXI_RVALID                  (M0_AXI_rvalid),
	.S_AXI_WREADY                  (M0_AXI_wready),
	.S_AXI_BRESP                   (M0_AXI_bresp),
	.S_AXI_BVALID                  (M0_AXI_bvalid),
	.S_AXI_AWREADY                 (M0_AXI_awready),
    
    // Interface to and from DMA
    .s_axis_dma_tdata(axis_dma_i_0_tdata),
    .s_axis_dma_tkeep(axis_dma_i_0_tkeep),
    .s_axis_dma_tuser(axis_dma_i_0_tuser),
    .s_axis_dma_tvalid(axis_dma_i_0_tvalid),
    .s_axis_dma_tready(axis_dma_i_0_tready),
    .s_axis_dma_tlast(axis_dma_i_0_tlast),

    .m_axis_dma_tdata(axis_dma_o_0_tdata),
    .m_axis_dma_tkeep(axis_dma_o_0_tkeep),
    .m_axis_dma_tuser(axis_dma_o_0_tuser),
    .m_axis_dma_tvalid(axis_dma_o_0_tvalid),
    .m_axis_dma_tready(axis_dma_o_0_tready),
    .m_axis_dma_tlast(axis_dma_o_0_tlast),

    // Interface to and from Ethernet (CMAC)
    .s_axis_phy_tdata_raw(axis_phy_i_0_tdata),
    .s_axis_phy_tkeep_raw(axis_phy_i_0_tkeep),
    .s_axis_phy_tuser_raw(axis_phy_i_0_tuser),
    .s_axis_phy_tvalid_raw(axis_phy_i_0_tvalid),
    .s_axis_phy_tready_raw(axis_phy_i_0_tready),
    .s_axis_phy_tlast_raw(axis_phy_i_0_tlast),


    .m_axis_phy_tdata_raw(axis_phy_o_0_tdata),
    .m_axis_phy_tkeep_raw(axis_phy_o_0_tkeep),
    .m_axis_phy_tuser_raw(axis_phy_o_0_tuser),
    .m_axis_phy_tvalid_raw(axis_phy_o_0_tvalid),
    .m_axis_phy_tready_raw(axis_phy_o_0_tready),
    .m_axis_phy_tlast_raw(axis_phy_o_0_tlast)
    );

	nf_datapath #(
		.C_S_AXI_DATA_WIDTH(32),          
		.C_S_AXI_ADDR_WIDTH(32),          
		.C_BASEADDR(32'h00000000),

		.C_AXIS_DATA_WIDTH(C_DATA_WIDTH),
		.C_AXIS_TUSER_WIDTH(C_TUSER_WIDTH)
	) datapath_1 (
		//Datapath clock
		.axis_aclk                      (clk_200),
		.axis_resetn                    (sys_rst_n_c),
		.axi_aclk                       (axi_clk),
		.axi_resetn                     (axi_aresetn),

		// Slave AXI Port
		.S_AXI_AWADDR                  (M1_AXI_awaddr),
		.S_AXI_AWVALID                 (M1_AXI_awvalid),
		.S_AXI_WDATA                   (M1_AXI_wdata),
		.S_AXI_WSTRB                   (M1_AXI_wstrb),
		.S_AXI_WVALID                  (M1_AXI_wvalid),
		.S_AXI_BREADY                  (M1_AXI_bready),
		.S_AXI_ARADDR                  (M1_AXI_araddr),
		.S_AXI_ARVALID                 (M1_AXI_arvalid),
		.S_AXI_RREADY                  (M1_AXI_rready),
		.S_AXI_ARREADY                 (M1_AXI_arready),
		.S_AXI_RDATA                   (M1_AXI_rdata),
		.S_AXI_RRESP                   (M1_AXI_rresp),
		.S_AXI_RVALID                  (M1_AXI_rvalid),
		.S_AXI_WREADY                  (M1_AXI_wready),
		.S_AXI_BRESP                   (M1_AXI_bresp),
		.S_AXI_BVALID                  (M1_AXI_bvalid),
		.S_AXI_AWREADY                 (M1_AXI_awready),
		
		// Interface to and from DMA
		.s_axis_dma_tdata(axis_dma_i_1_tdata),
		.s_axis_dma_tkeep(axis_dma_i_1_tkeep),
		.s_axis_dma_tuser(axis_dma_i_1_tuser),
		.s_axis_dma_tvalid(axis_dma_i_1_tvalid),
		.s_axis_dma_tready(axis_dma_i_1_tready),
		.s_axis_dma_tlast(axis_dma_i_1_tlast),

		.m_axis_dma_tdata(axis_dma_o_1_tdata),
		.m_axis_dma_tkeep(axis_dma_o_1_tkeep),
		.m_axis_dma_tuser(axis_dma_o_1_tuser),
		.m_axis_dma_tvalid(axis_dma_o_1_tvalid),
		.m_axis_dma_tready(axis_dma_o_1_tready),
		.m_axis_dma_tlast(axis_dma_o_1_tlast),

		// Interface to and from Ethernet (CMAC)
		.s_axis_phy_tdata_raw(axis_phy_i_1_tdata),
		.s_axis_phy_tkeep_raw(axis_phy_i_1_tkeep),
		.s_axis_phy_tuser_raw(axis_phy_i_1_tuser),
		.s_axis_phy_tvalid_raw(axis_phy_i_1_tvalid),
		.s_axis_phy_tready_raw(axis_phy_i_1_tready),
		.s_axis_phy_tlast_raw(axis_phy_i_1_tlast),


		.m_axis_phy_tdata_raw(axis_phy_o_1_tdata),
		.m_axis_phy_tkeep_raw(axis_phy_o_1_tkeep),
		.m_axis_phy_tuser_raw(axis_phy_o_1_tuser),
		.m_axis_phy_tvalid_raw(axis_phy_o_1_tvalid),
		.m_axis_phy_tready_raw(axis_phy_o_1_tready),
		.m_axis_phy_tlast_raw(axis_phy_o_1_tlast)
    );

	axis_sim_stim_ip0 axis_sim_stim_0 (
		.ACLK            (clk_200),
		.ARESETN         (sys_rst_n_c),

		//axi streaming data interface
		.M_AXIS_TDATA    (axis_phy_stim_0_tdata),
		.M_AXIS_TKEEP    (axis_phy_stim_0_tkeep),
		.M_AXIS_TUSER    (axis_phy_stim_0_tuser),
		.M_AXIS_TVALID   (axis_phy_stim_0_tvalid),
		.M_AXIS_TREADY   (1'b1),
		.M_AXIS_TLAST    (axis_phy_stim_0_tlast),

		.counter         (counter0),
		.activity_stim   (activity_stim0),
		.barrier_req     (barrier_req0),
		.barrier_proceed (barrier_proceed)
	);

	axis_sim_stim_ip1 axis_sim_stim_1 (
		.ACLK            (clk_200),
		.ARESETN         (sys_rst_n_c),
		
		//axi streaming data interface
		.M_AXIS_TDATA    (axis_phy_stim_1_tdata),
		.M_AXIS_TKEEP    (axis_phy_stim_1_tkeep),
		.M_AXIS_TUSER    (axis_phy_stim_1_tuser),
		.M_AXIS_TVALID   (axis_phy_stim_1_tvalid),
		.M_AXIS_TREADY   (1'b1),
		.M_AXIS_TLAST    (axis_phy_stim_1_tlast),

		.counter         (counter1),
		.activity_stim   (activity_stim1),
		.barrier_req     (barrier_req1),
		.barrier_proceed (barrier_proceed)
	);

	axis_sim_stim_ip2 axis_sim_stim_2 (
		.ACLK            (clk_200),
		.ARESETN         (sys_rst_n_c),
		
		//axi streaming data interface
		.M_AXIS_TDATA    (axis_dma_stim_tdata),
		.M_AXIS_TKEEP    (axis_dma_stim_tkeep),
		.M_AXIS_TUSER    (axis_dma_stim_tuser),
		.M_AXIS_TVALID   (axis_dma_stim_tvalid),
		.M_AXIS_TREADY   (axis_dma_stim_tready),
		.M_AXIS_TLAST    (axis_dma_stim_tlast),

		.counter         (counter2),
		.activity_stim   (activity_stim2),
		.barrier_req     (barrier_req2),
		.barrier_proceed (barrier_proceed)
	);

	axis_sim_record_ip0 axis_sim_record_0 (
		.axi_aclk (clk_200),
		// Slave Stream Ports (interface to data path)
		.s_axis_tdata (axis_phy_rec_0_tdata),
		.s_axis_tkeep (axis_phy_rec_0_tkeep),
		.s_axis_tuser (axis_phy_rec_0_tuser),
		.s_axis_tvalid(axis_phy_rec_0_tvalid),
		.s_axis_tready(axis_phy_rec_0_tready),
		.s_axis_tlast (axis_phy_rec_0_tlast),
	
		.counter (counter0),
		.activity_rec(activity_rec0)
	);

	axis_sim_record_ip1 axis_sim_record_1 (
		.axi_aclk (clk_200),
		// Slave Stream Ports (interface to data path)
		.s_axis_tdata (axis_phy_rec_1_tdata),
		.s_axis_tkeep (axis_phy_rec_1_tkeep),
		.s_axis_tuser (axis_phy_rec_1_tuser),
		.s_axis_tvalid(axis_phy_rec_1_tvalid),
		.s_axis_tready(axis_phy_rec_1_tready),
		.s_axis_tlast (axis_phy_rec_1_tlast),
	
		.counter (counter1),
		.activity_rec(activity_rec1)
	);

	axis_sim_record_ip2 axis_sim_record_2 (
		.axi_aclk (clk_200),
		// Slave Stream Ports (interface to data path)
		.s_axis_tdata (axis_dma_rec_tdata),
		.s_axis_tkeep (axis_dma_rec_tkeep),
		.s_axis_tuser (axis_dma_rec_tuser),
		.s_axis_tvalid(axis_dma_rec_tvalid),
		.s_axis_tready(axis_dma_rec_tready),
		.s_axis_tlast (axis_dma_rec_tlast),
	
		.counter (counter2),
		.activity_rec(activity_rec2)
	);

	nf_mac_attachment_ip u_nf_attachment_0 (
		.S_AXI_ACLK            (axi_clk),
		.S_AXI_ARESETN         (axi_resetn),
		.S_AXI_AWADDR          (M2_AXI_AWADDR),
		.S_AXI_AWVALID         (M2_AXI_AWVALID),
		.S_AXI_WDATA           (M2_AXI_WDATA),
		.S_AXI_WSTRB           (M2_AXI_WSTRB),
		.S_AXI_WVALID          (M2_AXI_WVALID),
		.S_AXI_BREADY          (M2_AXI_BREADY),
		.S_AXI_ARADDR          (M2_AXI_ARADDR),
		.S_AXI_ARVALID         (M2_AXI_ARVALID),
		.S_AXI_RREADY          (M2_AXI_RREADY),
		.S_AXI_ARREADY         (M2_AXI_ARREADY),
		.S_AXI_RDATA           (M2_AXI_RDATA),
		.S_AXI_RRESP           (M2_AXI_RRESP),
		.S_AXI_RVALID          (M2_AXI_RVALID),
		.S_AXI_WREADY          (M2_AXI_WREADY),
		.S_AXI_BRESP           (M2_AXI_BRESP),
		.S_AXI_BVALID          (M2_AXI_BVALID),
		.S_AXI_AWREADY         (M2_AXI_AWREADY),

		// 10GE block clk & rst 
		.clk156                (clk_200),  
		.areset_clk156         (!sys_rst_n_c), 
		// RX MAC 64b@clk156 (no backpressure) -> rx_queue 64b@axis_clk
		.m_axis_mac_tdata      (axis_phy_stim_0_tdata),
		.m_axis_mac_tkeep      (axis_phy_stim_0_tkeep),
		.m_axis_mac_tvalid     (axis_phy_stim_0_tvalid),
		.m_axis_mac_tuser_err  (1'b1),       // valid frame
		.m_axis_mac_tuser      (axis_phy_stim_0_tuser),
		.m_axis_mac_tlast      (axis_phy_stim_0_tlast),
		// tx_queue 64b@axis_clk -> mac 64b@clk156
		.s_axis_mac_tdata      (axis_phy_rec_0_tdata),
		.s_axis_mac_tkeep      (axis_phy_rec_0_tkeep),
		.s_axis_mac_tvalid     (axis_phy_rec_0_tvalid),
		.s_axis_mac_tuser_err  (),      //underrun
		.s_axis_mac_tuser      (axis_phy_rec_0_tuser),
		.s_axis_mac_tlast      (axis_phy_rec_0_tlast),
		.s_axis_mac_tready     (axis_phy_rec_0_tready),
		
		// TX/RX DATA channels  
		.interface_number      (8'b0000_0001),
		
		// NFPLUS pipeline clk & rst 
		.axis_aclk             (clk_200),
		.axis_aresetn          (sys_rst_n_c),
		// input from ref pipeline 256b -> MAC
		.s_axis_pipe_tdata     (axis_phy_o_0_tdata),
		.s_axis_pipe_tkeep     (axis_phy_o_0_tkeep),
		.s_axis_pipe_tlast     (axis_phy_o_0_tlast),
		.s_axis_pipe_tuser     (axis_phy_o_0_tuser),
		.s_axis_pipe_tvalid    (axis_phy_o_0_tvalid),
		.s_axis_pipe_tready    (axis_phy_o_0_tready),
		// output to ref pipeline 256b -> DMA
		.m_axis_pipe_tdata     (axis_phy_i_0_tdata),
		.m_axis_pipe_tkeep     (axis_phy_i_0_tkeep),
		.m_axis_pipe_tlast     (axis_phy_i_0_tlast),
		.m_axis_pipe_tuser     (axis_phy_i_0_tuser),
		.m_axis_pipe_tvalid    (axis_phy_i_0_tvalid),
		.m_axis_pipe_tready    (axis_phy_i_0_tready)
	);

	nf_mac_attachment_ip u_nf_attachment_1 (
		.S_AXI_ACLK            (axi_clk),
		.S_AXI_ARESETN         (axi_resetn),
		.S_AXI_AWADDR          (M3_AXI_AWADDR),
		.S_AXI_AWVALID         (M3_AXI_AWVALID),
		.S_AXI_WDATA           (M3_AXI_WDATA),
		.S_AXI_WSTRB           (M3_AXI_WSTRB),
		.S_AXI_WVALID          (M3_AXI_WVALID),
		.S_AXI_BREADY          (M3_AXI_BREADY),
		.S_AXI_ARADDR          (M3_AXI_ARADDR),
		.S_AXI_ARVALID         (M3_AXI_ARVALID),
		.S_AXI_RREADY          (M3_AXI_RREADY),
		.S_AXI_ARREADY         (M3_AXI_ARREADY),
		.S_AXI_RDATA           (M3_AXI_RDATA),
		.S_AXI_RRESP           (M3_AXI_RRESP),
		.S_AXI_RVALID          (M3_AXI_RVALID),
		.S_AXI_WREADY          (M3_AXI_WREADY),
		.S_AXI_BRESP           (M3_AXI_BRESP),
		.S_AXI_BVALID          (M3_AXI_BVALID),
		.S_AXI_AWREADY         (M3_AXI_AWREADY),
		// 10GE block clk & rst 
		.clk156                (clk_200),  
		.areset_clk156         (!sys_rst_n_c), 
		// RX MAC 64b@clk156 (no backpressure) -> rx_queue 64b@axis_clk
		.m_axis_mac_tdata      (axis_phy_stim_1_tdata),
		.m_axis_mac_tkeep      (axis_phy_stim_1_tkeep),
		.m_axis_mac_tvalid     (axis_phy_stim_1_tvalid),
		.m_axis_mac_tuser_err  (1'b1),       // valid frame
		.m_axis_mac_tuser      (axis_phy_stim_1_tuser),
		.m_axis_mac_tlast      (axis_phy_stim_1_tlast),
		// tx_queue 64b@axis_clk -> mac 64b@clk156
		.s_axis_mac_tdata      (axis_phy_rec_1_tdata),
		.s_axis_mac_tkeep      (axis_phy_rec_1_tkeep),
		.s_axis_mac_tvalid     (axis_phy_rec_1_tvalid),
		.s_axis_mac_tuser_err  (),      //underrun
		.s_axis_mac_tuser      (axis_phy_rec_1_tuser),
		.s_axis_mac_tlast      (axis_phy_rec_1_tlast),
		.s_axis_mac_tready     (axis_phy_rec_1_tready),
		
		// TX/RX DATA channels  
		.interface_number      (8'b0000_0001),
		
		// NFPLUS pipeline clk & rst 
		.axis_aclk             (clk_200),
		.axis_aresetn          (sys_rst_n_c),
		// input from ref pipeline 256b -> MAC
		.s_axis_pipe_tdata     (axis_phy_o_1_tdata),
		.s_axis_pipe_tkeep     (axis_phy_o_1_tkeep),
		.s_axis_pipe_tlast     (axis_phy_o_1_tlast),
		.s_axis_pipe_tuser     (axis_phy_o_1_tuser),
		.s_axis_pipe_tvalid    (axis_phy_o_1_tvalid),
		.s_axis_pipe_tready    (axis_phy_o_1_tready),
		// output to ref pipeline 256b -> DMA
		.m_axis_pipe_tdata     (axis_phy_i_1_tdata),
		.m_axis_pipe_tkeep     (axis_phy_i_1_tkeep),
		.m_axis_pipe_tlast     (axis_phy_i_1_tlast),
		.m_axis_pipe_tuser     (axis_phy_i_1_tuser),
		.m_axis_pipe_tvalid    (axis_phy_i_1_tvalid),
		.m_axis_pipe_tready    (axis_phy_i_1_tready)
	);

	nf_mac_attachment_dma_ip u_nf_attachment_dma_0 (
		.S_AXI_ACLK            (axi_clk),
		.S_AXI_ARESETN         (axi_resetn),
		.S_AXI_AWADDR          (M4_AXI_AWADDR),
		.S_AXI_AWVALID         (M4_AXI_AWVALID),
		.S_AXI_WDATA           (M4_AXI_WDATA),
		.S_AXI_WSTRB           (M4_AXI_WSTRB),
		.S_AXI_WVALID          (M4_AXI_WVALID),
		.S_AXI_BREADY          (M4_AXI_BREADY),
		.S_AXI_ARADDR          (M4_AXI_ARADDR),
		.S_AXI_ARVALID         (M4_AXI_ARVALID),
		.S_AXI_RREADY          (M4_AXI_RREADY),
		.S_AXI_ARREADY         (M4_AXI_ARREADY),
		.S_AXI_RDATA           (M4_AXI_RDATA),
		.S_AXI_RRESP           (M4_AXI_RRESP),
		.S_AXI_RVALID          (M4_AXI_RVALID),
		.S_AXI_WREADY          (M4_AXI_WREADY),
		.S_AXI_BRESP           (M4_AXI_BRESP),
		.S_AXI_BVALID          (M4_AXI_BVALID),
		.S_AXI_AWREADY         (M4_AXI_AWREADY),
		// 10GE block clk & rst
		.clk156                (clk_200),
		.areset_clk156         (!sys_rst_n_c),
		// RX MAC 64b@clk156 (no backpressure) -> rx_queue 64b@axis_clk
		.m_axis_mac_tdata      (axis_dma_i_0_raw_tdata),
		.m_axis_mac_tkeep      (axis_dma_i_0_raw_tkeep),
		.m_axis_mac_tvalid     (axis_dma_i_0_raw_tvalid),
		.m_axis_mac_tuser_err  (1'b1),   // valid frame
		.m_axis_mac_tuser      (axis_dma_i_0_raw_tuser),
		.m_axis_mac_tlast      (axis_dma_i_0_raw_tlast),
		// tx_queue 64b@axis_clk -> mac 64b@clk156
		.s_axis_mac_tdata      (axis_dma_o_0_raw_tdata),
		.s_axis_mac_tkeep      (axis_dma_o_0_raw_tkeep),
		.s_axis_mac_tvalid     (axis_dma_o_0_raw_tvalid),
		.s_axis_mac_tuser_err  (),       //underrun
		.s_axis_mac_tuser      (axis_dma_o_0_raw_tuser),
		.s_axis_mac_tlast      (axis_dma_o_0_raw_tlast),
		.s_axis_mac_tready     (axis_dma_o_0_raw_tready),

		// TX/RX DATA channels
		.interface_number      (8'd0),

		// NFPLUS pipeline clk & rst
		.axis_aclk             (clk_200),
		.axis_aresetn          (sys_rst_n_c),
		// input from ref pipeline 256b -> MAC
		.s_axis_pipe_tdata     (axis_dma_o_0_tdata),
		.s_axis_pipe_tkeep     (axis_dma_o_0_tkeep),
		.s_axis_pipe_tlast     (axis_dma_o_0_tlast),
		.s_axis_pipe_tuser     (axis_dma_o_0_tuser),
		.s_axis_pipe_tvalid    (axis_dma_o_0_tvalid),
		.s_axis_pipe_tready    (axis_dma_o_0_tready),
		// output to ref pipeline 256b -> DMA
		.m_axis_pipe_tdata     (axis_dma_i_0_tdata),
		.m_axis_pipe_tkeep     (axis_dma_i_0_tkeep),
		.m_axis_pipe_tlast     (axis_dma_i_0_tlast),
		.m_axis_pipe_tuser     (axis_dma_i_0_tuser),
		.m_axis_pipe_tvalid    (axis_dma_i_0_tvalid),
		.m_axis_pipe_tready    (axis_dma_i_0_tready)
  );

  	nf_mac_attachment_dma_ip u_nf_attachment_dma_1 (
		.S_AXI_ACLK            (axi_clk),
		.S_AXI_ARESETN         (axi_resetn),
		.S_AXI_AWADDR          (M5_AXI_AWADDR),
		.S_AXI_AWVALID         (M5_AXI_AWVALID),
		.S_AXI_WDATA           (M5_AXI_WDATA),
		.S_AXI_WSTRB           (M5_AXI_WSTRB),
		.S_AXI_WVALID          (M5_AXI_WVALID),
		.S_AXI_BREADY          (M5_AXI_BREADY),
		.S_AXI_ARADDR          (M5_AXI_ARADDR),
		.S_AXI_ARVALID         (M5_AXI_ARVALID),
		.S_AXI_RREADY          (M5_AXI_RREADY),
		.S_AXI_ARREADY         (M5_AXI_ARREADY),
		.S_AXI_RDATA           (M5_AXI_RDATA),
		.S_AXI_RRESP           (M5_AXI_RRESP),
		.S_AXI_RVALID          (M5_AXI_RVALID),
		.S_AXI_WREADY          (M5_AXI_WREADY),
		.S_AXI_BRESP           (M5_AXI_BRESP),
		.S_AXI_BVALID          (M5_AXI_BVALID),
		.S_AXI_AWREADY         (M5_AXI_AWREADY),
		// 10GE block clk & rst
		.clk156                (clk_200),
		.areset_clk156         (!sys_rst_n_c),
		// RX MAC 64b@clk156 (no backpressure) -> rx_queue 64b@axis_clk
		.m_axis_mac_tdata      (axis_dma_i_1_raw_tdata),
		.m_axis_mac_tkeep      (axis_dma_i_1_raw_tkeep),
		.m_axis_mac_tvalid     (axis_dma_i_1_raw_tvalid),
		.m_axis_mac_tuser_err  (1'b1),   // valid frame
		.m_axis_mac_tuser      (axis_dma_i_1_raw_tuser),
		.m_axis_mac_tlast      (axis_dma_i_1_raw_tlast),
		// tx_queue 64b@axis_clk -> mac 64b@clk156
		.s_axis_mac_tdata      (axis_dma_o_1_raw_tdata),
		.s_axis_mac_tkeep      (axis_dma_o_1_raw_tkeep),
		.s_axis_mac_tvalid     (axis_dma_o_1_raw_tvalid),
		.s_axis_mac_tuser_err  (),       //underrun
		.s_axis_mac_tuser      (axis_dma_o_1_raw_tuser),
		.s_axis_mac_tlast      (axis_dma_o_1_raw_tlast),
		.s_axis_mac_tready     (axis_dma_o_1_raw_tready),

		// TX/RX DATA channels
		.interface_number      (8'd0),

		// NFPLUS pipeline clk & rst
		.axis_aclk             (clk_200),
		.axis_aresetn          (sys_rst_n_c),
		// input from ref pipeline 256b -> MAC
		.s_axis_pipe_tdata     (axis_dma_o_1_tdata),
		.s_axis_pipe_tkeep     (axis_dma_o_1_tkeep),
		.s_axis_pipe_tlast     (axis_dma_o_1_tlast),
		.s_axis_pipe_tuser     (axis_dma_o_1_tuser),
		.s_axis_pipe_tvalid    (axis_dma_o_1_tvalid),
		.s_axis_pipe_tready    (axis_dma_o_1_tready),
		// output to ref pipeline 256b -> DMA
		.m_axis_pipe_tdata     (axis_dma_i_1_tdata),
		.m_axis_pipe_tkeep     (axis_dma_i_1_tkeep),
		.m_axis_pipe_tlast     (axis_dma_i_1_tlast),
		.m_axis_pipe_tuser     (axis_dma_i_1_tuser),
		.m_axis_pipe_tvalid    (axis_dma_i_1_tvalid),
		.m_axis_pipe_tready    (axis_dma_i_1_tready)
  );
	
	axi_crossbar_0 u_interconnect(
		.aclk          (axi_clk),
		.aresetn       (axi_aresetn),
		.s_axi_awaddr  (S00_AXI_awaddr),
		.s_axi_awprot  (3'b010),
		.s_axi_awvalid (S00_AXI_awvalid),
		.s_axi_awready (S00_AXI_awready),
		.s_axi_wdata   (S00_AXI_wdata  ),
		.s_axi_wstrb   (4'hf),
		.s_axi_wvalid  (S00_AXI_wvalid ),
		.s_axi_wready  (S00_AXI_wready ),
		.s_axi_bresp   (S00_AXI_bresp  ),
		.s_axi_bvalid  (S00_AXI_bvalid ),
		.s_axi_bready  (S00_AXI_bready ),
		.s_axi_araddr  (S00_AXI_araddr[31:0]),
		.s_axi_arprot  (3'b010),
		.s_axi_arvalid (S00_AXI_arvalid ),
		.s_axi_arready (S00_AXI_arready ),
		.s_axi_rdata   (S00_AXI_rdata   ),
		.s_axi_rresp   (S00_AXI_rresp   ),
		.s_axi_rvalid  (S00_AXI_rvalid  ),
		.s_axi_rready  (S00_AXI_rready  ),
		.m_axi_awprot  (),
		.m_axi_awaddr  ({M5_AXI_awaddr[31:0], M4_AXI_awaddr[31:0], M3_AXI_awaddr[31:0], M2_AXI_awaddr[31:0], M1_AXI_awaddr[31:0] ,M0_AXI_awaddr[31:0]}),
		.m_axi_awvalid ({M5_AXI_awvalid,      M4_AXI_awvalid,      M3_AXI_awvalid,      M2_AXI_awvalid,      M1_AXI_awvalid,      M0_AXI_awvalid}),
		.m_axi_awready ({M5_AXI_awready,      M4_AXI_awready,      M3_AXI_awready,      M2_AXI_awready,      M1_AXI_awready,      M0_AXI_awready}),
		.m_axi_wdata   ({M5_AXI_wdata,        M4_AXI_wdata,        M3_AXI_wdata,        M2_AXI_wdata,        M1_AXI_wdata  ,      M0_AXI_wdata  }),
		.m_axi_wstrb   ({M5_AXI_wstrb,        M4_AXI_wstrb,        M3_AXI_wstrb,        M2_AXI_wstrb,        M1_AXI_wstrb  ,      M0_AXI_wstrb  }),
		.m_axi_wvalid  ({M5_AXI_wvalid,       M4_AXI_wvalid,       M3_AXI_wvalid,       M2_AXI_wvalid,       M1_AXI_wvalid ,      M0_AXI_wvalid }),
		.m_axi_wready  ({M5_AXI_wready,       M4_AXI_wready,       M3_AXI_wready,       M2_AXI_wready,       M1_AXI_wready ,      M0_AXI_wready }),
		.m_axi_bresp   ({M5_AXI_bresp,        M4_AXI_bresp,        M3_AXI_bresp,        M2_AXI_bresp,        M1_AXI_bresp  ,      M0_AXI_bresp  }),
		.m_axi_bvalid  ({M5_AXI_bvalid,       M4_AXI_bvalid,       M3_AXI_bvalid,       M2_AXI_bvalid,       M1_AXI_bvalid ,      M0_AXI_bvalid }),
		.m_axi_bready  ({M5_AXI_bready,       M4_AXI_bready,       M3_AXI_bready,       M2_AXI_bready,       M1_AXI_bready ,      M0_AXI_bready }),
		.m_axi_araddr  ({M5_AXI_araddr,       M4_AXI_araddr,       M3_AXI_araddr,       M2_AXI_araddr,       M1_AXI_araddr ,      M0_AXI_araddr }),
		.m_axi_arvalid ({M5_AXI_arvalid,      M4_AXI_arvalid,      M3_AXI_arvalid,      M2_AXI_arvalid,      M1_AXI_arvalid,      M0_AXI_arvalid}),
		.m_axi_arready ({M5_AXI_arready,      M4_AXI_arready,      M3_AXI_arready,      M2_AXI_arready,      M1_AXI_arready,      M0_AXI_arready}),
		.m_axi_rdata   ({M5_AXI_rdata,        M4_AXI_rdata,        M3_AXI_rdata,        M2_AXI_rdata,        M1_AXI_rdata  ,      M0_AXI_rdata  }),
		.m_axi_rresp   ({M5_AXI_rresp,        M4_AXI_rresp,        M3_AXI_rresp,        M2_AXI_rresp,        M1_AXI_rresp  ,      M0_AXI_rresp  }),
		.m_axi_rvalid  ({M5_AXI_rvalid,       M4_AXI_rvalid,       M3_AXI_rvalid,       M2_AXI_rvalid,       M1_AXI_rvalid ,      M0_AXI_rvalid }),
		.m_axi_rready  ({M5_AXI_rready,       M4_AXI_rready,       M3_AXI_rready,       M2_AXI_rready,       M1_AXI_rready ,      M0_AXI_rready }),
		.m_axi_arprot  ()
	);

	axi_sim_transactor_ip axi_sim_transactor_i (
		.axi_aclk      (axi_clk),
		.axi_resetn    (axi_aresetn),
		//AXI Write address channel
		.M_AXI_AWADDR  (S00_AXI_awaddr),
		.M_AXI_AWVALID (S00_AXI_awvalid),
		.M_AXI_AWREADY (S00_AXI_awready),
		// AXI Write data channel
		.M_AXI_WDATA   (S00_AXI_wdata),
		.M_AXI_WSTRB   (S00_AXI_wstrb),
		.M_AXI_WVALID  (S00_AXI_wvalid),
		.M_AXI_WREADY  (S00_AXI_wready),
		//AXI Write response channel
		.M_AXI_BRESP   (S00_AXI_bresp),
		.M_AXI_BVALID  (S00_AXI_bvalid),
		.M_AXI_BREADY  (S00_AXI_bready),
		//AXI Read address channel
		.M_AXI_ARADDR  (S00_AXI_araddr),
		.M_AXI_ARVALID (S00_AXI_arvalid),
		.M_AXI_ARREADY (S00_AXI_arready),
		//AXI Read data & response channel
		.M_AXI_RDATA   (S00_AXI_rdata),
		.M_AXI_RRESP   (S00_AXI_rresp),
		.M_AXI_RVALID  (S00_AXI_rvalid),
		.M_AXI_RREADY  (S00_AXI_rready),
	
		.activity_trans_sim (activity_trans_sim),
		.activity_trans_log (activity_trans_log),
		.barrier_req_trans (barrier_req_trans),
		.barrier_proceed (barrier_proceed)
	);

	barrier_ip barrier_i (
		.activity_stim ({activity_stim2, activity_stim1, activity_stim0}), 
		.activity_rec ({activity_rec2, activity_rec1, activity_rec0}),
		.activity_trans_sim (activity_trans_sim),
		.activity_trans_log (activity_trans_log),
		.barrier_req ({barrier_req2, barrier_req1, barrier_req0}), 
		.barrier_req_trans (barrier_req_trans),
		.barrier_proceed (barrier_proceed)
	);

	reg is_first_transfer;
	reg [7:0] axis_dma_stim_tuser_src_last;

	wire [7:0] axis_dma_stim_tuser_src_current;
	assign axis_dma_stim_tuser_src_current = axis_dma_stim_tuser[23:16];

	wire [7:0] axis_dma_stim_tuser_src = is_first_transfer ? axis_dma_stim_tuser_src_current : axis_dma_stim_tuser_src_last;

	always_ff @(posedge clk_200) begin
		if(sys_rst_n_c) begin
			// Check an axis_dma transfer occurs
			if(axis_dma_stim_tvalid && axis_dma_stim_tready) begin
				if(is_first_transfer) begin
					axis_dma_stim_tuser_src_last <= axis_dma_stim_tuser_src_current;
				end

				// Next transfer is first iff this one is last.
				is_first_transfer <= axis_dma_stim_tlast;
			end
		end else begin
			is_first_transfer <= 1'b1;
			axis_dma_stim_tuser_src_last <= '0;
		end

	end

	// Multiplex the DMA stim to the two different datapths.
	// Fairly simple, just set valid based upon the tuser
	assign axis_dma_i_0_raw_tdata = axis_dma_stim_tdata;
	assign axis_dma_i_0_raw_tvalid = (axis_dma_stim_tuser_src[1]) ? axis_dma_stim_tvalid : 1'b0;
	assign axis_dma_i_0_raw_tlast = axis_dma_stim_tlast;
	assign axis_dma_i_0_raw_tuser = axis_dma_stim_tuser;
	assign axis_dma_i_0_raw_tkeep = axis_dma_stim_tkeep;
	// Choose appropriate tready depending on the destination
	// Definitely not tready if stim not tvalid.
	assign axis_dma_stim_tready = axis_dma_stim_tvalid ? ((axis_dma_stim_tuser_src[1]) ? axis_dma_i_0_raw_tready
		: ((axis_dma_stim_tuser_src[3]) ? axis_dma_i_1_raw_tready : 1'b0)) : 1'b0;

	assign axis_dma_i_1_raw_tdata = axis_dma_stim_tdata;
	assign axis_dma_i_1_raw_tvalid = (axis_dma_stim_tuser_src[3]) ? axis_dma_stim_tvalid : 1'b0;
	assign axis_dma_i_1_raw_tlast = axis_dma_stim_tlast;
	assign axis_dma_i_1_raw_tuser = axis_dma_stim_tuser;
	assign axis_dma_i_1_raw_tkeep = axis_dma_stim_tkeep;

	// Multiplex the DMA output (two streams) into a single stream for recording
	// In comparison more difficult as we must decide when to take from each.
	reg curr_datapath; // 0 for datapath 0, 1 for datapath 1
	reg need_more_data;

	assign axis_dma_rec_tdata = curr_datapath ?  axis_dma_o_1_raw_tdata :  axis_dma_o_0_raw_tdata;
	assign axis_dma_rec_tvalid = curr_datapath ? axis_dma_o_1_raw_tvalid : axis_dma_o_0_raw_tvalid;
	assign axis_dma_rec_tlast = curr_datapath ?  axis_dma_o_1_raw_tlast :  axis_dma_o_0_raw_tlast;
	assign axis_dma_rec_tuser = curr_datapath ?  axis_dma_o_1_raw_tuser :  axis_dma_o_0_raw_tuser;
	assign axis_dma_rec_tkeep = curr_datapath ?  axis_dma_o_1_raw_tkeep :  axis_dma_o_0_raw_tkeep;

	// Ready only if we are the current datapath selected.
	assign axis_dma_o_0_raw_tready = curr_datapath == 0 && axis_dma_rec_tready;
	assign axis_dma_o_1_raw_tready = curr_datapath == 1 && axis_dma_rec_tready;

	always_ff @(posedge clk_200) begin
		if(sys_rst_n_c) begin
			// Allowed to swap datapaths when there is no data, but only if not mid transaction
			if(!axis_dma_rec_tvalid && !need_more_data) begin
				// Swap datapaths if the other port has data
				curr_datapath <= curr_datapath ? (axis_dma_o_0_raw_tvalid ? 0 : 1) : (axis_dma_o_1_raw_tvalid ? 1 : 0);
				need_more_data <= 0;
			end else if(axis_dma_rec_tvalid && axis_dma_rec_tready) begin
				if(axis_dma_rec_tlast) begin
					// The last transaction: swap to the other datapath but only if it is valid
					need_more_data <= 0;
					// i.e. if we are 1, go to 0 if it is valid, if we are 0, go to 1 if it is valid.
					curr_datapath <= curr_datapath ? (axis_dma_o_0_raw_tvalid ? 0 : 1) : (axis_dma_o_1_raw_tvalid ? 1 : 0);
				end else begin
					// Not the last transaction: make sure to stick with this datapath until that point
					need_more_data <= 1;
				end
			end
		end else begin
			curr_datapath <= 0;
			need_more_data <= 0;
		end
	end
endmodule

