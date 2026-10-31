/*
 * Copyright (c) 2021 University of Cambridge
 * All rights reserved.
 *
 * This software was developed by the University of Cambridge Computer
 * Laboratory under EPSRC EARL Project EP/P025374/1 alongside support
 * from Xilinx Inc.
 *
 * @NETFPGA_LICENSE_HEADER_START@
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *  http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * @NETFPGA_LICENSE_HEADER_END@
 *
 */
`default_nettype none
`timescale 1ns/1ns

module top #(
	parameter SIMULATIOM                   = "FALSE",
	parameter BOARD                        = "AU280",
	parameter C_DATA_WIDTH              = 512,
	parameter C_TUSER_WIDTH             = 128,
	parameter NF_C_S_AXI_DATA_WIDTH        = 32,
	parameter NF_C_S_AXI_ADDR_WIDTH        = 32
)(	
`ifdef __au280__
	output wire                    hbm_cattrip,
	input  wire              [3:0] satellite_gpio,
`elsif __au50__
	output wire                    hbm_cattrip,
	input  wire              [1:0] satellite_gpio,
`elsif __au55n__
	output wire                    hbm_cattrip,
	input  wire              [3:0] satellite_gpio,
`elsif __au55c__
	output wire                    hbm_cattrip,
	input  wire              [3:0] satellite_gpio,
`elsif __au200__
	//output                   [1:0] qsfp_resetl,
	//input                    [1:0] qsfp_modprsl,
	//input                    [1:0] qsfp_intl,
	//output                   [1:0] qsfp_lpmode,
	//output                   [1:0] qsfp_modsell,
	input  wire              [3:0] satellite_gpio,
`elsif __au250__
	//output                   [1:0] qsfp_resetl,
	//input                    [1:0] qsfp_modprsl,
	//input                    [1:0] qsfp_intl,
	//output                   [1:0] qsfp_lpmode,
	//output                   [1:0] qsfp_modsell,
	input  wire              [3:0] satellite_gpio,
`elsif __au45n__
	input  wire              [1:0] satellite_gpio,
`endif
	input wire QSFP0_CLOCK_P,
	input wire QSFP0_CLOCK_N,
	input wire QSFP1_CLOCK_P,
	input wire QSFP1_CLOCK_N,

	/* QSFP port 0 */
`ifndef BOARD_AU280
	output wire [1:0] QSFP0_FS,

	input  wire       QSFP0_INTL,
	output wire       QSFP0_LPMODE,
	input  wire       QSFP0_MODPRSL,
	output wire       QSFP0_MODSELL,
	output wire       QSFP0_RESETL,
`else 
	output wire       QSFP0_FS,
`endif /* BOARD_AU280 */
	output wire       QSFP0_RESET,

	output wire [3:0] QSFP0_TX_P,
	output wire [3:0] QSFP0_TX_N,
	input  wire [3:0] QSFP0_RX_P,
	input  wire [3:0] QSFP0_RX_N,
	
	/* QSFP port 1 */
`ifndef BOARD_AU280
	output wire [1:0] QSFP1_FS,

	input  wire       QSFP1_INTL,
	output wire       QSFP1_LPMODE,
	input  wire       QSFP1_MODPRSL,
	output wire       QSFP1_MODSELL,
	output wire       QSFP1_RESETL,
`else 
	output wire       QSFP1_FS,
`endif /* BOARD_AU280 */
	output wire       QSFP1_RESET,

	output wire [3:0] QSFP1_TX_P,
	output wire [3:0] QSFP1_TX_N,
	input  wire [3:0] QSFP1_RX_P,
	input  wire [3:0] QSFP1_RX_N,

	// Satellite core
	input  wire       satellite_uart_0_rxd,
	output wire       satellite_uart_0_txd,

	input  wire         sysclk_p,
	input  wire         sysclk_n,

	input  wire         pci_clk_p,
	input  wire         pci_clk_n,
	input  wire         pci_rst_n,

	output wire [15:0]  pcie_txp,
	output wire [15:0]  pcie_txn,
	input  wire [15:0]  pcie_rxp,
	input  wire [15:0]  pcie_rxn
);

//`ifdef BOARD_AU280
//  assign STAT_CATTRIP = 1'b0;
//`endif 

`ifndef BOARD_AU280
  // QSFP Clock for 156.25MHz (2'b01)
  // QSFP Clock for 161MHz (2'b1X)
  assign QSFP0_FS      = 2'b11;
  assign QSFP0_RESET   = 1'b0;
  assign QSFP0_LPMODE  = 1'b0;
  assign QSFP0_MODSELL = 1'b0;
  assign QSFP0_RESETL  = 1'b1;

  // QSFP Clock for 156.25MHz (2'b01)
  // QSFP Clock for 161MHz (2'b1X)
  assign QSFP1_FS      = 2'b11;
  assign QSFP1_RESET   = 1'b0;
  assign QSFP1_LPMODE  = 1'b0;
  assign QSFP1_MODSELL = 1'b0;
  assign QSFP1_RESETL  = 1'b1;
`else
  // QSFP Clock for 156.25MHz
  assign QSFP0_FS = 1'b0;
  assign QSFP0_RESET = 1'b0;
  // QSFP Clock for 156.25MHz
  assign QSFP1_FS = 1'b0;
  assign QSFP1_RESET = 1'b0;
`endif /*BOARD_AU280*/

  /* clock infrastracture */
  wire sysclk_ibufds;
  IBUFDS IBUFDS_sysclk (
    .I(sysclk_p),
    .IB(sysclk_n),
    .O(sysclk_ibufds)
  );

  wire sys_clk;
  reg clk_div = 1'b0;
  always @ (posedge sysclk_ibufds)
    clk_div <= ~clk_div;
  BUFG bufg_clk (
    .I  (clk_div),
    .O  (sys_clk)
  );

  reg [13:0] cold_counter = 14'd0;
  reg sys_rst;
  always @ (posedge sys_clk) begin
    if (cold_counter != 14'h10) begin
      cold_counter <= cold_counter + 14'd1;
      sys_rst <= 1'b1;
    end
    else begin
      sys_rst <= 1'b0;
    end
  end

  reg [9:0] core_rst_cnt = 10'd0;
  reg core_rst_reg;
  always @ (posedge core_clk) begin
    if (core_rst_cnt != 10'h3ff) begin
      core_rst_cnt <= core_rst_cnt + 10'd1;
      core_rst_reg <= 1'b1;
    end
    else begin
      core_rst_reg <= 1'b0;
    end
  end
  wire core_rst;
  assign   core_rst  = core_rst_reg;

  wire axis_aclk, axil_aclk_250m;
  wire axis_rst, axil_rst_250m;

  wire core_clk;
  wire locked;

  clk_wiz_1 u_clk_wiz_1 (
    .clk_out1(core_clk),
    .reset   (axis_rst),
    .locked  (locked),
    .clk_in1 (axis_aclk)      //  DMA clock (250MHz)
  );

  //-- AXI Master Write Address Channel
  wire [31:0] m_axil_awaddr;
  wire [2:0]  m_axil_awprot;
  wire        m_axil_awvalid;
  wire        m_axil_awready;

  //-- AXI Master Write Data Channel
  wire [31:0] m_axil_wdata;
  wire  [3:0] m_axil_wstrb = 4'hf;
  wire        m_axil_wvalid;
  wire        m_axil_wready;

  //-- AXI Master Write Response Channel
  wire        m_axil_bvalid;
  wire        m_axil_bready;

  //-- AXI Master Read Address Channel
  wire [31:0] m_axil_araddr;
  wire [2:0]  m_axil_arprot;
  wire        m_axil_arvalid;
  wire        m_axil_arready;

  //-- AXI Master Read Data Channel
  wire [31:0] m_axil_rdata;
  wire [1:0]  m_axil_rresp;
  wire        m_axil_rvalid;
  wire        m_axil_rready;
  wire [1:0]  m_axil_bresp;


  //-- AXI Master Write Address Channel
  wire [31:0] s_axil_awaddr;
  wire [2:0]  s_axil_awprot;
  wire        s_axil_awvalid;
  wire        s_axil_awready;

  //-- AXI Master Write Data Channel
  wire [31:0] s_axil_wdata;
  wire  [3:0] s_axil_wstrb;
  wire        s_axil_wvalid;
  wire        s_axil_wready;

  //-- AXI Master Write Response Channel
  wire        s_axil_bvalid;
  wire        s_axil_bready;

  //-- AXI Master Read Address Channel
  wire [31:0] s_axil_araddr;
  wire [2:0]  s_axil_arprot;
  wire        s_axil_arvalid;
  wire        s_axil_arready;

  //-- AXI Master Read Data Channel
  wire [31:0] s_axil_rdata;
  wire [1:0]  s_axil_rresp;
  wire        s_axil_rvalid;
  wire        s_axil_rready;
  wire [1:0]  s_axil_bresp;

  wire [C_DATA_WIDTH-1:0]         axis_dma_o_0_tdata,  axis_dma_o_1_tdata;
  wire                            axis_dma_o_0_tvalid, axis_dma_o_1_tvalid;
  wire                            axis_dma_o_0_tlast,  axis_dma_o_1_tlast;
  wire [C_TUSER_WIDTH-1:0]        axis_dma_o_0_tuser,  axis_dma_o_1_tuser;
  wire [(C_DATA_WIDTH/8)-1:0]     axis_dma_o_0_tkeep,  axis_dma_o_1_tkeep;
  wire                            axis_dma_o_0_tready, axis_dma_o_1_tready;

  wire [C_DATA_WIDTH-1:0]         axis_dma_i_0_tdata,  axis_dma_i_1_tdata;
  wire                            axis_dma_i_0_tvalid, axis_dma_i_1_tvalid;
  wire                            axis_dma_i_0_tlast,  axis_dma_i_1_tlast;
  wire [C_TUSER_WIDTH-1:0]        axis_dma_i_0_tuser,  axis_dma_i_1_tuser;
  wire [(C_DATA_WIDTH/8)-1:0]     axis_dma_i_0_tkeep,  axis_dma_i_1_tkeep;
  wire                            axis_dma_i_0_tready, axis_dma_i_1_tready;

  wire [C_DATA_WIDTH-1:0]         axis_phy_i_0_tdata , axis_phy_i_1_tdata ;
  wire [(C_DATA_WIDTH/8)-1:0]     axis_phy_i_0_tkeep , axis_phy_i_1_tkeep ;
  wire                            axis_phy_i_0_tlast , axis_phy_i_1_tlast ;
  wire                            axis_phy_i_0_tready, axis_phy_i_1_tready;
  wire [C_TUSER_WIDTH-1:0]        axis_phy_i_0_tuser , axis_phy_i_1_tuser ;
  wire                            axis_phy_i_0_tvalid, axis_phy_i_1_tvalid;

  wire [C_DATA_WIDTH-1:0]         axis_phy_o_0_tdata , axis_phy_o_1_tdata ;
  wire [(C_DATA_WIDTH/8)-1:0]     axis_phy_o_0_tkeep , axis_phy_o_1_tkeep ;
  wire                            axis_phy_o_0_tlast , axis_phy_o_1_tlast ;
  wire                            axis_phy_o_0_tready, axis_phy_o_1_tready;
  wire [C_TUSER_WIDTH-1:0]        axis_phy_o_0_tuser , axis_phy_o_1_tuser ;
  wire                            axis_phy_o_0_tvalid, axis_phy_o_1_tvalid;
  // ----------------------------------------------------------
  //      nf_datapaths (one per QDMA/MAC port)
  // ----------------------------------------------------------

  nf_datapath #(
		.C_S_AXI_DATA_WIDTH(32),          
		.C_S_AXI_ADDR_WIDTH(32),          
		.C_BASEADDR(32'h00000000),

		.C_AXIS_DATA_WIDTH(C_DATA_WIDTH),
		.C_AXIS_TUSER_WIDTH(C_TUSER_WIDTH)
	) datapath_0 (
    // Datapath clock
    .axis_aclk   (core_clk),
    .axis_resetn (!core_rst),
    // Registers clock
    .axi_aclk    (core_clk),
    .axi_resetn  (!core_rst),

    // Slave AXI Port
    .S_AXI_AWADDR                  (s_axil_awaddr),
    .S_AXI_AWVALID                 (s_axil_awvalid),
    .S_AXI_WDATA                   (s_axil_wdata),
    .S_AXI_WSTRB                   (s_axil_wstrb),
    .S_AXI_WVALID                  (s_axil_wvalid),
    .S_AXI_BREADY                  (s_axil_bready),
    .S_AXI_ARADDR                  (s_axil_araddr),
    .S_AXI_ARVALID                 (s_axil_arvalid),
    .S_AXI_RREADY                  (s_axil_rready),
    .S_AXI_ARREADY                 (s_axil_arready),
    .S_AXI_RDATA                   (s_axil_rdata),
    .S_AXI_RRESP                   (s_axil_rresp),
    .S_AXI_RVALID                  (s_axil_rvalid),
    .S_AXI_WREADY                  (s_axil_wready),
    .S_AXI_BRESP                   (s_axil_bresp),
    .S_AXI_BVALID                  (s_axil_bvalid),
    .S_AXI_AWREADY                 (s_axil_awready),
    
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
    .s_axis_phy_tdata(axis_phy_i_0_tdata),
    .s_axis_phy_tkeep(axis_phy_i_0_tkeep),
    .s_axis_phy_tuser(axis_phy_i_0_tuser),
    .s_axis_phy_tvalid(axis_phy_i_0_tvalid),
    .s_axis_phy_tready(axis_phy_i_0_tready),
    .s_axis_phy_tlast(axis_phy_i_0_tlast),


    .m_axis_phy_tdata(axis_phy_o_0_tdata),
    .m_axis_phy_tkeep(axis_phy_o_0_tkeep),
    .m_axis_phy_tuser(axis_phy_o_0_tuser),
    .m_axis_phy_tvalid(axis_phy_o_0_tvalid),
    .m_axis_phy_tready(axis_phy_o_0_tready),
    .m_axis_phy_tlast(axis_phy_o_0_tlast)
    );

	nf_datapath #(
		.C_S_AXI_DATA_WIDTH(32),          
		.C_S_AXI_ADDR_WIDTH(32),          
		.C_BASEADDR(32'h00000000),

		.C_AXIS_DATA_WIDTH(C_DATA_WIDTH),
		.C_AXIS_TUSER_WIDTH(C_TUSER_WIDTH)
	) datapath_1 (
    //Datapath clock
    .axis_aclk   (core_clk),
    .axis_resetn (!core_rst),
    //Registers clock
    .axi_aclk    (core_clk),
    .axi_resetn  (!core_rst),
		// Slave AXI Port
		// TODO: Need an AXI crossbar to connect these two modules
		// Want each at a different base address.
		.S_AXI_AWADDR                  (s_axil_awaddr),
		.S_AXI_AWVALID                 (s_axil_awvalid),
		.S_AXI_WDATA                   (s_axil_wdata),
		.S_AXI_WSTRB                   (s_axil_wstrb),
		.S_AXI_WVALID                  (s_axil_wvalid),
		.S_AXI_BREADY                  (s_axil_bready),
		.S_AXI_ARADDR                  (s_axil_araddr),
		.S_AXI_ARVALID                 (s_axil_arvalid),
		.S_AXI_RREADY                  (s_axil_rready),
		.S_AXI_ARREADY                 (s_axil_arready),
		.S_AXI_RDATA                   (s_axil_rdata),
		.S_AXI_RRESP                   (s_axil_rresp),
		.S_AXI_RVALID                  (s_axil_rvalid),
		.S_AXI_WREADY                  (s_axil_wready),
		.S_AXI_BRESP                   (s_axil_bresp),
		.S_AXI_BVALID                  (s_axil_bvalid),
		.S_AXI_AWREADY                 (s_axil_awready),
		
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
		.s_axis_phy_tdata(axis_phy_i_1_tdata),
		.s_axis_phy_tkeep(axis_phy_i_1_tkeep),
		.s_axis_phy_tuser(axis_phy_i_1_tuser),
		.s_axis_phy_tvalid(axis_phy_i_1_tvalid),
		.s_axis_phy_tready(axis_phy_i_1_tready),
		.s_axis_phy_tlast(axis_phy_i_1_tlast),


		.m_axis_phy_tdata(axis_phy_o_1_tdata),
		.m_axis_phy_tkeep(axis_phy_o_1_tkeep),
		.m_axis_phy_tuser(axis_phy_o_1_tuser),
		.m_axis_phy_tvalid(axis_phy_o_1_tvalid),
		.m_axis_phy_tready(axis_phy_o_1_tready),
		.m_axis_phy_tlast(axis_phy_o_1_tlast)
    );

  axi_clock_converter_0 u_clk_conv (
    .s_axi_aclk    (axil_aclk_250m),
    .s_axi_aresetn (!axil_rst_250m),
    .s_axi_awaddr  (m_axil_awaddr),
    .s_axi_awprot  (0),
    .s_axi_awvalid (m_axil_awvalid),
    .s_axi_awready (m_axil_awready),
    .s_axi_wdata   (m_axil_wdata  ),
    .s_axi_wstrb   (4'b1111),
    .s_axi_wvalid  (m_axil_wvalid),
    .s_axi_wready  (m_axil_wready),
    .s_axi_bresp   (m_axil_bresp ),
    .s_axi_bvalid  (m_axil_bvalid),
    .s_axi_bready  (m_axil_bready),
    .s_axi_araddr  (m_axil_araddr),
    .s_axi_arprot  (0),
    .s_axi_arvalid (m_axil_arvalid),
    .s_axi_arready (m_axil_arready),
    .s_axi_rdata   (m_axil_rdata  ),
    .s_axi_rresp   (m_axil_rresp  ),
    .s_axi_rvalid  (m_axil_rvalid ),
    .s_axi_rready  (m_axil_rready ),
    .m_axi_aclk    (core_clk),
    .m_axi_aresetn (!core_rst),
    .m_axi_awaddr  (s_axil_awaddr),
    .m_axi_awprot  (),
    .m_axi_awvalid (s_axil_awvalid),
    .m_axi_awready (s_axil_awready),
    .m_axi_wdata   (s_axil_wdata),
    .m_axi_wstrb   (s_axil_wstrb),
    .m_axi_wvalid  (s_axil_wvalid),
    .m_axi_wready  (s_axil_wready),
    .m_axi_bresp   (s_axil_bresp ),
    .m_axi_bvalid  (s_axil_bvalid),
    .m_axi_bready  (s_axil_bready),
    .m_axi_araddr  (s_axil_araddr),
    .m_axi_arprot  (),
    .m_axi_arvalid (s_axil_arvalid),
    .m_axi_arready (s_axil_arready),
    .m_axi_rdata   (s_axil_rdata  ),
    .m_axi_rresp   (s_axil_rresp  ),
    .m_axi_rvalid  (s_axil_rvalid ),
    .m_axi_rready  (s_axil_rready )
  );

  top_wrapper #(
    .C_TDATA_WIDTH    (C_DATA_WIDTH),
    .C_TUSER_WIDTH    (C_TUSER_WIDTH)
  ) u_top_wrapper (
`ifdef __au280__
    .hbm_cattrip    (hbm_cattrip   ),
    .satellite_gpio (satellite_gpio),
`elsif __au50__
    .hbm_cattrip    (hbm_cattrip   ),
    .satellite_gpio (satellite_gpio),
`elsif __au55n__
    .hbm_cattrip    (hbm_cattrip   ),
    .satellite_gpio (satellite_gpio),
`elsif __au55c__
    .hbm_cattrip    (hbm_cattrip   ),
    .satellite_gpio (satellite_gpio),
`elsif __au200__
    .qsfp_resetl    (/*qsfp_resetl   */),
    .qsfp_modprsl   (/*qsfp_modprsl  */),
    .qsfp_intl      (/*qsfp_intl     */),
    .qsfp_lpmode    (/*qsfp_lpmode   */),
    .qsfp_modsell   (/*qsfp_modsell  */),
    .satellite_gpio (satellite_gpio),
`elsif __au250__
    .qsfp_resetl    (/*qsfp_resetl   */),
    .qsfp_modprsl   (/*qsfp_modprsl  */),
    .qsfp_intl      (/*qsfp_intl     */),
    .qsfp_lpmode    (/*qsfp_lpmode   */),
    .qsfp_modsell   (/*qsfp_modsell  */),
    .satellite_gpio (satellite_gpio),
`elsif __au45n__
    .satellite_gpio (satellite_gpio),
`endif
    // QSFP port0
    .qsfp0_rxp         (QSFP0_RX_P),
    .qsfp0_rxn         (QSFP0_RX_N),
    .qsfp0_txp         (QSFP0_TX_P),
    .qsfp0_txn         (QSFP0_TX_N),
    // QSFP port1
    .qsfp1_rxp         (QSFP1_RX_P),
    .qsfp1_rxn         (QSFP1_RX_N),
    .qsfp1_txp         (QSFP1_TX_P),
    .qsfp1_txn         (QSFP1_TX_N),
    // QSFP CLK0
    .qsfp0_clk_p       (QSFP0_CLOCK_P),
    .qsfp0_clk_n       (QSFP0_CLOCK_N),
    // QSFP CLK1
    .qsfp1_clk_p       (QSFP1_CLOCK_P),
    .qsfp1_clk_n       (QSFP1_CLOCK_N),

    .pcie_txp          (pcie_txp),
    .pcie_txn          (pcie_txn),
    .pcie_rxp          (pcie_rxp),
    .pcie_rxn          (pcie_rxn),
    // PCIe CLK
    .pcie_clk_p        (pci_clk_p),
    .pcie_clk_n        (pci_clk_n),
    .pcie_rst_n        (pci_rst_n),
    // Satellite core
    .satellite_uart_0_rxd(satellite_uart_0_rxd),
    .satellite_uart_0_txd(satellite_uart_0_txd),

    .m_axil_awvalid    (m_axil_awvalid),
    .m_axil_awaddr     (m_axil_awaddr ),
    .m_axil_awready    (m_axil_awready),
    .m_axil_wvalid     (m_axil_wvalid ),
    .m_axil_wdata      (m_axil_wdata  ),
    .m_axil_wready     (m_axil_wready ),
    .m_axil_bvalid     (m_axil_bvalid ),
    .m_axil_bresp      (m_axil_bresp  ),
    .m_axil_bready     (m_axil_bready ),
    .m_axil_arvalid    (m_axil_arvalid),
    .m_axil_araddr     (m_axil_araddr ),
    .m_axil_arready    (m_axil_arready),
    .m_axil_rvalid     (m_axil_rvalid ),
    .m_axil_rdata      (m_axil_rdata  ),
    .m_axil_rresp      (m_axil_rresp  ),
    .m_axil_rready     (m_axil_rready ),
    // Slave Stream Ports
    .axis_dma_o_0_tdata  (axis_dma_o_0_tdata ),
    .axis_dma_o_0_tkeep  (axis_dma_o_0_tkeep ),
    .axis_dma_o_0_tuser  (axis_dma_o_0_tuser ),
    .axis_dma_o_0_tvalid (axis_dma_o_0_tvalid),
    .axis_dma_o_0_tready (axis_dma_o_0_tready),
    .axis_dma_o_0_tlast  (axis_dma_o_0_tlast ),
    // Master Stream Ports
    .axis_dma_i_0_tdata  (axis_dma_i_0_tdata ),
    .axis_dma_i_0_tkeep  (axis_dma_i_0_tkeep ),
    .axis_dma_i_0_tuser  (axis_dma_i_0_tuser ),
    .axis_dma_i_0_tvalid (axis_dma_i_0_tvalid),
    .axis_dma_i_0_tready (axis_dma_i_0_tready),
    .axis_dma_i_0_tlast  (axis_dma_i_0_tlast ),

    .axis_dma_o_1_tdata  (axis_dma_o_1_tdata ),
    .axis_dma_o_1_tkeep  (axis_dma_o_1_tkeep ),
    .axis_dma_o_1_tuser  (axis_dma_o_1_tuser ),
    .axis_dma_o_1_tvalid (axis_dma_o_1_tvalid),
    .axis_dma_o_1_tready (axis_dma_o_1_tready),
    .axis_dma_o_1_tlast  (axis_dma_o_1_tlast ),
    // Master Stream Ports
    .axis_dma_i_1_tdata  (axis_dma_i_1_tdata ),
    .axis_dma_i_1_tkeep  (axis_dma_i_1_tkeep ),
    .axis_dma_i_1_tuser  (axis_dma_i_1_tuser ),
    .axis_dma_i_1_tvalid (axis_dma_i_1_tvalid),
    .axis_dma_i_1_tready (axis_dma_i_1_tready),
    .axis_dma_i_1_tlast  (axis_dma_i_1_tlast ),
    // Slave Stream Ports
    .axis_phy_o_0_tdata    (axis_phy_o_0_tdata ),
    .axis_phy_o_0_tkeep    (axis_phy_o_0_tkeep ),
    .axis_phy_o_0_tuser    (axis_phy_o_0_tuser ),
    .axis_phy_o_0_tvalid   (axis_phy_o_0_tvalid),
    .axis_phy_o_0_tready   (axis_phy_o_0_tready),
    .axis_phy_o_0_tlast    (axis_phy_o_0_tlast ),
    // Slave Stream Ports
    .axis_phy_o_1_tdata    (axis_phy_o_1_tdata ),
    .axis_phy_o_1_tkeep    (axis_phy_o_1_tkeep ),
    .axis_phy_o_1_tuser    (axis_phy_o_1_tuser ),
    .axis_phy_o_1_tvalid   (axis_phy_o_1_tvalid),
    .axis_phy_o_1_tready   (axis_phy_o_1_tready),
    .axis_phy_o_1_tlast    (axis_phy_o_1_tlast ),
    // Master Stream Ports
    .axis_phy_i_0_tdata    (axis_phy_i_0_tdata ),
    .axis_phy_i_0_tkeep    (axis_phy_i_0_tkeep ),
    .axis_phy_i_0_tuser    (axis_phy_i_0_tuser ),
    .axis_phy_i_0_tvalid   (axis_phy_i_0_tvalid),
    .axis_phy_i_0_tready   (axis_phy_i_0_tready),
    .axis_phy_i_0_tlast    (axis_phy_i_0_tlast ),
    // Master Stream Ports
    .axis_phy_i_1_tdata    (axis_phy_i_1_tdata ),
    .axis_phy_i_1_tkeep    (axis_phy_i_1_tkeep ),
    .axis_phy_i_1_tuser    (axis_phy_i_1_tuser ),
    .axis_phy_i_1_tvalid   (axis_phy_i_1_tvalid),
    .axis_phy_i_1_tready   (axis_phy_i_1_tready),
    .axis_phy_i_1_tlast    (axis_phy_i_1_tlast ),

    .core_clk           (core_clk),
    .core_rst           (core_rst),
    .axis_aclk          (axis_aclk),
    .axil_aclk          (axil_aclk_250m),
    .axis_rst           (axis_rst),
    .axil_rst           (axil_rst_250m)
  );

endmodule 
`default_nettype wire
