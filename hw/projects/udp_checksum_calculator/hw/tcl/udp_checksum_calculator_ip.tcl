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
set device          $::env(DEVICE)
set top udp_set_checksum
set proj_dir ./synth
set proj_dir ./project
set public_repo_dir $::env(NFPLUS_FOLDER)/hw/lib/
set repo_dir ./ip_repo

set device          $::env(DEVICE)
set ip_name 		{udp_checksum_calculator}
set lib_name 		{NetFPGA}
set vendor_name 	{NetFPGA}
set ip_display_name 	{udp_checksum_calculator}
set ip_description 	{UDP checksum calculator at 100Gbps}
set vendor_display_name {NetFPGA}
set vendor_company_url 	{http://www.netfpga.org}
set ip_version 		{1.0}

set test_name [lindex $argv 0]
#####################################
# Project Settings
#####################################
create_project -name ${ip_name} -force -dir "./${proj_dir}" -part ${device}
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

#####################################
# Project Structure & IP Build
#####################################

read_verilog -sv "./hdl/inter_structs.sv"
read_verilog -sv "./hdl/udp_checksum_calculator.sv"
read_verilog -sv "./hdl/udp_set_checksum.sv"

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

ipx::package_project

set_property name 			${ip_name} [ipx::current_core]
set_property library 			${lib_name} [ipx::current_core]
set_property vendor_display_name 	${vendor_display_name} [ipx::current_core]
set_property company_url 		${vendor_company_url} [ipx::current_core]
set_property vendor 			${vendor_name} [ipx::current_core]
set_property supported_families {{virtexuplus} {Production} {virtexuplushbm} {Production}} [ipx::current_core]
set_property taxonomy 			{{/NetFPGA/Generic}} [ipx::current_core]
set_property version 			${ip_version} [ipx::current_core]
set_property display_name 		${ip_display_name} [ipx::current_core]
set_property description 		${ip_description} [ipx::current_core]

create_ip -name nf_mac_attachment -vendor NetFPGA -library NetFPGA -module_name nf_mac_attachment_ip
set_property CONFIG.C_M_AXIS_DATA_WIDTH ${datapath_width_bit} [get_ips nf_mac_attachment_ip]
set_property CONFIG.C_S_AXIS_DATA_WIDTH ${datapath_width_bit} [get_ips nf_mac_attachment_ip]
set_property generate_synth_checkpoint false [get_files nf_mac_attachment_ip.xci]
reset_target all [get_ips nf_mac_attachment_ip]
generate_target all [get_ips nf_mac_attachment_ip]

# Write IP Core xml to File system
ipx::check_integrity [ipx::current_core]
write_peripheral [ipx::current_core]

# Generate GUI Configuration Files
ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]

close_project
exit