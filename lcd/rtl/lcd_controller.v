// ---------------------------------------------------------------------------
// lcd_controller - top level RGB panel driver for the Prism console
//
// Drives a ChengHao CH500WV05A-T (Adafruit 1596) 5.0" 800x480 24-bit parallel
// RGB panel: timing generation, power sequencing, clock forwarding, test
// patterns and a raw pin override.  Everything is a runtime input so the
// panel can be debugged from software without rebuilding; lcd_bringup_top
// ties them to the datasheet defaults, lcd_debug_top drives them from AXI.
//
// Pixel source, i_pattern:
//   0 BARS    eight colour bars, black-to-white ramp along the bottom quarter
//   1 SOLID   i_solid everywhere
//   2 WALK    only data bit i_pattern_arg[4:0] high ({R,G,B}, B0 = bit 0), so
//             one FPC line at a time can be checked
//   3 RAMPS   red, green, blue and grey ramps in four horizontal bands
//   4 GRID    1 px white border, grey 32 px grid, red / green / blue 16 px
//             blocks in the top-left / top-right / bottom-left corners
//             (mirroring, flipping and porch offsets are obvious)
//   5 CHECKER 32 px black/white checkerboard
//   6 EXT     i_pixel, sampled in the SAME cycle as o_x / o_y / o_active
//             (zero latency): i_pixel must be the pixel for the o_x / o_y
//             currently presented.  lcd_stream_src does this with a
//             first-word-fall-through FIFO popped on o_active.
//   other     black
//
// Pin override (i_pin_override = 1): every panel pin, DCLK included, is
// driven statically from i_pin_value = {bl_en, disp, de, vsync, hsync, dclk,
// R[7:0], G[7:0], B[7:0]}, bypassing the timing.  Use it to check each trace
// with a meter.
//
// All panel outputs leave through one final register stage, packed into the
// IOBs (see the IOB attributes), so DCLK (an ODDR, also in the IOB) and the
// data have matched, routing-independent output delays.
//
// Board wiring (Prism, XC7Z020-CLG484, all of bank 13 at VCCO = 3.3 V):
//   o_red[7:0]   -> J701.5..12    o_clk    -> J701.30 (Y5)
//   o_green[7:0] -> J701.13..20   o_disp   -> J701.31 (Y6)
//   o_blue[7:0]  -> J701.21..28   o_hsync  -> J701.32 (AA6)
//                                 o_vsync  -> J701.33 (AA7)
//                                 o_de     -> J701.34 (AB1)
//   o_bl_en -> U701 (MT3608) EN, package pin AA4.  NOT on the panel connector.
// ---------------------------------------------------------------------------

`default_nettype none

module lcd_controller (
    input  wire clk,          // pixel clock, 25.000 MHz for the default mode
    input  wire rst_n,
    input  wire i_enable,     // high brings the panel up, low takes it down
    input  wire i_clk_invert, // DCLK polarity; see lcd_clock_out.v

    // mode (see lcd_timing.v)
    input  wire [11:0] i_h_active, i_h_front, i_h_sync, i_h_back,
    input  wire [11:0] i_v_active, i_v_front, i_v_sync, i_v_back,
    input  wire        i_hs_active_low,
    input  wire        i_vs_active_low,
    input  wire        i_de_active_low,
    input  wire        i_de_only,       // 1 = HSYNC and VSYNC held low (ST7262 DE mode)

    // power sequence (see lcd_power_seq.v)
    input  wire [23:0] i_vdd_wait,
    input  wire [7:0]  i_blank_frames,
    input  wire [7:0]  i_disp_frames,
    input  wire [7:0]  i_off_frames,

    // pixel source
    input  wire [3:0]  i_pattern,
    input  wire [7:0]  i_pattern_arg,
    input  wire [23:0] i_solid,         // {R, G, B}
    output wire [11:0] o_x,
    output wire [11:0] o_y,
    output wire        o_active,
    input  wire [23:0] i_pixel,         // {R[7:0], G[7:0], B[7:0]}

    // raw pin drive
    input  wire        i_pin_override,
    input  wire [29:0] i_pin_value,

    // panel interface
    output wire       o_clk,
    output wire       o_hsync,
    output wire       o_vsync,
    output wire       o_de,
    output wire       o_disp,
    output wire [7:0] o_red,
    output wire [7:0] o_green,
    output wire [7:0] o_blue,

    // backlight boost enable (board-level, not a panel pin)
    output wire o_bl_en,

    // status
    output wire       o_ready,
    output wire [2:0] o_seq_state,
    output wire       o_frame_start
);

    localparam [3:0] P_BARS = 4'd0, P_SOLID = 4'd1, P_WALK = 4'd2,
                     P_RAMPS = 4'd3, P_GRID = 4'd4, P_CHECKER = 4'd5,
                     P_EXT = 4'd6;

    wire timing_en, blank, disp_i, bl_en_i;
    wire de_i, hsync_i, vsync_i;

    lcd_timing u_timing (
        .clk             (clk),
        .rst_n           (rst_n),
        .i_enable        (timing_en),
        .i_h_active      (i_h_active), .i_h_front (i_h_front),
        .i_h_sync        (i_h_sync),   .i_h_back  (i_h_back),
        .i_v_active      (i_v_active), .i_v_front (i_v_front),
        .i_v_sync        (i_v_sync),   .i_v_back  (i_v_back),
        .i_hs_active_low (i_hs_active_low),
        .i_vs_active_low (i_vs_active_low),
        .i_de_active_low (i_de_active_low),
        .o_x             (o_x),
        .o_y             (o_y),
        .o_active        (o_active),
        .o_hsync         (hsync_i),
        .o_vsync         (vsync_i),
        .o_de            (de_i),
        .o_frame_start   (o_frame_start)
    );

    lcd_power_seq u_seq (
        .clk            (clk),
        .rst_n          (rst_n),
        .i_enable       (i_enable),
        .i_frame_start  (o_frame_start),
        .i_vdd_wait     (i_vdd_wait),
        .i_blank_frames (i_blank_frames),
        .i_disp_frames  (i_disp_frames),
        .i_off_frames   (i_off_frames),
        .o_timing_en    (timing_en),
        .o_blank        (blank),
        .o_disp         (disp_i),
        .o_bl_en        (bl_en_i),
        .o_ready        (o_ready),
        .o_state        (o_seq_state)
    );

    // ---- pixel source -----------------------------------------------------
    // Bar index by counting, not dividing: the bar width is h_active / 8 and
    // h_active is a runtime value.  o_active is low for at least the porches
    // before every line, which resets the count for x = 0.
    wire [11:0] bar_w = i_h_active >> 3;
    reg  [11:0] bar_cnt;
    reg  [2:0]  bar_idx;
    always @(posedge clk) begin
        if (!rst_n || !o_active) begin
            bar_cnt <= 12'd0;
            bar_idx <= 3'd0;
        end
        else if (bar_cnt + 1'b1 >= bar_w) begin
            bar_cnt <= 12'd0;
            if (bar_idx != 3'd7) bar_idx <= bar_idx + 1'b1;
        end
        else begin
            bar_cnt <= bar_cnt + 1'b1;
        end
    end

    // 0..255 across 800 px: x * 327 / 1024 tops out at 255.2.  Saturate so a
    // wider runtime mode does not wrap.
    wire [20:0] ramp_w = o_x * 9'd327;
    wire [7:0]  ramp   = (ramp_w[20:10] > 11'd255) ? 8'hFF : ramp_w[17:10];

    wire [11:0] v_q  = i_v_active >> 2;               // quarter height
    wire [11:0] v_h  = i_v_active >> 1;
    wire [11:0] v_3q = v_h + v_q;

    reg [23:0] bar_rgb;
    always @(*) begin
        case (bar_idx)
            3'd0:    bar_rgb = 24'h000000; // black
            3'd1:    bar_rgb = 24'h0000FF; // blue
            3'd2:    bar_rgb = 24'h00FF00; // green
            3'd3:    bar_rgb = 24'h00FFFF; // cyan
            3'd4:    bar_rgb = 24'hFF0000; // red
            3'd5:    bar_rgb = 24'hFF00FF; // magenta
            3'd6:    bar_rgb = 24'hFFFF00; // yellow
            default: bar_rgb = 24'hFFFFFF; // white
        endcase
    end

    wire edge_px = (o_x == 12'd0) || (o_x == i_h_active - 1'b1) ||
                   (o_y == 12'd0) || (o_y == i_v_active - 1'b1);
    wire grid_px = (o_x[4:0] == 5'd0) || (o_y[4:0] == 5'd0);
    wire left    = (o_x < 12'd16);
    wire right   = (o_x >= i_h_active - 12'd16);
    wire top     = (o_y < 12'd16);
    wire bottom  = (o_y >= i_v_active - 12'd16);

    reg [23:0] pattern;
    always @(*) begin
        case (i_pattern)
            P_BARS:    pattern = (o_y >= v_3q) ? {3{ramp}} : bar_rgb;
            P_SOLID:   pattern = i_solid;
            P_WALK:    pattern = 24'd1 << i_pattern_arg[4:0];
            P_RAMPS:   pattern = (o_y < v_q)  ? {ramp, 16'd0}        :
                                 (o_y < v_h)  ? {8'd0, ramp, 8'd0}   :
                                 (o_y < v_3q) ? {16'd0, ramp}        :
                                                {3{ramp}};
            P_GRID:    pattern = edge_px        ? 24'hFFFFFF :
                                 (top && left)  ? 24'hFF0000 :
                                 (top && right) ? 24'h00FF00 :
                                 (bottom && left) ? 24'h0000FF :
                                 grid_px        ? 24'h606060 : 24'h000000;
            P_CHECKER: pattern = (o_x[5] ^ o_y[5]) ? 24'hFFFFFF : 24'h000000;
            P_EXT:     pattern = i_pixel;
            default:   pattern = 24'h000000;
        endcase
    end

    // One register stage, matching lcd_timing's, so data lands aligned with DE.
    reg [23:0] px_q;
    always @(posedge clk) begin
        if (!rst_n)
            px_q <= 24'd0;
        else
            px_q <= (blank || !o_active) ? 24'd0 : pattern;
    end

    // ---- output stage, in the IOBs ----------------------------------------
    // i_pin_value = {bl_en, disp, de, vsync, hsync, dclk, R, G, B}
    (* IOB = "TRUE" *) reg [23:0] rgb_q;
    (* IOB = "TRUE" *) reg        hs_q, vs_q, de_q, disp_q, bl_q;

    always @(posedge clk) begin
        if (!rst_n) begin
            rgb_q  <= 24'd0;
            hs_q   <= i_hs_active_low;
            vs_q   <= i_vs_active_low;
            de_q   <= i_de_active_low;
            disp_q <= 1'b0;
            bl_q   <= 1'b0;
        end
        else if (i_pin_override) begin
            {bl_q, disp_q, de_q, vs_q, hs_q} <= i_pin_value[29:25];
            rgb_q <= i_pin_value[23:0];
        end
        else begin
            rgb_q  <= px_q;
            hs_q   <= i_de_only ? 1'b0 : hsync_i;
            vs_q   <= i_de_only ? 1'b0 : vsync_i;
            de_q   <= de_i;
            disp_q <= disp_i;
            bl_q   <= bl_en_i;
        end
    end

    lcd_clock_out u_clk_out (
        .clk         (clk),
        .rst_n       (rst_n),
        .i_invert    (i_clk_invert),
        .i_force     (i_pin_override),
        .i_force_val (i_pin_value[24]),
        .o_clk       (o_clk)
    );

    assign o_red   = rgb_q[23:16];
    assign o_green = rgb_q[15:8];
    assign o_blue  = rgb_q[7:0];
    assign o_hsync = hs_q;
    assign o_vsync = vs_q;
    assign o_de    = de_q;
    assign o_disp  = disp_q;
    assign o_bl_en = bl_q;

endmodule

`default_nettype wire
