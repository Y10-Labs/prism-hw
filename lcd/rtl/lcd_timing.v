// ---------------------------------------------------------------------------
// lcd_timing - RGB display timing generator, runtime-configurable
//
// Target panel: ChengHao CH500WV05A-T (Adafruit 1596), 5.0" 800x480 24-bit
// parallel RGB, driver IC Sitronix ST7262.  The mode is NOT baked in: every
// active / porch / sync length and every polarity is an input, so the whole
// mode can be swept at runtime from software (see lcd_regs_axil.v).  The
// ST7262 limits (section 7.3.4) and the default 832 x 500 @ 25 MHz mode are
// documented in lcd/README.md; lcd_timing_tb asserts them.
//
// Region order within a line/frame is ACTIVE, FRONT PORCH, SYNC, BACK PORCH.
//
// Every output is driven from a single register stage so DE, the syncs and
// the pixel data are aligned at the pins with no relative skew.
//
// o_x / o_y / o_active are the *pre-register* coordinates: a pixel source
// must register its data off them with exactly one cycle of latency for
// i_pixel to land in the same stage as o_de.
//
// Changing the mode while running is safe: the counters wrap on ">= total",
// so a shrinking total can never strand them past the end of a line/frame.
// The picture may tear for one frame, nothing worse.  Every length must be
// at least 1.
// ---------------------------------------------------------------------------

`default_nettype none

module lcd_timing (
    input  wire clk,
    input  wire rst_n,
    input  wire i_enable,      // hold high to run continuously

    // mode, lengths in DCLKs (H) and lines (V); all must be >= 1
    input  wire [11:0] i_h_active,
    input  wire [11:0] i_h_front,
    input  wire [11:0] i_h_sync,
    input  wire [11:0] i_h_back,
    input  wire [11:0] i_v_active,
    input  wire [11:0] i_v_front,
    input  wire [11:0] i_v_sync,
    input  wire [11:0] i_v_back,
    input  wire        i_hs_active_low,   // 1 = HSYNC pulses low (ST7262 default)
    input  wire        i_vs_active_low,   // 1 = VSYNC pulses low (ST7262 default)
    input  wire        i_de_active_low,   // 0 = DE high during active (ST7262 default)

    // pre-register coordinates, for an external pixel source
    output wire [11:0] o_x,
    output wire [11:0] o_y,
    output wire        o_active,

    // registered outputs, mutually aligned
    output reg  o_hsync,
    output reg  o_vsync,
    output reg  o_de,
    output reg  o_frame_start  // one clk pulse at the first active pixel
);

    // 13 bits so the sums of four 12-bit lengths cannot overflow.
    wire [13:0] h_total    = i_h_active + i_h_front + i_h_sync + i_h_back;
    wire [13:0] v_total    = i_v_active + i_v_front + i_v_sync + i_v_back;
    wire [13:0] h_sync_beg = i_h_active + i_h_front;
    wire [13:0] h_sync_end = h_sync_beg + i_h_sync;          // exclusive
    wire [13:0] v_sync_beg = i_v_active + i_v_front;
    wire [13:0] v_sync_end = v_sync_beg + i_v_sync;          // exclusive

    reg [13:0] h_cnt;
    reg [13:0] v_cnt;

    wire h_last = (h_cnt >= h_total - 1'b1);
    wire v_last = (v_cnt >= v_total - 1'b1);

    always @(posedge clk) begin
        if (!rst_n || !i_enable) begin
            // park at the top-left so every enable starts a whole frame
            h_cnt <= 14'd0;
            v_cnt <= 14'd0;
        end
        else if (h_last) begin
            h_cnt <= 14'd0;
            v_cnt <= v_last ? 14'd0 : (v_cnt + 1'b1);
        end
        else begin
            h_cnt <= h_cnt + 1'b1;
        end
    end

    // combinational region decode
    wire h_act = (h_cnt < i_h_active);
    wire v_act = (v_cnt < i_v_active);
    wire de_c  = i_enable && h_act && v_act;

    wire h_syn = i_enable && (h_cnt >= h_sync_beg) && (h_cnt < h_sync_end);
    wire v_syn = i_enable && (v_cnt >= v_sync_beg) && (v_cnt < v_sync_end);

    wire frame_start_c = i_enable && (h_cnt == 14'd0) && (v_cnt == 14'd0);

    assign o_x      = h_act ? h_cnt[11:0] : 12'd0;
    assign o_y      = v_act ? v_cnt[11:0] : 12'd0;
    assign o_active = de_c;

    always @(posedge clk) begin
        if (!rst_n) begin
            o_hsync       <= i_hs_active_low;
            o_vsync       <= i_vs_active_low;
            o_de          <= i_de_active_low;
            o_frame_start <= 1'b0;
        end
        else begin
            o_hsync       <= h_syn ^ i_hs_active_low;
            o_vsync       <= v_syn ^ i_vs_active_low;
            o_de          <= de_c  ^ i_de_active_low;
            o_frame_start <= frame_start_c;
        end
    end

endmodule

`default_nettype wire
