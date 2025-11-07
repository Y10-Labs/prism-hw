module axis_deser #
(
    parameter FREQ_HZ = 50000000,
    parameter DATA_W = 32
)
(
    input  wire                   aclk,
    input  wire                   aresetn,

    input  wire [DATA_W-1:0]      s_tdata,
    input  wire                   s_tvalid,
    output wire                   s_tready,
    input  wire                   s_tlast,
    input  wire                   stall,

    output reg  [4*DATA_W-1:0]    m_data128,
    output reg                    m_valid,
    input  wire                   m_ready
);

    reg [1:0]  word_cnt;
    reg        buffer_full;

    wire handshake = s_tvalid && s_tready;

    // Slave always ready unless buffer full
    assign s_tready = !buffer_full || !stall;

    always @(posedge aclk) begin
        if (!aresetn) begin
            word_cnt    <= 0;
            m_valid     <= 0;
            buffer_full <= 0;
            m_data128   <= 0;
        end else begin
            // Clear output valid when downstream accepts
            if (m_valid && m_ready) begin
                m_valid     <= 0;
                buffer_full <= 0;
            end

            if (handshake) begin
                m_data128 <= {m_data128[3*DATA_W-1:0], s_tdata};
                word_cnt <= word_cnt + 1;
                
                if (word_cnt == 2'd3) begin
                    m_valid     <= 1;
                    buffer_full <= 1;
                    word_cnt    <= 0;
                end 
                else buffer_full <= 0;
            end
        end
    end

endmodule
