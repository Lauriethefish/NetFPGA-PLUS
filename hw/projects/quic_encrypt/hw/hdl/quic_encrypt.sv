// QUIC encryption pipeline scaffold. Encryption is not implemented yet.
// Preserve the 512-bit AXI-stream interface used by udp_segmentation.
`timescale 1ns / 1ps

module quic_encrypt #(
    parameter C_AXIS_DATA_WIDTH = 512,
    parameter C_AXIS_TUSER_WIDTH = 128
) (
    input axis_aclk,
    input axis_resetn,

    input [C_AXIS_DATA_WIDTH-1:0] s_axis_tdata,
    input [C_AXIS_DATA_WIDTH/8-1:0] s_axis_tkeep,
    input [C_AXIS_TUSER_WIDTH-1:0] s_axis_tuser,
    input [7:0] s_axis_dcid_length,
    input s_axis_tvalid,
    output s_axis_tready,
    input s_axis_tlast,

    output [C_AXIS_DATA_WIDTH-1:0] m_axis_tdata,
    output [C_AXIS_DATA_WIDTH/8-1:0] m_axis_tkeep,
    output [C_AXIS_TUSER_WIDTH-1:0] m_axis_tuser,
    output m_axis_tvalid,
    input m_axis_tready,
    output m_axis_tlast
);
    // Lengths of crypto parameters in bytes.
    localparam NONCE_LENGTH=12;
    localparam KEY_LENGTH=16;

    // Constant parameters for now. TODO: Wire these in from cryptographic
    // parameter storage.
    wire [KEY_LENGTH*8-1:0] key = 'd4;
    wire [NONCE_LENGTH*8-1:0] packet_protection_iv = 'd5;


    // Buffer up to two transfers of incoming data.
    reg [C_AXIS_DATA_WIDTH*2-1:0] tdata_buf;
    reg [1:0] buf_fullness; // 0, 1 or 2
    assign s_axis_tready = buf_fullness < 2;
    always_ff @(posedge axis_aclk) begin
        if(s_axis_tready && s_axis_tvalid) begin
            if(buf_fullness == 0) begin
                tdata_buf[C_AXIS_DATA_WIDTH-1:0] <= s_axis_tdata;
            end else if(buf_fullness == 1) begin
                tdata_buf[C_AXIS_DATA_WIDTH*2-1:C_AXIS_DATA_WIDTH] <= s_axis_tdata;
            end
        end
    end

    // Length of the Ether + IP + UDP headers.
    localparam PRE_QUIC_HEADERS_LEN=42;
    // Destination connection ID length: in the future, this will have to come
    // from tuser as it can vary with each connection.
    localparam DCID_LENGTH=8;

    // After Ether + IP + UDP headers, we get to QUIC headers.

    wire [C_AXIS_DATA_WIDTH*2-PRE_QUIC_HEADERS_LEN*8-1:0] quic_headers =
        tdata_buf[C_AXIS_DATA_WIDTH*2-1:PRE_QUIC_HEADERS_LEN*8];

    wire [7:0] packet_type = {<<8{quic_headers[7:0]}};
    // RFC 9000. 17.3.1.
    wire is_1rtt = (packet_type & 8'b11011000) == 8'b01000000;
    wire [2:0] packet_number_length_bytes = (packet_type & 2'b11) + 1;

    localparam PACKET_NUMBER_POS = 8 + DCID_LENGTH*8;
    wire [31:0] packet_number_raw = quic_headers[PACKET_NUMBER_POS+31:PACKET_NUMBER_POS];
    // Mask out the packet number depending on the length field
    wire [31:0] packet_number = packet_number_raw[7:0]
        | (packet_number_length_bytes > 1 ? packet_number[15:8] : 0)
        | (packet_number_length_bytes > 2 ? packet_number[23:16] : 0)
        | (packet_number_length_bytes > 3 ? packet_number[31:24] : 0);

    // True if all the packet headers have been communicated in this one
    // transfer.
    wire need_two_transfers = 42 + 1 + packet_number_length_bytes + DCID_LENGTH <=
        C_AXIS_DATA_WIDTH/8;

    // Compute cryptographic parameters
    wire nonce = packet_protection_iv ^ packet_number;
    // key is constant
    

endmodule
