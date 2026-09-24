// ---------------------------------------------------------------------------
// lcd_stream_src - AXI4-Stream video (e.g. from AXI VDMA MM2S) -> i_pixel
//
// Stream side (s_axis_*, the AXI clock): 32-bit beats, {8'hx, R, G, B}, one
// pixel per beat, tuser[0] = start of frame (first pixel), tlast = end of
// line (ignored; the frame is re-aligned on every SOF instead).
//
// Pixel side: feeds lcd_controller's i_pixel with ZERO latency - the head of
// a first-word-fall-through FIFO is presented combinationally and popped in
// the same cycle o_active is high, which is exactly when lcd_controller
// samples i_pixel for pixel (o_x, o_y).
//
// Frame alignment.  The stream and the panel timing run independently, so
// every panel frame is locked to a stream SOF:
//   SEEK   discard beats until the FIFO head is a SOF, then hold it.
//   READY  head is a SOF; wait for the panel's first active pixel.
//   RUN    pop one beat per active pixel.
// At the panel's first active pixel the head MUST be a SOF, otherwise the
// frame is shown black and the source goes back to SEEK (o_misalign pulses).
// A SOF turning up mid-frame (stream frame too short) or an empty FIFO when a
// pixel is due (o_underflow) shows black for that pixel; the next frame's
// check re-aligns.  A VDMA that keeps up therefore gives whole, untorn frames.
// ---------------------------------------------------------------------------

`default_nettype none

module lcd_stream_src #(
    parameter integer FIFO_AW = 9          // 512 beats of elasticity
)(
    // AXI4-Stream slave, s_axis_aclk domain
    input  wire        s_axis_aclk,
    input  wire        s_axis_aresetn,
    input  wire [31:0] s_axis_tdata,
    input  wire [0:0]  s_axis_tuser,
    input  wire        s_axis_tlast,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,

    // pixel domain
    input  wire        clk,
    input  wire        rst_n,             // NOT the soft reset: see lcd_async_fifo
    input  wire [11:0] i_x,
    input  wire [11:0] i_y,
    input  wire        i_active,
    output wire [23:0] o_pixel,

    output wire [1:0]  o_state,
    output reg         o_underflow,       // one-cycle pulses
    output reg         o_misalign
);

    localparam [1:0] S_SEEK = 2'd0, S_READY = 2'd1, S_RUN = 2'd2;

    wire        full, empty;
    wire [24:0] head;                     // {sof, R, G, B}
    reg         pop;

    lcd_async_fifo #(.DW(25), .AW(FIFO_AW)) u_fifo (
        .wr_clk    (s_axis_aclk),
        .wr_rst_n  (s_axis_aresetn),
        .i_wr_en   (s_axis_tvalid),
        .i_wr_data ({s_axis_tuser[0], s_axis_tdata[23:0]}),
        .o_full    (full),
        .rd_clk    (clk),
        .rd_rst_n  (rst_n),
        .i_rd_en   (pop),
        .o_rd_data (head),
        .o_empty   (empty)
    );
    assign s_axis_tready = !full;

    wire head_sof  = !empty && head[24];
    wire first_px  = i_active && (i_x == 12'd0) && (i_y == 12'd0);

    reg [1:0] state;
    reg       show;                        // present the head this cycle
    assign o_state = state;
    assign o_pixel = show ? head[23:0] : 24'h000000;

    always @(*) begin
        pop  = 1'b0;
        show = 1'b0;
        case (state)
            S_SEEK:  pop = !empty && !head[24];
            S_READY: if (first_px && head_sof) begin pop = 1'b1; show = 1'b1; end
            S_RUN:   if (first_px) begin
                         if (head_sof) begin pop = 1'b1; show = 1'b1; end
                     end
                     else if (i_active && !empty && !head[24]) begin
                         pop = 1'b1; show = 1'b1;
                     end
            default: ;
        endcase
    end

    always @(posedge clk) begin
        o_underflow <= 1'b0;
        o_misalign  <= 1'b0;
        if (!rst_n) begin
            state <= S_SEEK;
        end
        else case (state)
            S_SEEK:  if (head_sof) state <= S_READY;
            S_READY: if (first_px) state <= head_sof ? S_RUN : S_SEEK;
            S_RUN: begin
                if (first_px && !head_sof) begin
                    state      <= S_SEEK;
                    o_misalign <= 1'b1;
                end
                else if (i_active && !first_px) begin
                    if (empty)     o_underflow <= 1'b1;
                    else if (head[24]) o_misalign <= 1'b1;   // SOF mid-frame
                end
            end
            default: state <= S_SEEK;
        endcase
    end

    // tlast is part of the interface for completeness; alignment is per SOF.
    wire unused_tlast = s_axis_tlast;

endmodule

`default_nettype wire
