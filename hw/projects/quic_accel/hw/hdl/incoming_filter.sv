module incoming_filter #(
    parameter C_AXIS_DATA_WIDTH=512,
    parameter C_AXIS_TUSER_WIDTH=128
) 
(
    input [C_AXIS_DATA_WIDTH - 1:0]         s_axis_tdata,
    input [C_AXIS_TUSER_WIDTH-1:0]          s_axis_tuser,
    
    output is_offloadable
);
    import inter_structs::*;

    wire [$bits(udp_header)-1:0] udp_header_bits = {<<8{s_axis_tdata[$bits(udp_header)-1:0]}};
    wire udp_header header = udp_header_bits;

    // Check: Ethertype
    wire ethertype_ipv4 = header.ether.ethertype == 16'h0800;
    // Check: Is UDP packet
    wire protocol_udp = header.ipv4.protocol == 8'd17;

    // TODO: Check whether this flow is one with the variable length GSO enabled.

    assign is_offloadable = ethertype_ipv4 && protocol_udp;

endmodule