create_pblock pblock_set_checksum
add_cells_to_pblock [get_pblocks pblock_set_checksum] [get_cells -quiet [list nf_datapath_0/set_checksum]]
resize_pblock [get_pblocks pblock_set_checksum] -add {SLICE_X10Y300:SLICE_X56Y420}
resize_pblock [get_pblocks pblock_set_checksum] -add {DSP48E2_X1Y114:DSP48E2_X7Y161}
resize_pblock [get_pblocks pblock_set_checksum] -add {RAMB18_X1Y120:RAMB18_X3Y167}
resize_pblock [get_pblocks pblock_set_checksum] -add {RAMB36_X1Y60:RAMB36_X3Y83}
resize_pblock [get_pblocks pblock_set_checksum] -add {URAM288_X0Y80:URAM288_X0Y111}
create_pblock pblock_input_arbiter_v1_0
add_cells_to_pblock [get_pblocks pblock_input_arbiter_v1_0] [get_cells -quiet [list nf_datapath_0/input_arbiter_v1_0]]
resize_pblock [get_pblocks pblock_input_arbiter_v1_0] -add {SLICE_X57Y360:SLICE_X116Y478}
resize_pblock [get_pblocks pblock_input_arbiter_v1_0] -add {DSP48E2_X7Y138:DSP48E2_X15Y183}
resize_pblock [get_pblocks pblock_input_arbiter_v1_0] -add {RAMB18_X4Y144:RAMB18_X7Y189}
resize_pblock [get_pblocks pblock_input_arbiter_v1_0] -add {RAMB36_X4Y72:RAMB36_X7Y94}
resize_pblock [get_pblocks pblock_input_arbiter_v1_0] -add {URAM288_X1Y96:URAM288_X1Y123}
create_pblock pblock_output_port_lookup_1
add_cells_to_pblock [get_pblocks pblock_output_port_lookup_1] [get_cells -quiet [list nf_datapath_0/output_port_lookup_1]]
resize_pblock [get_pblocks pblock_output_port_lookup_1] -add {SLICE_X57Y305:SLICE_X116Y359}
resize_pblock [get_pblocks pblock_output_port_lookup_1] -add {DSP48E2_X7Y116:DSP48E2_X15Y137}
resize_pblock [get_pblocks pblock_output_port_lookup_1] -add {RAMB18_X4Y122:RAMB18_X7Y143}
resize_pblock [get_pblocks pblock_output_port_lookup_1] -add {RAMB36_X4Y61:RAMB36_X7Y71}
resize_pblock [get_pblocks pblock_output_port_lookup_1] -add {URAM288_X1Y84:URAM288_X1Y95}
create_pblock pblock_bram_output_queues_1
add_cells_to_pblock [get_pblocks pblock_bram_output_queues_1] [get_cells -quiet [list nf_datapath_0/bram_output_queues_1]]
resize_pblock [get_pblocks pblock_bram_output_queues_1] -add {SLICE_X117Y300:SLICE_X175Y430}
resize_pblock [get_pblocks pblock_bram_output_queues_1] -add {DSP48E2_X16Y114:DSP48E2_X24Y165}
resize_pblock [get_pblocks pblock_bram_output_queues_1] -add {RAMB18_X8Y120:RAMB18_X10Y171}
resize_pblock [get_pblocks pblock_bram_output_queues_1] -add {RAMB36_X8Y60:RAMB36_X10Y85}
resize_pblock [get_pblocks pblock_bram_output_queues_1] -add {URAM288_X2Y80:URAM288_X3Y111}
