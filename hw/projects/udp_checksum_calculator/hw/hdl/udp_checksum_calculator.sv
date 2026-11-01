// Buffers a packet and computes its checksum.
// NB is either buffering a packet or outputting the result, not both.
module udp_checksum_calculator
#(
    parameter C_M_AXIS_DATA_WIDTH=1024,
    parameter C_S_AXIS_DATA_WIDTH=1024,
    parameter C_M_AXIS_TUSER_WIDTH=128,
    parameter C_S_AXIS_TUSER_WIDTH=128,
    parameter BUFFER_SIZE=32
)
(
    // Global clock/reset
    input axis_aclk,
    // Active low
    input axis_resetn,

    // Master Stream Ports (write packet data)
    output reg [C_M_AXIS_DATA_WIDTH - 1:0] m_axis_tdata,
    output reg [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] m_axis_tkeep,
    output reg [C_M_AXIS_TUSER_WIDTH-1:0] m_axis_tuser,
    output reg m_axis_tvalid,
    input  m_axis_tready,
    output reg m_axis_tlast,

    // Slave Stream Ports (read packet data)
    input [C_S_AXIS_DATA_WIDTH - 1:0] s_axis_tdata,
    input [$bits(inter_structs::udp_header):0] s_axis_orig_header,
    input [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_tkeep,
    input [C_S_AXIS_TUSER_WIDTH-1:0] s_axis_tuser,
    input  s_axis_tvalid,
    output s_axis_tready,
    input  s_axis_tlast,
    input [31:0] s_axis_checksum
);
    import inter_structs::*;

    reg [31:0] running_checksum;
    wire [31:0] trimmed_checksum;
    wire [31:0] trimmed_checksum_2;
    wire [15:0] final_checksum;

    // Each carry (i.e. the upper 16 bits) needs to be accounted for as a single
    // unit in the lower bits.
    wire [31:0] buffered_checksum;
    assign trimmed_checksum = (32'((buffered_checksum[15:0])) + 32'((buffered_checksum[31:16])));
    assign trimmed_checksum_2 = ~(32'((trimmed_checksum[15:0])) + 32'((trimmed_checksum[31:16])));
    // If the computed checksum is 0, then we need to set it to FFFF as 0
    // indicates no checksum is present.
    assign final_checksum = |trimmed_checksum_2 ? trimmed_checksum_2 : 16'hffff;

    // UDP packets have their header replaced with the pseudo header. Put it back here if necessary.
    wire need_restore_udp_header;

    // Highest bit indicates whether the header needs restoring
    assign need_restore_udp_header = s_axis_orig_header[$bits(udp_header)];

    wire [C_M_AXIS_DATA_WIDTH - 1:0] s_axis_tdata_restored_header;
    assign s_axis_tdata_restored_header = need_restore_udp_header ? 
        {s_axis_tdata[C_M_AXIS_DATA_WIDTH-1:$bits(udp_header)], s_axis_orig_header[$bits(udp_header)-1:0]} : s_axis_tdata;

    // Work out what to use for computing checksum based upon whether this is the header transaction.
    wire is_udp_packet;
    assign is_udp_packet = (buffered_header.ipv4.protocol == 'd17);

    wire udp_header buffered_header;
    wire [C_M_AXIS_DATA_WIDTH - 1:0] buffered_tdata;
    wire [C_M_AXIS_DATA_WIDTH - 1:0] buffered_tdata_with_header_update;


    wire [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] buffered_tkeep;
    wire [C_M_AXIS_TUSER_WIDTH-1:0] buffered_tuser;
    wire buffered_tlast;

    wire in_fifo_full;
    assign s_axis_tready = !in_fifo_full;

    wire in_fifo_empty;
    wire checksum_fifo_empty;
    reg is_first_output_transfer;
    // Ready to transfer if:
    // - There is physically space or no backpressure
    // - AND have a checksum if needed
    // - AND FIFO isn't empty.
    wire make_out_transfer = (!m_axis_tvalid || m_axis_tready) && (!checksum_fifo_empty || !is_first_output_transfer)
        && !in_fifo_empty;

    // Buffer the packet in a FIFO
    xpm_fifo_sync # (
       .FIFO_WRITE_DEPTH    (BUFFER_SIZE),
       .WRITE_DATA_WIDTH    (C_M_AXIS_DATA_WIDTH+C_M_AXIS_DATA_WIDTH / 8+C_M_AXIS_TUSER_WIDTH+1),
       .PROG_FULL_THRESH    (BUFFER_SIZE - 5),
       .READ_MODE           ("FWFT"),
       .FIFO_READ_LATENCY   (0),
       .READ_DATA_WIDTH     (C_M_AXIS_DATA_WIDTH+C_M_AXIS_DATA_WIDTH / 8+C_M_AXIS_TUSER_WIDTH+1)
    ) input_fifo (
       .sleep            (1'b0),
       .rst              (~axis_resetn),
       .wr_clk           (axis_aclk),
       .wr_en            (s_axis_tvalid & s_axis_tready),
       .din              ({s_axis_tuser, s_axis_tlast, s_axis_tkeep, s_axis_tdata_restored_header}),
       .full             (in_fifo_full),
       .prog_full        (), // TODO: maybe track with an AXI-Lite register?
       .wr_data_count    (),
       .overflow         (),
       .wr_rst_busy      (),
       .rd_en            (make_out_transfer),
       .dout             ({buffered_tuser, buffered_tlast, buffered_tkeep, buffered_tdata}),
       .data_valid       (),
       .empty            (in_fifo_empty),
       .prog_empty       (),
       .rd_data_count    (),
       .underflow        (),
       .rd_rst_busy      (),
       .injectsbiterr    (1'b0),
       .injectdbiterr    (1'b0),
       .sbiterr          (),
       .dbiterr          ()
    );

    xpm_fifo_sync # (
       .FIFO_WRITE_DEPTH    (BUFFER_SIZE),
       .WRITE_DATA_WIDTH    (32),
       .PROG_FULL_THRESH    (BUFFER_SIZE - 5),
       .READ_MODE           ("FWFT"),
       .FIFO_READ_LATENCY   (0),
       .READ_DATA_WIDTH     (32)
    ) chksum_fifo (
       .sleep            (1'b0),
       .rst              (~axis_resetn),
       .wr_clk           (axis_aclk),
       // Write computed total sum if this is the last packet
       .wr_en            (s_axis_tlast && s_axis_tready && s_axis_tvalid),
       // Add up checksum of last transfer to the running checksum
       .din              (running_checksum + transfer_checksum),
       .full             (),
       .prog_full        (), // TODO: maybe track with an AXI-Lite register?
       .wr_data_count    (),
       .overflow         (),
       .wr_rst_busy      (),
       .rd_en            (is_first_output_transfer && make_out_transfer),
       .dout             (buffered_checksum),
       .data_valid       (),
       .empty            (checksum_fifo_empty),
       .prog_empty       (),
       .rd_data_count    (),
       .underflow        (),
       .rd_rst_busy      (),
       .injectsbiterr    (1'b0),
       .injectdbiterr    (1'b0),
       .sbiterr          (),
       .dbiterr          ()
    );

    assign buffered_header = {<<8{buffered_tdata[$bits(udp_header)-1:0]}};

    wire udp_header checksum_set_header;
    wire [$bits(udp_header) - 1:0] checksum_set_header_bits;

    assign checksum_set_header = '{
        buffered_header.ether,
        buffered_header.ipv4,
        buffered_header.src_port,
        buffered_header.dst_port,
        buffered_header.length,
        final_checksum};
    assign checksum_set_header_bits = {<<8{checksum_set_header}};

    // Overwrite the header if this is the first transfer of the packet.
    assign buffered_tdata_with_header_update = (is_udp_packet && is_first_output_transfer) ?
        {buffered_tdata[C_M_AXIS_DATA_WIDTH - 1:$bits(udp_header)],checksum_set_header_bits}
        : buffered_tdata;

    // Use the already computed sum of the whole transaction
    // NB this accounts for the pseudo header due to the udp_pseudo_header_inserter module.
    wire [31:0] transfer_checksum;
    assign transfer_checksum = s_axis_checksum;

    always_ff @(posedge axis_aclk) begin
        if(!axis_resetn) begin
            running_checksum <= 0;
            is_first_output_transfer <= 1;
        end else begin
            if(make_out_transfer) begin
                m_axis_tdata <= buffered_tdata_with_header_update;
                m_axis_tuser <= buffered_tuser;
                m_axis_tkeep <= buffered_tkeep;
                m_axis_tlast <= buffered_tlast;
                m_axis_tvalid <= 1'b1;
                // If this is the last transfer, the next one is the first.
                is_first_output_transfer <= buffered_tlast;
            end else if(m_axis_tready) begin
                m_axis_tvalid <= 1'b0; // Output buffer now empty.
            end
            // Reset checksum if processing the last transfer in a packet.
            if(s_axis_tready && s_axis_tvalid) begin
                if(s_axis_tlast) begin
                    running_checksum <= 0;
                end else begin
                    running_checksum <= running_checksum + transfer_checksum;
                end
            end
        end
    end
endmodule