`define C_M_AXIS_DATA_WIDTH 512
`define C_S_AXIS_DATA_WIDTH 512
`define C_M_AXIS_TUSER_WIDTH 128
`define C_S_AXIS_TUSER_WIDTH 128

// TODO: Doesn't check whether the packet is actually IPv4.
// TODO: Should ideally be done by some earlier stage that checks all the traffic
// is valid for our offloading.
module ip_header_calc
(
    // Global clock/reset
    input axis_aclk,
    // Active low
    input axis_resetn,

    // Master Stream Ports (write packet data)
    output reg [`C_M_AXIS_DATA_WIDTH - 1:0] m_axis_tdata,
    output reg [((`C_M_AXIS_DATA_WIDTH / 8)) - 1:0] m_axis_tkeep,
    output reg [`C_M_AXIS_TUSER_WIDTH-1:0] m_axis_tuser,
    output reg m_axis_tvalid,
    input  m_axis_tready,
    output reg m_axis_tlast,

    // Slave Stream Ports (read packet data)
    // Register these inputs
    // And compute checksum of the first half
    input [`C_S_AXIS_DATA_WIDTH - 1:0] s_axis_tdata,
    input [((`C_S_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_tkeep,
    input [`C_S_AXIS_TUSER_WIDTH-1:0] s_axis_tuser,
    input  s_axis_tvalid,
    output s_axis_tready,
    input  s_axis_tlast
);
    import inter_structs::*;

    reg first_transfer_in_packet;

    wire [$bits(ipv4_header)-1:0] s_axis_header_bits;
    assign s_axis_header_bits = {<<8{s_axis_tdata[$bits(ipv4_header)+$bits(ether_header)-1:$bits(ether_header)]}};

    // Sum of 9x 16 bit words, so need 4 extra bits
    wire [20-1:0] s_axis_header_sum_raw = s_axis_header_bits[16*1-1:0] + 
        s_axis_header_bits[16*2-1:16*1] + 
        s_axis_header_bits[16*3-1:16*2] + 
        s_axis_header_bits[16*4-1:16*3] + 
        // Skip existing checksum
        //s_axis_header_bits[16*5-1:16*4] + 
        s_axis_header_bits[16*6-1:16*5] + 
        s_axis_header_bits[16*7-1:16*6] + 
        s_axis_header_bits[16*8-1:16*7] + 
        s_axis_header_bits[16*9-1:16*8] + 
        s_axis_header_bits[16*10-1:16*9];

    wire [16:0] s_axis_sum_1s_comp_stg1 = s_axis_header_sum_raw[15:0] + s_axis_header_sum_raw[19:16];
    wire [15:0] s_axis_sum_1s_comp_stg2 = s_axis_sum_1s_comp_stg1[15:0] + s_axis_sum_1s_comp_stg1[16];
    // Set checksum to ffff if its 1s complement will be 0000.
    wire [15:0] final_checksum = s_axis_sum_1s_comp_stg2 == 16'hffff ? 16'hffff : ~s_axis_sum_1s_comp_stg2;

    wire ipv4_header header = s_axis_header_bits;
    wire ipv4_header header_checksum_set = '{
        header.version,
        header.ihl,
        header.dscp,
        header.ecn,
        header.total_length,
        header.identification,
        header.flags,
        header.frag_offset,
        header.ttl,
        header.protocol,
        final_checksum,
        header.src_addr,
        header.dst_addr
    };

    wire [$bits(ipv4_header)-1:0] s_axis_header_bits_checksum_set = {<<8{header_checksum_set}};
    wire [`C_M_AXIS_DATA_WIDTH - 1:0] s_axis_tdata_updated;
    assign s_axis_tdata_updated = first_transfer_in_packet ? 
        {s_axis_tdata[`C_M_AXIS_DATA_WIDTH-1:$bits(ipv4_header)+$bits(ether_header)], s_axis_header_bits_checksum_set, s_axis_tdata[$bits(ether_header)-1:0]}
        : s_axis_tdata;


    // Ready to accept data if buffer empty or downstream is ready.
    assign s_axis_tready = m_axis_tready || !m_axis_tvalid;

    always_ff @(posedge axis_aclk) begin
        if(!axis_resetn) begin
            m_axis_tdata <= '0;
            m_axis_tuser <= '0;
            m_axis_tkeep <= '0;
            m_axis_tvalid <= 1'b0;
            m_axis_tlast <= '0;
            first_transfer_in_packet <= 1'b1;
        end else begin
            if(s_axis_tready && s_axis_tvalid) begin
                m_axis_tdata <= s_axis_tdata_updated;
                m_axis_tkeep <= s_axis_tkeep;
                m_axis_tuser <= s_axis_tuser;
                m_axis_tvalid <= 1'b1;
                m_axis_tlast <= s_axis_tlast;
                first_transfer_in_packet <= s_axis_tlast;
            end
            
            // Handle case where the buffer is being emptied
            if(m_axis_tready && !s_axis_tvalid) begin
                m_axis_tvalid <= 1'b0;
            end
        end
    end

endmodule