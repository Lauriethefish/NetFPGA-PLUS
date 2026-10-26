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
    input [C_S_AXIS_DATA_WIDTH - 1:0]         s_axis_dma_tdata,
    input [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_dma_tkeep,
    input [C_S_AXIS_TUSER_WIDTH-1:0]          s_axis_dma_tuser,
    input                                     s_axis_dma_tvalid,
    output                                    s_axis_dma_tready,
    input                                     s_axis_dma_tlast,


    output [C_M_AXIS_DATA_WIDTH - 1:0]         m_axis_dma_tdata,
    output [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] m_axis_dma_tkeep,
    output [C_M_AXIS_TUSER_WIDTH-1:0]          m_axis_dma_tuser,
    output                                     m_axis_dma_tvalid,
    input                                      m_axis_dma_tready,
    output                                     m_axis_dma_tlast,

    // Interface to and from Ethernet (CMAC)
    input [C_S_AXIS_DATA_WIDTH - 1:0]         s_axis_phy_tdata,
    input [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_phy_tkeep,
    input [C_S_AXIS_TUSER_WIDTH-1:0]          s_axis_phy_tuser,
    input                                     s_axis_phy_tvalid,
    output                                    s_axis_phy_tready,
    input                                     s_axis_phy_tlast,


    output [C_M_AXIS_DATA_WIDTH - 1:0]         m_axis_phy_tdata,
    output [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] m_axis_phy_tkeep,
    output [C_M_AXIS_TUSER_WIDTH-1:0]          m_axis_phy_tuser,
    output                                     m_axis_phy_tvalid,
    input                                      m_axis_phy_tready,
    output                                     m_axis_phy_tlast,

    );
   
    // For now a direct passthrough: i.e. this module is a no-op
    assign m_axis_phy_tdata = s_axis_dma_tdata;
    assign m_axis_phy_tkeep = s_axis_dma_tkeep;
    assign m_axis_phy_tuser = s_axis_dma_tuser;
    assign m_axis_phy_tvalid = s_axis_dma_tvalid;
    assign m_axis_phy_tlast = s_axis_dma_tlast;
    assign s_axis_dma_tready = m_axis_phy_tready;

    assign m_axis_dma_tdata = s_axis_phy_tdata;
    assign m_axis_dma_tkeep = s_axis_phy_tkeep;
    assign m_axis_dma_tuser = s_axis_phy_tuser;
    assign m_axis_dma_tvalid = s_axis_phy_tvalid;
    assign m_axis_dma_tlast = s_axis_phy_tlast;
    assign s_axis_phy_tready = m_axis_dma_tready;

    
endmodule