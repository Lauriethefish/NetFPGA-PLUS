`define C_M_AXIS_DATA_WIDTH 512
`define C_S_AXIS_DATA_WIDTH 512
`define C_M_AXIS_TUSER_WIDTH 128
`define C_S_AXIS_TUSER_WIDTH 128

// Total width of ethernet/IP/UDP header stack in bytes
`define UDP_HEADERS_SIZE 42

module udp_splitter
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

    reg is_new_packet;

    // Track the header for the current set of segments we are generating.
    reg [`UDP_HEADERS_SIZE*8-1:0] segments_header;
    wire udp_header segments_header_udp;
    assign segments_header_udp = {<<8{segments_header}};

    // Buffer needs to always be able to:
    // - Accept 64 bytes
    // - Have 64 bytes ready to slide into place
    // - 
    reg [`C_M_AXIS_DATA_WIDTH*2:0] segment_buffer;

    // BUFFER MANAGEMENT

    // Ready to accept new data if:
    // Expecting more in current packet and will be adding at most halfway through the buffer
    // Or is a new packet and the buffer is empty (TODO: this will cause stalls)
    reg [15:0] bytes_in_buffer;
    assign s_axis_tready = is_new_packet ? (buffer_remove_amt == bytes_in_buffer) : (buffer_add_pos <= `C_M_AXIS_DATA_WIDTH/8);
    // Position at which data will be added/removed from the buffer in the next
    // cycle.
    wire [15:0] buffer_add_pos;
    wire [15:0] buffer_remove_amt;
    assign buffer_add_pos = bytes_in_buffer - buffer_remove_amt;

    // INGRESS DATA

    // In the first transfer of a packet, strip out the UDP headers before storing in the buffer
    wire [`C_S_AXIS_DATA_WIDTH - 1:0] s_axis_tdata_stripped_udp_headers;
    assign s_axis_tdata_stripped_udp_headers = is_new_packet ?
        s_axis_tdata[`C_S_AXIS_DATA_WIDTH-1:`UDP_HEADERS_SIZE*8]
        : s_axis_tdata;

    // Number of bytes left in the packet we're currently expecting as input.
    reg [15:0] bytes_left_in_packet;

    // Get the length of the packet from the tuser
    wire [15:0] s_axis_tuser_length;
    assign s_axis_tuser_length = s_axis_tuser[15:0];
    // Number of bytes left to transfer in the current ingress packet
    wire [15:0] s_axis_bytes_remaining;
    assign s_axis_bytes_remaining = is_new_packet ? s_axis_tuser_length
        : bytes_left_in_packet;

    wire [15:0] s_axis_bytes_to_input;
    assign s_axis_bytes_to_input = s_axis_bytes_remaining > (`C_M_AXIS_DATA_WIDTH/8)
        ? (`C_M_AXIS_DATA_WIDTH/8) : s_axis_bytes_remaining;

    // Number of bytes we're adding to the buffer this cycle.
    wire [15:0] s_axis_bytes_to_accept = is_new_packet ?
        s_axis_bytes_to_input - `UDP_HEADERS_SIZE
        : s_axis_bytes_to_input;

    // EGRESS DATA
    reg is_new_segment;

    reg [15:0] segment_rem;
    reg [15:0] segment_total_len;
    wire [15:0] new_segment_size;
    assign new_segment_size = segment_buffer[15:0];

    wire [15:0] reconstructed_tuser;
    assign reconstructed_tuser = is_new_segment ? new_segment_size + `UDP_HEADERS_SIZE : '0;

    wire [15:0] current_segment_rem;
    assign current_segment_rem = is_new_segment ? new_segment_size : segment_rem;

    wire [15:0] current_segment_size;
    assign current_segment_size = is_new_segment ? new_segment_size : segment_total_len;

    wire [15:0] max_data_in_transfer; // Amount of data bytes (payload) we could send in the next transfer
    wire [15:0] bytes_to_send;
    wire [15:0] egress_needed; // Amount of data we NEED in the buffer to make the next transfer
    assign max_data_in_transfer = `C_S_AXIS_DATA_WIDTH/8 - (is_new_segment ? `UDP_HEADERS_SIZE : 0);
    assign bytes_to_send = current_segment_rem > max_data_in_transfer ? max_data_in_transfer : current_segment_rem;
    // Add 2 if a new segment, since we need the segment length in the buffer.
    assign egress_needed = bytes_to_send + (is_new_segment ? 2 : 0);

    wire ipv4_header header_updated_ipv4;
    assign header_updated_ipv4 = '{
        segments_header_udp.ipv4.version,
        segments_header_udp.ipv4.ihl,
        segments_header_udp.ipv4.dscp,
        segments_header_udp.ipv4.ecn,
        current_segment_size + 28, // ipv4 header size + UDP header size
        segments_header_udp.ipv4.identification,
        segments_header_udp.ipv4.flags,
        segments_header_udp.ipv4.frag_offset,
        segments_header_udp.ipv4.ttl,
        segments_header_udp.ipv4.protocol,
        16'b0, // Computed later
        segments_header_udp.ipv4.src_addr,
        segments_header_udp.ipv4.dst_addr
    };

    wire udp_header header_updated_size;
    assign header_updated_size = '{
        segments_header_udp.ether,
        header_updated_ipv4,
        segments_header_udp.src_port,
        segments_header_udp.dst_port,
        current_segment_size + 8, // add UDP header size.
        16'b0 // Computed later by udp_checksum_calculator
    };

    wire [`UDP_HEADERS_SIZE*8-1:0] segment_updated_header;
    assign segment_updated_header = {<<8{header_updated_size}};

    wire [`C_S_AXIS_DATA_WIDTH - 1:0] segment_egress_data;
    assign segment_egress_data = is_new_segment ?
        {segment_buffer[`C_S_AXIS_DATA_WIDTH:0] >> 16, segment_updated_header}
        : segment_buffer[`C_S_AXIS_DATA_WIDTH:0];

    // Don't remove anything from the buffer unless have the full amount needed for the segment
    wire ready_for_egress;
    assign ready_for_egress = egress_needed > 0 && bytes_in_buffer >= egress_needed;
    assign buffer_remove_amt = ready_for_egress ? egress_needed : 0;

    wire last_in_segment;
    assign last_in_segment = bytes_to_send == current_segment_rem;

    // TODO: I imagine this won't synthesise very well.
    // There's only one way to find out.
    wire [((`C_S_AXIS_DATA_WIDTH / 8)) - 1:0] output_tkeep;
    generate
        for(genvar i = 0; i < (`C_S_AXIS_DATA_WIDTH / 8); i++) begin
            assign output_tkeep[i] = (bytes_to_send + (is_new_segment ? `UDP_HEADERS_SIZE : 0)) > i;
        end
    endgenerate

    always_ff @(posedge axis_aclk) begin
        if(!axis_resetn) begin
            is_new_packet <= 1'b1;
            segments_header <= '0;
            segment_buffer <= '0;
            bytes_in_buffer <= '0;
            bytes_left_in_packet <= '0;
            is_new_segment <= 1'b1;
            segment_rem <= '0;
            segment_total_len <= '0;

            m_axis_tdata <= '0;
            m_axis_tkeep <= '0;
            m_axis_tuser <= '0;
            m_axis_tvalid <= '0;
            m_axis_tlast <= '0;
        end else begin
            // BUFFER MANAGEMENT
            // Remove data from the buffer, and add new data from the incoming packet.
            segment_buffer <= (segment_buffer >> (buffer_remove_amt*8)) |
                ((s_axis_tready && s_axis_tvalid) ? (s_axis_tdata_stripped_udp_headers << (buffer_add_pos*8)) : 0);
            bytes_in_buffer <= bytes_in_buffer + ((s_axis_tready && s_axis_tvalid) ? s_axis_bytes_to_accept : 0) - buffer_remove_amt;

            // INGRESS DATA
            if(s_axis_tready && s_axis_tvalid) begin
                if(is_new_packet) begin
                    // Buffer the packet headers
                    segments_header <= s_axis_tdata[`UDP_HEADERS_SIZE*8-1:0];
                end
                bytes_left_in_packet <= s_axis_bytes_remaining - s_axis_bytes_to_input;
                is_new_packet <= s_axis_tlast;
            end


            // EGRESS DATA
            if(ready_for_egress && m_axis_tready) begin
                segment_rem <= current_segment_rem - bytes_to_send;
                if(is_new_segment) begin
                    segment_total_len <= new_segment_size;
                end
                is_new_segment <= last_in_segment;

                m_axis_tdata <= segment_egress_data;
                m_axis_tkeep <= output_tkeep;
                // TODO: currently doesn't maintain the other parts of tuser.
                m_axis_tuser <= reconstructed_tuser;
                m_axis_tvalid <= 1'b1;
                m_axis_tlast <= last_in_segment;
            end else begin
                // Buffer emptied with nothing to fill its place
                m_axis_tvalid <= 1'b0;
            end
        end 
    end
endmodule