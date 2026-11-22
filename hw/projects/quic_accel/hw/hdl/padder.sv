`timescale 1ns / 1ps

// Adds padding to Ethernet frames that aren't long enough (60 bytes minimum
// is needed)
module padder #(
    parameter C_AXIS_DATA_WIDTH = 512,
    parameter C_AXIS_TUSER_WIDTH = 128
) (
    input axis_aclk,
    input axis_resetn,

    input [C_AXIS_DATA_WIDTH-1:0] s_axis_tdata,
    input [C_AXIS_DATA_WIDTH/8-1:0] s_axis_tkeep,
    input [C_AXIS_TUSER_WIDTH-1:0] s_axis_tuser,
    input s_axis_tvalid,
    output s_axis_tready,
    input s_axis_tlast,

    output reg [C_AXIS_DATA_WIDTH-1:0] m_axis_tdata,
    output reg [C_AXIS_DATA_WIDTH/8-1:0] m_axis_tkeep,
    output reg [C_AXIS_TUSER_WIDTH-1:0] m_axis_tuser,
    output reg m_axis_tvalid,
    input m_axis_tready,
    output reg m_axis_tlast
);
    localparam MIN_FRAME_LEN=60;

    assign s_axis_tready = m_axis_tready || !m_axis_tvalid;

    reg is_new_packet;

    wire [15:0] s_axis_tuser_length = s_axis_tuser[15:0];
    wire need_to_pad = (s_axis_tuser_length < MIN_FRAME_LEN) && is_new_packet;

    wire [C_AXIS_DATA_WIDTH/8-1:0] padded_tkeep = s_axis_tkeep | ((1 << MIN_FRAME_LEN) - 1);
    wire [C_AXIS_TUSER_WIDTH-1:0] padded_tuser = 
        {s_axis_tuser[C_AXIS_TUSER_WIDTH-1:16], 16'(MIN_FRAME_LEN)};

    always_ff @(posedge axis_aclk) begin
        if(!axis_resetn) begin
            is_new_packet <= 1'b1;
            m_axis_tdata <= '0;
            m_axis_tkeep <= '0;
            m_axis_tuser <= '0;
            m_axis_tlast <= '0;
            m_axis_tvalid <= '0;
        end else begin
            if(s_axis_tready && s_axis_tvalid) begin
                m_axis_tdata <= s_axis_tdata;
                m_axis_tkeep <= need_to_pad ? padded_tkeep : s_axis_tkeep;
                m_axis_tvalid <= s_axis_tvalid;
                m_axis_tlast <= s_axis_tlast;
                m_axis_tuser <= need_to_pad ? padded_tuser : s_axis_tuser;

                is_new_packet <= s_axis_tlast;
            end else if(m_axis_tready) begin
                m_axis_tvalid <= 1'b0;
            end
        end
    end
endmodule
