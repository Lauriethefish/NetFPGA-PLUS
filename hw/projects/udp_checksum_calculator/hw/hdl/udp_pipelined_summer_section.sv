module udp_pipelined_summer_section
#(
    parameter C_M_AXIS_DATA_WIDTH=1024,
    parameter C_S_AXIS_DATA_WIDTH=1024,
    parameter C_M_AXIS_TUSER_WIDTH=128,
    parameter C_S_AXIS_TUSER_WIDTH=128,

    // NB must be multiple of 8
    parameter DATA_ADD_START,
    // as above.
    parameter DATA_ADD_LENGTH
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
    output reg [31:0] m_axis_partial_sum;

    // Slave Stream Ports (read packet data)
    input [C_S_AXIS_DATA_WIDTH - 1:0] s_axis_tdata,
    input [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_tkeep,
    input [C_S_AXIS_TUSER_WIDTH-1:0] s_axis_tuser,
    input  s_axis_tvalid,
    output s_axis_tready,
    input  s_axis_tlast
    input [31:0] s_axis_partial_sum;
);
    // Ready to receive data IF downstream is ready OR nothing buffered.
    assign s_axis_tready = m_axis_tready || !m_axis_tvalid;

    wire [31:0] segment_sum;

    sum_16_bit_words #(
        DATA_START=DATA_ADD_START,
        DATA_WIDTH=DATA_ADD_LENGTH,
        INPUT_WIDTH=C_M_AXIS_DATA_WIDTH
    ) summer (
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tkeep(s_axis_tkeep),
        .sum(segment_sum)
    )

    always_ff @(posedge axis_aclk) begin
        if(axis_resetn) begin
            if(s_axis_tready && s_axis_tvalid) begin
                m_axis_tdata <= s_axis_tdata;
                m_axis_tvalid <= s_axis_tvalid;
                m_axis_tkeep <= s_axis_tkeep;
                m_axis_tuser <= s_axis_tuser;
                m_axis_tlast <= s_axis_tlast;
                m_axis_partial_sum <= s_axis_partial_sum + segment_sum;
            end

            // If data being transferred out of the output but
            // there is no data to transfer in, then set valid to false
            if(m_axis_tready && m_axis_tvalid && !s_axis_tvalid) begin
                m_axis_tvalid <= 0;
            end
        end else begin
            m_axis_tvalid <= 0;
        end
    end
endmodule