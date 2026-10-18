#
# Copyright (c) 2015 Noa Zilberman
# Modified by Salvator Galea, Laurie Fay.
# All rights reserved.
#
# This software was developed by
# Stanford University and the University of Cambridge Computer Laboratory
# under National Science Foundation under Grant No. CNS-0855268,
# the University of Cambridge Computer Laboratory under EPSRC INTERNET Project EP/H040536/1 and
# by the University of Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-11-C-0249 ("MRC2"), 
# as part of the DARPA MRC research programme,
# and by the University of Cambridge Computer Laboratory under EPSRC EARL Project
# EP/P025374/1 alongside support from Xilinx Inc.
#
# @NETFPGA_LICENSE_HEADER_START@
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# @NETFPGA_LICENSE_HEADER_END@
#

# Vivado Launch Script
#### Change design settings here #######
set design udp_checksum_calculator
set top udp_set_checksum
set device $::env(DEVICE)
set proj_dir ./synth
set top top_sim
set sim_top top_tb
set board  $::env(BOARD)
set board_name  $::env(BOARD_NAME)
set proj_dir ./project
set public_repo_dir $::env(NFPLUS_FOLDER)/hw/lib/
set repo_dir ./ip_repo
set project_constraints ./constraints/${board_name}_switch.xdc

set test_name [lindex $argv 0]
#####################################
# Project Settings
#####################################
create_project -name ${design} -force -dir "./${proj_dir}" -part ${device}
set_property board_part ${board} [current_project]
set_property source_mgmt_mode DisplayOnly [current_project]
set_property top ${top} [current_fileset]
puts "Creating UDP checksum setting IP"
#####################################
# set IP paths
#####################################
create_fileset -constrset -quiet constraints
file copy ${public_repo_dir}/ ${repo_dir}
set_property ip_repo_paths ${repo_dir} [current_fileset]
#####################################
# Design Parameters on NF_DATAPATH
#####################################
set datapath_width_bit    1024

update_ip_catalog
create_ip -name axis_sim_stim -vendor NetFPGA -library NetFPGA -module_name axis_sim_stim_ip0
set_property -dict [list CONFIG.input_file $::env(NF_DESIGN_DIR)/test/single_stim.axi] [get_ips axis_sim_stim_ip0]
generate_target all [get_ips axis_sim_stim_ip0]

create_ip -name axis_sim_record -vendor NetFPGA -library NetFPGA -module_name axis_sim_record_ip0
set_property -dict [list CONFIG.OUTPUT_FILE $::env(NF_DESIGN_DIR)/test/single_log.axi] [get_ips axis_sim_record_ip0]
reset_target all [get_ips axis_sim_record_ip0]
generate_target all [get_ips axis_sim_record_ip0]

create_ip -name nf_mac_attachment -vendor NetFPGA -library NetFPGA -module_name nf_mac_attachment_ip
set_property CONFIG.C_M_AXIS_DATA_WIDTH ${datapath_width_bit} [get_ips nf_mac_attachment_ip]
set_property CONFIG.C_S_AXIS_DATA_WIDTH ${datapath_width_bit} [get_ips nf_mac_attachment_ip]
set_property generate_synth_checkpoint false [get_files nf_mac_attachment_ip.xci]
reset_target all [get_ips nf_mac_attachment_ip]
generate_target all [get_ips nf_mac_attachment_ip]

#####################################
# Project Structure & IP Build
#####################################

read_verilog -sv "$::env(NF_DESIGN_DIR)/hw/hdl/inter_structs.sv"
read_verilog -sv "$::env(NF_DESIGN_DIR)/hw/hdl/udp_checksum_calculator.sv"
read_verilog -sv "$::env(NF_DESIGN_DIR)/hw/hdl/udp_set_checksum.sv"
read_verilog "$::env(NF_DESIGN_DIR)/hw/hdl/top_sim.v"
read_verilog "$::env(NF_DESIGN_DIR)/hw/hdl/top_tb.v"

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

set_property top ${sim_top} [get_filesets sim_1]
set_property include_dirs ${proj_dir} [get_filesets sim_1]
set_property simulator_language Mixed [current_project]
set_property verilog_define { {SIMULATION=1} } [get_filesets sim_1]
set_property -name xsim.more_options -value {-testplusarg TESTNAME=basic_test} -objects [get_filesets sim_1]
set_property runtime {} [get_filesets sim_1]
set_property target_simulator xsim [current_project]
set_property compxlib.compiled_library_dir {} [current_project]
set_property top_lib xil_defaultlib [get_filesets sim_1]
update_compile_order -fileset sim_1

unset env(PYTHONPATH)
unset env(PYTHONHOME)
set env(PYTHONPATH) ".:$::env(NFPLUS_FOLDER)/tools/scripts/:$::env(NFPLUS_FOLDER)/tools/scripts/NFTest"
set output [exec $::env(PYTHON_BNRY) $::env(NF_DESIGN_DIR)/test/${test_name}/run.py]
puts $output

launch_simulation -simset sim_1 -mode behavioral
run 140us
