/*
 * Copyright (c) 2021 Yuta Tokusashi
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

module top_wrapper #(
	parameter C_TDATA_WIDTH    = 512,
	parameter C_TUSER_WIDTH    = 128
)(
`ifdef __au280__
	output wire                    hbm_cattrip,
	input  wire              [3:0] satellite_gpio,
`elsif __au50__
	output                         hbm_cattrip,
	input                    [1:0] satellite_gpio,
`elsif __au55n__
	output                         hbm_cattrip,
	input                    [3:0] satellite_gpio,
`elsif __au55c__
	output                         hbm_cattrip,
	input                    [3:0] satellite_gpio,
`elsif __au200__
	output                   [1:0] qsfp_resetl,
	input                    [1:0] qsfp_modprsl,
	input                    [1:0] qsfp_intl,
	output                   [1:0] qsfp_lpmode,
	output                   [1:0] qsfp_modsell,
	input                    [3:0] satellite_gpio,
`elsif __au250__
	output                   [1:0] qsfp_resetl,
	input                    [1:0] qsfp_modprsl,
	input                    [1:0] qsfp_intl,
	output                   [1:0] qsfp_lpmode,
	output                   [1:0] qsfp_modsell,
	input                    [3:0] satellite_gpio,
`elsif __au45n__
	input                    [1:0] satellite_gpio,
`endif
	// QSFP port0
	input wire [3:0]                  qsfp0_rxp,
	input wire [3:0]                  qsfp0_rxn,
	output wire [3:0]                  qsfp0_txp,
	output wire [3:0]                  qsfp0_txn,
	// QSFP port1
	input wire [3:0]                  qsfp1_rxp,
	input wire [3:0]                  qsfp1_rxn,
	output wire [3:0]                  qsfp1_txp,
	output wire [3:0]                  qsfp1_txn,
	// QSFP CLK0
	input wire                    qsfp0_clk_p,
	input wire                    qsfp0_clk_n,
	// QSFP CLK1
	input wire                    qsfp1_clk_p,
	input wire                    qsfp1_clk_n,

	output wire [15:0]                 pcie_txp,
	output wire [15:0]                 pcie_txn,
	input  wire [15:0]                 pcie_rxp,
	input  wire [15:0]                 pcie_rxn,
	// PCIe CLK
	input  wire                   pcie_clk_p,
	input  wire                   pcie_clk_n,
	input  wire                   pcie_rst_n,

	// Satellite core
	input  wire                   satellite_uart_0_rxd,
	output wire                   satellite_uart_0_txd,

	output wire                   m_axil_awvalid,
	output wire            [31:0] m_axil_awaddr,
	input  wire                   m_axil_awready,
	output wire                   m_axil_wvalid,
	output wire            [31:0] m_axil_wdata,
	input  wire                   m_axil_wready,
	input  wire                   m_axil_bvalid,
	input  wire             [1:0] m_axil_bresp,
	output wire                   m_axil_bready,
	output wire                   m_axil_arvalid,
	output wire            [31:0] m_axil_araddr,
	input  wire                   m_axil_arready,
	input  wire                   m_axil_rvalid,
	input  wire            [31:0] m_axil_rdata,
	input  wire             [1:0] m_axil_rresp,
	output wire                   m_axil_rready,
	// Slave Stream Ports
	input  wire [C_TDATA_WIDTH-1:0]     axis_dma_o_0_tdata,
	input  wire [(C_TDATA_WIDTH/8)-1:0] axis_dma_o_0_tkeep,
	input  wire [C_TUSER_WIDTH-1:0]     axis_dma_o_0_tuser,
	input  wire                         axis_dma_o_0_tvalid,
	output wire                         axis_dma_o_0_tready,
	input  wire                         axis_dma_o_0_tlast, 

    input  wire [C_TDATA_WIDTH-1:0]     axis_dma_o_1_tdata,
	input  wire [(C_TDATA_WIDTH/8)-1:0] axis_dma_o_1_tkeep,
	input  wire [C_TUSER_WIDTH-1:0]     axis_dma_o_1_tuser,
	input  wire                         axis_dma_o_1_tvalid,
	output wire                         axis_dma_o_1_tready,
	input  wire                         axis_dma_o_1_tlast, 
	
	// Master Stream Ports
	output wire [C_TDATA_WIDTH-1:0]    axis_dma_i_0_tdata,
	output wire [(C_TDATA_WIDTH/8)-1:0]axis_dma_i_0_tkeep,
	output wire [C_TUSER_WIDTH-1:0]    axis_dma_i_0_tuser,
	output wire                        axis_dma_i_0_tvalid,
	input  wire                        axis_dma_i_0_tready,
	output wire                        axis_dma_i_0_tlast, 

    output wire [C_TDATA_WIDTH-1:0]    axis_dma_i_1_tdata,
	output wire [(C_TDATA_WIDTH/8)-1:0]axis_dma_i_1_tkeep,
	output wire [C_TUSER_WIDTH-1:0]    axis_dma_i_1_tuser,
	output wire                        axis_dma_i_1_tvalid,
	input  wire                        axis_dma_i_1_tready,
	output wire                        axis_dma_i_1_tlast, 

	// Slave Stream Ports
	input  wire [C_TDATA_WIDTH-1:0]     axis_phy_o_0_tdata,
	input  wire [(C_TDATA_WIDTH/8)-1:0] axis_phy_o_0_tkeep,
	input  wire [C_TUSER_WIDTH-1:0]     axis_phy_o_0_tuser,
	input  wire                         axis_phy_o_0_tvalid,
	output wire                         axis_phy_o_0_tready,
	input  wire                         axis_phy_o_0_tlast, 
	// Slave Stream Ports
	input  wire [C_TDATA_WIDTH-1:0]     axis_phy_o_1_tdata,
	input  wire [(C_TDATA_WIDTH/8)-1:0] axis_phy_o_1_tkeep,
	input  wire [C_TUSER_WIDTH-1:0]     axis_phy_o_1_tuser,
	input  wire                         axis_phy_o_1_tvalid,
	output wire                         axis_phy_o_1_tready,
	input  wire                         axis_phy_o_1_tlast, 
	// Master Stream Ports
	output wire [C_TDATA_WIDTH-1:0]    axis_phy_i_0_tdata,
	output wire [(C_TDATA_WIDTH/8)-1:0]axis_phy_i_0_tkeep,
	output wire [C_TUSER_WIDTH-1:0]    axis_phy_i_0_tuser,
	output wire                        axis_phy_i_0_tvalid,
	input  wire                        axis_phy_i_0_tready,
	output wire                        axis_phy_i_0_tlast, 
	// Master Stream Ports
	output wire [C_TDATA_WIDTH-1:0]    axis_phy_i_1_tdata,
	output wire [(C_TDATA_WIDTH/8)-1:0]axis_phy_i_1_tkeep,
	output wire [C_TUSER_WIDTH-1:0]    axis_phy_i_1_tuser,
	output wire                        axis_phy_i_1_tvalid,
	input  wire                        axis_phy_i_1_tready,
	output wire                        axis_phy_i_1_tlast, 

	input  wire                       core_clk,
	input wire                        core_rst,
	output wire                       axis_aclk,
	output wire                       axil_aclk,
	output wire                       axis_rst,
	output wire                       axil_rst
);

  wire [1:0] cmac_clk;

  wire                            axis_cmac_i_0_tvalid, axis_cmac_i_1_tvalid;
  wire [C_TDATA_WIDTH-1:0]        axis_cmac_i_0_tdata , axis_cmac_i_1_tdata ;
  wire [(C_TDATA_WIDTH/8)-1:0]    axis_cmac_i_0_tkeep , axis_cmac_i_1_tkeep ;
  wire                            axis_cmac_i_0_tuser_err , axis_cmac_i_1_tuser_err ;
  wire                            axis_cmac_i_0_tlast , axis_cmac_i_1_tlast ;

  wire                            axis_cmac_o_0_tvalid, axis_cmac_o_1_tvalid;
  wire [C_TDATA_WIDTH-1:0]        axis_cmac_o_0_tdata , axis_cmac_o_1_tdata ;
  wire [(C_TDATA_WIDTH/8)-1:0]    axis_cmac_o_0_tkeep , axis_cmac_o_1_tkeep ;
  wire                            axis_cmac_o_0_tuser_err , axis_cmac_o_1_tuser_err ;
  wire                            axis_cmac_o_0_tlast , axis_cmac_o_1_tlast ;
  wire                            axis_cmac_o_0_tready , axis_cmac_o_1_tready ;

  wire [15:0]                    axis_dma_o_0_tuser_size, axis_dma_o_1_tuser_size;
  wire [15:0]                    axis_dma_o_0_tuser_src , axis_dma_o_1_tuser_src ;
  wire [15:0]                    axis_dma_o_0_tuser_dst , axis_dma_o_1_tuser_dst ;

  wire [15:0]                    axis_dma_i_0_tuser_size, axis_dma_i_1_tuser_size;
  wire [15:0]                    axis_dma_i_0_tuser_src , axis_dma_i_1_tuser_src ;
  wire [15:0]                    axis_dma_i_0_tuser_dst , axis_dma_i_1_tuser_dst ;

  assign axis_dma_i_0_tuser = {axis_dma_i_0_tuser_dst[7:0], axis_dma_i_0_tuser_src[7:0], axis_dma_i_0_tuser_size};
  assign axis_dma_i_1_tuser = {axis_dma_i_1_tuser_dst[7:0], axis_dma_i_1_tuser_src[7:0], axis_dma_i_1_tuser_size};

  assign axis_dma_o_0_tuser_dst = 2'b01;
  assign axis_dma_o_1_tuser_dst = 2'b10;
  assign axis_dma_o_0_tuser_src = axis_dma_o_0_tuser[23:16];
  assign axis_dma_o_1_tuser_src = axis_dma_o_1_tuser[23:16];
  assign axis_dma_o_0_tuser_size = axis_dma_o_0_tuser[15:0];
  assign axis_dma_o_1_tuser_size = axis_dma_o_1_tuser[15:0];

  wire                     m0_axil_awvalid;
  wire              [31:0] m0_axil_awaddr;
  wire                     m0_axil_awready;
  wire                     m0_axil_wvalid;
  wire              [31:0] m0_axil_wdata;
  wire                     m0_axil_wready;
  wire                     m0_axil_bvalid;
  wire               [1:0] m0_axil_bresp;
  wire                     m0_axil_bready;
  wire                     m0_axil_arvalid;
  wire              [31:0] m0_axil_araddr;
  wire                     m0_axil_arready;
  wire                     m0_axil_rvalid;
  wire              [31:0] m0_axil_rdata;
  wire               [1:0] m0_axil_rresp;
  wire                     m0_axil_rready;

  wire                     s_axil_awvalid;
  wire              [31:0] s_axil_awaddr;
  wire                     s_axil_awready;
  wire                     s_axil_wvalid;
  wire              [31:0] s_axil_wdata;
  wire                     s_axil_wready;
  wire                     s_axil_bvalid;
  wire               [1:0] s_axil_bresp;
  wire                     s_axil_bready;
  wire                     s_axil_arvalid;
  wire              [31:0] s_axil_araddr;
  wire                     s_axil_arready;
  wire                     s_axil_rvalid;
  wire              [31:0] s_axil_rdata;
  wire               [1:0] s_axil_rresp;
  wire                     s_axil_rready;
  wire               [3:0] s_axil_wstrb;

  wire [31:0] user_rst_done = 32'hffff_fffe;

  reg [9:0] axis_rst_cnt = 10'd0;
  reg [9:0] axil_rst_cnt = 10'd0;
  reg [9:0] cmac0_rst_cnt = 10'd0;
  reg [9:0] cmac1_rst_cnt = 10'd0;
  reg       axis_rst_reg, axil_rst_reg, cmac0_rst_reg, cmac1_rst_reg;
  assign axis_rst = axis_rst_reg;
  assign axil_rst = axil_rst_reg;
  wire   cmac0_rst = cmac0_rst_reg;
  wire   cmac1_rst = cmac1_rst_reg;

  always @ (posedge cmac_clk[0]) begin
    if (cmac0_rst_cnt != 10'h3ff) begin
      cmac0_rst_cnt <= cmac0_rst_cnt + 10'd1;
      cmac0_rst_reg <= 1'b1;
    end
    else begin
      cmac0_rst_reg <= 1'b0;
    end
  end

  always @ (posedge cmac_clk[1]) begin
    if (cmac1_rst_cnt != 10'h3ff) begin
      cmac1_rst_cnt <= cmac1_rst_cnt + 10'd1;
      cmac1_rst_reg <= 1'b1;
    end
    else begin
      cmac1_rst_reg <= 1'b0;
    end
  end

  always @ (posedge axis_aclk) begin
    if (axis_rst_cnt != 10'h3ff) begin
      axis_rst_cnt <= axis_rst_cnt + 10'd1;
      axis_rst_reg <= 1'b1;
    end
    else begin
      axis_rst_reg <= 1'b0;
    end
  end

  always @ (posedge axil_aclk) begin
    if (axil_rst_cnt != 10'h3ff) begin
      axil_rst_cnt <= axil_rst_cnt + 10'd1;
      axil_rst_reg <= 1'b1;
    end
    else begin
      axil_rst_reg <= 1'b0;
    end
  end

  axi_clock_converter_0 u_clk_conv (
    .s_axi_aclk    (axil_aclk),
    .s_axi_aresetn (!axil_rst),
    .s_axi_awaddr  (m0_axil_awaddr),
    .s_axi_awprot  (),
    .s_axi_awvalid (m0_axil_awvalid),
    .s_axi_awready (m0_axil_awready),
    .s_axi_wdata   (m0_axil_wdata  ),
    .s_axi_wstrb   (4'b1111),
    .s_axi_wvalid  (m0_axil_wvalid),
    .s_axi_wready  (m0_axil_wready),
    .s_axi_bresp   (m0_axil_bresp ),
    .s_axi_bvalid  (m0_axil_bvalid),
    .s_axi_bready  (m0_axil_bready),
    .s_axi_araddr  (m0_axil_araddr),
    .s_axi_arprot  (),
    .s_axi_arvalid (m0_axil_arvalid),
    .s_axi_arready (m0_axil_arready),
    .s_axi_rdata   (m0_axil_rdata  ),
    .s_axi_rresp   (m0_axil_rresp  ),
    .s_axi_rvalid  (m0_axil_rvalid ),
    .s_axi_rready  (m0_axil_rready ),
    .m_axi_aclk    (core_clk),
    .m_axi_aresetn (!core_rst),
    .m_axi_awaddr  (s_axil_awaddr),
    .m_axi_awprot  (s_axil_awvalid),
    .m_axi_awvalid (s_axil_awready),
    .m_axi_awready (s_axil_wdata  ),
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

  nf_mac_attachment_ip u_nf_attachment_0 (
    // 10GE block clk & rst 
    .clk156                (cmac_clk[0]),  
    .areset_clk156         (cmac0_rst), 
    // RX MAC 64b@clk156 (no backpressure) -> rx_queue 64b@axis_clk
    .m_axis_mac_tdata      (axis_cmac_i_0_tdata),
    .m_axis_mac_tkeep      (axis_cmac_i_0_tkeep),
    .m_axis_mac_tvalid     (axis_cmac_i_0_tvalid),
    .m_axis_mac_tuser_err  (!axis_cmac_i_0_tuser_err),
    .m_axis_mac_tuser      (),
    .m_axis_mac_tlast      (axis_cmac_i_0_tlast),
    // tx_queue 64b@axis_clk -> mac 64b@clk156
    .s_axis_mac_tdata      (axis_cmac_o_0_tdata),
    .s_axis_mac_tkeep      (axis_cmac_o_0_tkeep),
    .s_axis_mac_tvalid     (axis_cmac_o_0_tvalid),
    .s_axis_mac_tuser_err  (axis_cmac_o_0_tuser_err),      //underrun
    .s_axis_mac_tuser      (),
    .s_axis_mac_tlast      (axis_cmac_o_0_tlast),
    .s_axis_mac_tready     (axis_cmac_o_0_tready),
    
    // TX/RX DATA channels  
    .interface_number      (8'b0000_0001),
    
    // NFPLUS pipeline clk & rst 
    .axis_aclk             (core_clk),
    .axis_aresetn          (!core_rst),
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
        // 10GE block clk & rst 
        .clk156                (cmac_clk[1]),  
        .areset_clk156         (cmac1_rst), 
        // RX MAC 64b@clk156 (no backpressure) -> rx_queue 64b@axis_clk
        .m_axis_mac_tdata      (axis_cmac_i_1_tdata),
        .m_axis_mac_tkeep      (axis_cmac_i_1_tkeep),
        .m_axis_mac_tvalid     (axis_cmac_i_1_tvalid),
        .m_axis_mac_tuser_err  (!axis_cmac_i_1_tuser_err),       // valid frame
        .m_axis_mac_tuser      (),
        .m_axis_mac_tlast      (axis_cmac_i_1_tlast),
        // tx_queue 64b@axis_clk -> mac 64b@clk156
        .s_axis_mac_tdata      (axis_cmac_o_1_tdata),
        .s_axis_mac_tkeep      (axis_cmac_o_1_tkeep),
        .s_axis_mac_tvalid     (axis_cmac_o_1_tvalid),
        .s_axis_mac_tuser_err  (axis_cmac_o_1_tuser_err),      //underrun
        .s_axis_mac_tuser      (),
        .s_axis_mac_tlast      (axis_cmac_o_1_tlast),
        .s_axis_mac_tready     (axis_cmac_o_1_tready),
        
        // TX/RX DATA channels  
        .interface_number      (8'b0000_0001),
        
        // NFPLUS pipeline clk & rst
        .axis_aclk             (core_clk),
        .axis_aresetn          (!core_rst),
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

  xilinx_shell_ip xilinx_nic_shell (
`ifndef sim
    .pcie_txp      (pcie_txp),
    .pcie_txn      (pcie_txn),
    .pcie_rxp      (pcie_rxp),
    .pcie_rxn      (pcie_rxn),
    .pcie_refclk_p (pcie_clk_p),
    .pcie_refclk_n (pcie_clk_n),
    .pcie_rstn     (pcie_rst_n),

    .qsfp_rxp      ({qsfp1_rxp, qsfp0_rxp}),
    .qsfp_rxn      ({qsfp1_rxn, qsfp0_rxn}),
    .qsfp_txp      ({qsfp1_txp, qsfp0_txp}),
    .qsfp_txn      ({qsfp1_txn, qsfp0_txn}),
    .qsfp_refclk_p ({qsfp1_clk_p, qsfp0_clk_p}),
    .qsfp_refclk_n ({qsfp1_clk_n, qsfp0_clk_n}),

    .satellite_uart_0_rxd(satellite_uart_0_rxd),
    .satellite_uart_0_txd(satellite_uart_0_txd),
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
    .qsfp_resetl    (qsfp_resetl   ),
    .qsfp_modprsl   (qsfp_modprsl  ),
    .qsfp_intl      (qsfp_intl     ),
    .qsfp_lpmode    (qsfp_lpmode   ),
    .qsfp_modsell   (qsfp_modsell  ),
    .satellite_gpio (satellite_gpio),
`elsif __au250__
    .qsfp_resetl    (qsfp_resetl   ),
    .qsfp_modprsl   (qsfp_modprsl  ),
    .qsfp_intl      (qsfp_intl     ),
    .qsfp_lpmode    (qsfp_lpmode   ),
    .qsfp_modsell   (qsfp_modsell  ),
    .satellite_gpio (satellite_gpio),
`elsif __au45n__
    .satellite_gpio (satellite_gpio),
`endif

`else // !`ifdef __synthesis__
    .s_axil_awvalid (),
    .s_axil_awaddr  (),
    .s_axil_awready (),
    .s_axil_wvalid  (),
    .s_axil_wdata   (),
    .s_axil_wready  (),
    .s_axil_bvalid  (),
    .s_axil_bresp   (),
    .s_axil_bready  (),
    .s_axil_arvalid (),
    .s_axil_araddr  (),
    .s_axil_arready (),
    .s_axil_rvalid  (),
    .s_axil_rdata   (),
    .s_axil_rresp   (),
    .s_axil_rready  (),

    .s_axis_qdma_h2c_tvalid       (),
    .s_axis_qdma_h2c_tlast        (),
    .s_axis_qdma_h2c_tdata        (),
    .s_axis_qdma_h2c_dpar         (),
    .s_axis_qdma_h2c_tuser_qid    (),
    .s_axis_qdma_h2c_tuser_port_id(),
    .s_axis_qdma_h2c_tuser_err    (),
    .s_axis_qdma_h2c_tuser_mdata  (),
    .s_axis_qdma_h2c_tuser_mty    (),
    .s_axis_qdma_h2c_tuser_zero_byte(),
    .s_axis_qdma_h2c_tready       (),

    .m_axis_qdma_c2h_tvalid       (),
    .m_axis_qdma_c2h_tlast        (),
    .m_axis_qdma_c2h_tdata        (),
    .m_axis_qdma_c2h_dpar         (),
    .m_axis_qdma_c2h_ctrl_marker  (),
    .m_axis_qdma_c2h_ctrl_port_id (),
    .m_axis_qdma_c2h_ctrl_len     (),
    .m_axis_qdma_c2h_ctrl_qid     (),
    .m_axis_qdma_c2h_ctrl_has_cmpt(),
    .m_axis_qdma_c2h_mty          (),
    .m_axis_qdma_c2h_tready       (),

    .m_axis_qdma_cpl_tvalid              (),
    .m_axis_qdma_cpl_tdata               (),
    .m_axis_qdma_cpl_size                (),
    .m_axis_qdma_cpl_dpar                (),
    .m_axis_qdma_cpl_ctrl_qid            (),
    .m_axis_qdma_cpl_ctrl_cmpt_type      (),
    .m_axis_qdma_cpl_ctrl_wait_pld_pkt_id(),
    .m_axis_qdma_cpl_ctrl_port_id        (),
    .m_axis_qdma_cpl_ctrl_marker         (),
    .m_axis_qdma_cpl_ctrl_user_trig      (),
    .m_axis_qdma_cpl_ctrl_col_idx        (),
    .m_axis_qdma_cpl_ctrl_err_idx        (),
    .m_axis_qdma_cpl_tready              (),

    .m_axis_cmac_tx_tvalid                    (),
    .m_axis_cmac_tx_tdata                     (),
    .m_axis_cmac_tx_tkeep                     (),
    .m_axis_cmac_tx_tlast                     (),
    .m_axis_cmac_tx_tuser                     (),
    .m_axis_cmac_tx_tready                    (),

    .s_axis_cmac_rx_tvalid                    (),
    .s_axis_cmac_rx_tdata                     (),
    .s_axis_cmac_rx_tkeep                     (),
    .s_axis_cmac_rx_tlast                     (),
    .s_axis_cmac_rx_tuser                     (),

    .powerup_rstn                             (),
`endif

    .m_axil_box0_awvalid               (m0_axil_awvalid),
    .m_axil_box0_awaddr                (m0_axil_awaddr ),
    .m_axil_box0_awready               (m0_axil_awready),
    .m_axil_box0_wvalid                (m0_axil_wvalid ),
    .m_axil_box0_wdata                 (m0_axil_wdata  ),
    .m_axil_box0_wready                (m0_axil_wready ),
    .m_axil_box0_bvalid                (m0_axil_bvalid ),
    .m_axil_box0_bresp                 (m0_axil_bresp  ),
    .m_axil_box0_bready                (m0_axil_bready ),
    .m_axil_box0_arvalid               (m0_axil_arvalid),
    .m_axil_box0_araddr                (m0_axil_araddr ),
    .m_axil_box0_arready               (m0_axil_arready),
    .m_axil_box0_rvalid                (m0_axil_rvalid ),
    .m_axil_box0_rdata                 (m0_axil_rdata  ),
    .m_axil_box0_rresp                 (m0_axil_rresp  ),
    .m_axil_box0_rready                (m0_axil_rready ),

    .m_axil_box1_awvalid               (m_axil_awvalid),
    .m_axil_box1_awaddr                (m_axil_awaddr ),
    .m_axil_box1_awready               (m_axil_awready),
    .m_axil_box1_wvalid                (m_axil_wvalid ),
    .m_axil_box1_wdata                 (m_axil_wdata  ),
    .m_axil_box1_wready                (m_axil_wready ),
    .m_axil_box1_bvalid                (m_axil_bvalid ),
    .m_axil_box1_bresp                 (m_axil_bresp  ),
    .m_axil_box1_bready                (m_axil_bready ),
    .m_axil_box1_arvalid               (m_axil_arvalid),
    .m_axil_box1_araddr                (m_axil_araddr ),
    .m_axil_box1_arready               (m_axil_arready),
    .m_axil_box1_rvalid                (m_axil_rvalid ),
    .m_axil_box1_rdata                 (m_axil_rdata  ),
    .m_axil_box1_rresp                 (m_axil_rresp  ),
    .m_axil_box1_rready                (m_axil_rready ),

     // QDMA subsystem interfaces to the box running at 250MHz
    .m_axis_qdma_h2c_tvalid    ({axis_dma_i_1_tvalid, axis_dma_i_0_tvalid }),
    .m_axis_qdma_h2c_tdata     ({axis_dma_i_1_tdata , axis_dma_i_0_tdata  }),
    .m_axis_qdma_h2c_tkeep     ({axis_dma_i_1_tkeep , axis_dma_i_0_tkeep  }),
    .m_axis_qdma_h2c_tlast     ({axis_dma_i_1_tlast , axis_dma_i_0_tlast  }),
    .m_axis_qdma_h2c_tuser_size({axis_dma_i_1_tuser_size, axis_dma_i_0_tuser_size}),
    .m_axis_qdma_h2c_tuser_src ({axis_dma_i_1_tuser_src, axis_dma_i_0_tuser_src}),
    .m_axis_qdma_h2c_tuser_dst ({axis_dma_i_1_tuser_dst, axis_dma_i_0_tuser_dst}),
    .m_axis_qdma_h2c_tready    ({axis_dma_i_1_tready, axis_dma_i_0_tready}),

    .s_axis_qdma_c2h_tvalid    ({axis_dma_o_1_tvalid, axis_dma_o_0_tvalid }),
    .s_axis_qdma_c2h_tdata     ({axis_dma_o_1_tdata , axis_dma_o_0_tdata  }),
    .s_axis_qdma_c2h_tkeep     ({axis_dma_o_1_tkeep , axis_dma_o_0_tkeep  }),
    .s_axis_qdma_c2h_tlast     ({axis_dma_o_1_tlast , axis_dma_o_0_tlast  }),
    .s_axis_qdma_c2h_tuser_size({axis_dma_o_1_tuser_size, axis_dma_o_0_tuser_size}),
    .s_axis_qdma_c2h_tuser_src ({axis_dma_o_1_tuser_src, axis_dma_o_0_tuser_src}),
    .s_axis_qdma_c2h_tuser_dst ({axis_dma_o_1_tuser_dst, axis_dma_o_0_tuser_dst}),
    .s_axis_qdma_c2h_tready    ({axis_dma_o_1_tready, axis_dma_o_0_tready}),

    // CMAC subsystem CMAC-side interfaces to the box running at 322MHz
    .s_axis_cmac_tx_tvalid   ({axis_cmac_o_1_tvalid,    axis_cmac_o_0_tvalid}),
    .s_axis_cmac_tx_tdata    ({axis_cmac_o_1_tdata ,    axis_cmac_o_0_tdata }),
    .s_axis_cmac_tx_tkeep    ({axis_cmac_o_1_tkeep ,    axis_cmac_o_0_tkeep }),
    .s_axis_cmac_tx_tlast    ({axis_cmac_o_1_tlast ,    axis_cmac_o_0_tlast }),
    .s_axis_cmac_tx_tuser_err({axis_cmac_o_1_tuser_err, axis_cmac_o_0_tuser_err}),
    .s_axis_cmac_tx_tready   ({axis_cmac_o_1_tready,    axis_cmac_o_0_tready}),

    .m_axis_cmac_rx_tvalid   ({axis_cmac_i_1_tvalid,    axis_cmac_i_0_tvalid}),
    .m_axis_cmac_rx_tdata    ({axis_cmac_i_1_tdata ,    axis_cmac_i_0_tdata }),
    .m_axis_cmac_rx_tkeep    ({axis_cmac_i_1_tkeep ,    axis_cmac_i_0_tkeep }),
    .m_axis_cmac_rx_tlast    ({axis_cmac_i_1_tlast ,    axis_cmac_i_0_tlast }),
    .m_axis_cmac_rx_tuser_err({axis_cmac_i_1_tuser_err, axis_cmac_i_0_tuser_err}),

    .user_rstn              (),
    .user_rst_done          (user_rst_done),

    .axil_aclk              (axil_aclk),
    .axis_aclk              (axis_aclk),

    .cmac_clk               (cmac_clk)
  );

endmodule
