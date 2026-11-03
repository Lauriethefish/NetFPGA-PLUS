`timescale 1ns / 1ps
//-
// Copyright (c) 2015 Noa Zilberman
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
//        nf_datapath.v
//
//  Module:
//        nf_datapath
//
//  Author: Noa Zilberman
//
//  Description:
//        NetFPGA user data path wrapper, wrapping input arbiter, output port lookup and output queues
//
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
module nf_datapath #(
    //Slave AXI parameters
    parameter C_S_AXI_DATA_WIDTH    = 32,          
    parameter C_S_AXI_ADDR_WIDTH    = 32,          
    parameter C_BASEADDR            = 32'h00000000,

    // Master AXI Stream Data Width
    parameter C_AXIS_DATA_WIDTH=512,
    parameter C_AXIS_TUSER_WIDTH=128,
    parameter NUM_QUEUES=5
) (
    //Datapath clock
    input                                     axis_aclk,
    input                                     axis_resetn,
    //Registers clock
    input                                     axi_aclk,
    input                                     axi_resetn,

    // Slave AXI Port
    input      [C_S_AXI_ADDR_WIDTH-1 : 0]     S_AXI_AWADDR,
    input                                     S_AXI_AWVALID,
    input      [C_S_AXI_DATA_WIDTH-1 : 0]     S_AXI_WDATA,
    input      [C_S_AXI_DATA_WIDTH/8-1 : 0]   S_AXI_WSTRB,
    input                                     S_AXI_WVALID,
    input                                     S_AXI_BREADY,
    input      [C_S_AXI_ADDR_WIDTH-1 : 0]     S_AXI_ARADDR,
    input                                     S_AXI_ARVALID,
    input                                     S_AXI_RREADY,
    output                                    S_AXI_ARREADY,
    output     [C_S_AXI_DATA_WIDTH-1 : 0]     S_AXI_RDATA,
    output     [1 : 0]                        S_AXI_RRESP,
    output                                    S_AXI_RVALID,
    output                                    S_AXI_WREADY,
    output     [1 :0]                         S_AXI_BRESP,
    output                                    S_AXI_BVALID,
    output                                    S_AXI_AWREADY,

    
    // Interface to and from DMA
    input [C_AXIS_DATA_WIDTH - 1:0]         s_axis_dma_tdata,
    input [((C_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_dma_tkeep,
    input [C_AXIS_TUSER_WIDTH-1:0]          s_axis_dma_tuser,
    input                                     s_axis_dma_tvalid,
    output                                    s_axis_dma_tready,
    input                                     s_axis_dma_tlast,


    output [C_AXIS_DATA_WIDTH - 1:0]         m_axis_dma_tdata,
    output [((C_AXIS_DATA_WIDTH / 8)) - 1:0] m_axis_dma_tkeep,
    output [C_AXIS_TUSER_WIDTH-1:0]          m_axis_dma_tuser,
    output                                     m_axis_dma_tvalid,
    input                                      m_axis_dma_tready,
    output                                     m_axis_dma_tlast,

    // Interface to and from Ethernet (CMAC)
    input [C_AXIS_DATA_WIDTH - 1:0]         s_axis_phy_tdata_raw,
    input [((C_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_phy_tkeep_raw,
    input [C_AXIS_TUSER_WIDTH-1:0]          s_axis_phy_tuser_raw,
    input                                     s_axis_phy_tvalid_raw,
    output                                    s_axis_phy_tready_raw,
    input                                     s_axis_phy_tlast_raw,


    output [C_AXIS_DATA_WIDTH - 1:0]         m_axis_phy_tdata_raw,
    output [((C_AXIS_DATA_WIDTH / 8)) - 1:0] m_axis_phy_tkeep_raw,
    output [C_AXIS_TUSER_WIDTH-1:0]          m_axis_phy_tuser_raw,
    output                                     m_axis_phy_tvalid_raw,
    input                                      m_axis_phy_tready_raw,
    output                                     m_axis_phy_tlast_raw
    );

    // Register inputs and outputs to CMAC subsystem using SLR-crossing
    // axis_register_slice.
    // The CMAC subsystem has a high clock frequency so the interface to it
    // needs to be as clean as possible.

    wire [C_AXIS_DATA_WIDTH - 1:0]         s_axis_phy_tdata;
    wire [((C_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_phy_tkeep;
    wire [C_AXIS_TUSER_WIDTH-1:0]          s_axis_phy_tuser;
    wire                                   s_axis_phy_tvalid;
    wire                                   s_axis_phy_tready;
    wire                                   s_axis_phy_tlast;

    wire [C_AXIS_DATA_WIDTH - 1:0]         m_axis_phy_tdata;
    wire [((C_AXIS_DATA_WIDTH / 8)) - 1:0] m_axis_phy_tkeep;
    wire [C_AXIS_TUSER_WIDTH-1:0]          m_axis_phy_tuser;
    wire                                   m_axis_phy_tvalid;
    wire                                   m_axis_phy_tready;
    wire                                   m_axis_phy_tlast;

    axis_register_slice_1 out_reg_slice (
        .aclk(axis_aclk),
        .aresetn(axis_resetn),
        .m_axis_tvalid(s_axis_phy_tvalid),
        .m_axis_tready(s_axis_phy_tready),
        .m_axis_tdata (s_axis_phy_tdata),
        .m_axis_tkeep (s_axis_phy_tkeep),
        .m_axis_tlast (s_axis_phy_tlast),
        .m_axis_tuser (s_axis_phy_tuser),
        .s_axis_tvalid(s_axis_phy_tvalid_raw),
        .s_axis_tready(s_axis_phy_tready_raw),
        .s_axis_tdata (s_axis_phy_tdata_raw),
        .s_axis_tkeep (s_axis_phy_tkeep_raw),
        .s_axis_tlast (s_axis_phy_tlast_raw),
        .s_axis_tuser (s_axis_phy_tuser_raw)
    );

    axis_register_slice_1 in_reg_slice (
        .aclk(axis_aclk),
        .aresetn(axis_resetn),
        .m_axis_tvalid(m_axis_phy_tvalid_raw),
        .m_axis_tready(m_axis_phy_tready_raw),
        .m_axis_tdata (m_axis_phy_tdata_raw),
        .m_axis_tkeep (m_axis_phy_tkeep_raw),
        .m_axis_tlast (m_axis_phy_tlast_raw),
        .m_axis_tuser (m_axis_phy_tuser_raw),
        .s_axis_tvalid(m_axis_phy_tvalid),
        .s_axis_tready(m_axis_phy_tready),
        .s_axis_tdata (m_axis_phy_tdata),
        .s_axis_tkeep (m_axis_phy_tkeep),
        .s_axis_tlast (m_axis_phy_tlast),
        .s_axis_tuser (m_axis_phy_tuser)
    );
   
    // Connect physical transmission through the udp checksum setter IP
   /*
    assign m_axis_phy_tdata = s_axis_dma_tdata;
    assign m_axis_phy_tkeep = s_axis_dma_tkeep;
    assign m_axis_phy_tuser = s_axis_dma_tuser;
    assign m_axis_phy_tvalid = s_axis_dma_tvalid;
    assign m_axis_phy_tlast = s_axis_dma_tlast;
    assign s_axis_dma_tready = m_axis_phy_tready;*/

    assign m_axis_dma_tdata = s_axis_phy_tdata;
    assign m_axis_dma_tkeep = s_axis_phy_tkeep;
    assign m_axis_dma_tuser = s_axis_phy_tuser;
    assign m_axis_dma_tvalid = s_axis_phy_tvalid;
    assign m_axis_dma_tlast = s_axis_phy_tlast;
    assign s_axis_phy_tready = m_axis_dma_tready;
    

    udp_checksum_setter_ip
    set_checksum
    (
      .axis_aclk(axis_aclk), 
      .axis_resetn(axis_resetn), 
      
      .s_axis_tdata (s_axis_dma_tdata), 
      .s_axis_tkeep (s_axis_dma_tkeep), 
      .s_axis_tuser (s_axis_dma_tuser), 
      .s_axis_tvalid(s_axis_dma_tvalid),
      .s_axis_tready(s_axis_dma_tready), 
      .s_axis_tlast (s_axis_dma_tlast),

      .m_axis_tdata (m_axis_phy_tdata), 
      .m_axis_tkeep (m_axis_phy_tkeep), 
      .m_axis_tuser (m_axis_phy_tuser), 
      .m_axis_tvalid(m_axis_phy_tvalid), 
      .m_axis_tready(m_axis_phy_tready), 
      .m_axis_tlast (m_axis_phy_tlast)
    );

    reg [31:0] num_packets_rx;
    reg [31:0] num_packets_tx;
    reg [31:0] num_packets_rx_raw;
    reg [31:0] num_packets_tx_raw;
    reg [31:0] num_packets_tx_tvalid;

    always_ff @(posedge axis_aclk) begin
        if(!axis_resetn) begin
            num_packets_rx <= 0;
            num_packets_tx <= 0;
            num_packets_rx_raw <= 0;
            num_packets_tx_raw <= 0;
            num_packets_tx_tvalid <= 0;
        end else begin
            if(s_axis_phy_tvalid && s_axis_phy_tready && s_axis_phy_tlast) begin
                num_packets_rx <= num_packets_rx + 1;
            end

            if(s_axis_phy_tvalid_raw && s_axis_phy_tready_raw && s_axis_phy_tlast_raw) begin
                num_packets_rx_raw <= num_packets_rx_raw + 1;
            end

            if(s_axis_dma_tvalid && s_axis_dma_tready && s_axis_dma_tlast) begin
                num_packets_tx <= num_packets_tx + 1;
            end

            if(s_axis_dma_tvalid) begin
                num_packets_tx_tvalid <= num_packets_tx_tvalid + 1;
            end

            if(m_axis_phy_tvalid_raw && m_axis_phy_tready_raw && m_axis_phy_tlast_raw) begin
                num_packets_tx_raw <= num_packets_tx_raw + 1;
            end
        end
    end

    wire [31:0] reg_read_values[6];
    // Debug value to check the memory map is correct
    assign reg_read_values[0] = 32'hffdafafa;
    assign reg_read_values[1] = num_packets_tx;
    assign reg_read_values[2] = num_packets_rx;
    assign reg_read_values[3] = num_packets_tx_raw;
    assign reg_read_values[4] = num_packets_rx_raw;
    assign reg_read_values[5] = num_packets_tx_tvalid;

    axil_register_bank 
    #(
        .NUM_REGISTERS(6)
    )
    axil_regs
    (
        // General ports
        .clk(axis_aclk),
        .resetn(axis_resetn),

        .reg_read_values(reg_read_values),
        .reg_write_values(),
        .reg_is_writing(),

        .S_AXI_ACLK(axi_aclk),
        .S_AXI_ARESETN(axi_resetn),
        .S_AXI_AWADDR(S_AXI_AWADDR),
        .S_AXI_AWVALID(S_AXI_AWVALID),
        .S_AXI_WDATA(S_AXI_WDATA),
        .S_AXI_WSTRB(S_AXI_WSTRB),
        .S_AXI_WVALID(S_AXI_WVALID),
        .S_AXI_BREADY(S_AXI_BREADY),
        .S_AXI_ARADDR(S_AXI_ARADDR),
        .S_AXI_ARVALID(S_AXI_ARVALID),
        .S_AXI_RREADY(S_AXI_RREADY),
        .S_AXI_ARREADY(S_AXI_ARREADY),
        .S_AXI_RDATA(S_AXI_RDATA),
        .S_AXI_RRESP(S_AXI_RRESP),
        .S_AXI_RVALID(S_AXI_RVALID),
        .S_AXI_WREADY(S_AXI_WREADY),
        .S_AXI_BRESP(S_AXI_BRESP),
        .S_AXI_BVALID(S_AXI_BVALID),
        .S_AXI_AWREADY(S_AXI_AWREADY)
    );
    
endmodule