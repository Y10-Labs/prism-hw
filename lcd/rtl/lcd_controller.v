// ---------------------------------------------------------------------------
// lcd_controller - top level RGB panel driver for the Prism console
//
// Drives a ChengHao CH500WV05A-T (Adafruit 1596) 5.0" 800x480 24-bit parallel
// RGB panel: timing generation, power sequencing, clock forwarding, and a
// self-contained bring-up test pattern.
//
// Pixel source
//   TEST_PATTERN = 1 (default) : internal colour bars + grey ramp, no external
//                                input needed.  Use this to bring the panel up.
//   TEST_PATTERN = 0           : pixels come from i_pixel.  The source must
//                                register off o_x / o_y with EXACTLY one cycle
//                                of latency so i_pixel arrives in the same
//                                stage as o_de.
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

module lcd_controller #(
    // 1056 x 525 @ 33.264 MHz = 60.0 Hz
    parameter integer H_ACTIVE = 800,
    parameter integer H_FRONT  = 40,
    parameter integer H_SYNC   = 48,
    parameter integer H_BACK   = 168,

    parameter integer V_ACTIVE = 480,
    parameter integer V_FRONT  = 13,
    parameter integer V_SYNC   = 3,
    parameter integer V_BACK   = 29,

    // power sequencing, see lcd_power_seq.v for what is and is not from the
    // datasheet
    parameter integer VDD_WAIT_CYCLES = 332640,   // 10 ms @ 33.264 MHz
    parameter integer BLANK_FRAMES    = 2,
    parameter integer DISP_FRAMES     = 10,
    parameter integer OFF_FRAMES      = 2,

    parameter         TEST_PATTERN    = 1'b1,
    parameter         CLK_INVERT      = 1'b1     // DCLK 180 deg from clk
)(
    input  wire clk,        // pixel clock, 33.264 MHz for the defaults above
    input  wire rst_n,
    input  wire i_enable,   // high brings the panel up, low takes it down

    // external pixel source (ignored when TEST_PATTERN = 1)
    output wire [11:0] o_x,
    output wire [11:0] o_y,
    output wire        o_active,
    input  wire [23:0] i_pixel,     // {R[7:0], G[7:0], B[7:0]}

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
    output wire o_ready
);

    wire timing_en, blank, frame_start;
    wire de_i, hsync_i, vsync_i;

    lcd_timing #(
        .H_ACTIVE (H_ACTIVE), .H_FRONT (H_FRONT),
        .H_SYNC   (H_SYNC),   .H_BACK  (H_BACK),
        .V_ACTIVE (V_ACTIVE), .V_FRONT (V_FRONT),
        .V_SYNC   (V_SYNC),   .V_BACK  (V_BACK),
        .SYNC_ACTIVE_LOW (1'b1)
    ) u_timing (
        .clk           (clk),
        .rst_n         (rst_n),
        .i_enable      (timing_en),
        .o_x           (o_x),
        .o_y           (o_y),
        .o_active      (o_active),
        .o_hsync       (hsync_i),
        .o_vsync       (vsync_i),
        .o_de          (de_i),
        .o_frame_start (frame_start)
    );

    lcd_power_seq #(
        .VDD_WAIT_CYCLES (VDD_WAIT_CYCLES),
        .BLANK_FRAMES    (BLANK_FRAMES),
        .DISP_FRAMES     (DISP_FRAMES),
        .OFF_FRAMES      (OFF_FRAMES)
    ) u_seq (
        .clk           (clk),
        .rst_n         (rst_n),
        .i_enable      (i_enable),
        .i_frame_start (frame_start),
        .o_timing_en   (timing_en),
        .o_blank       (blank),
        .o_disp        (o_disp),
        .o_bl_en       (o_bl_en),
        .o_ready       (o_ready)
    );

    lcd_clock_out #(.INVERT (CLK_INVERT)) u_clk_out (
        .clk   (clk),
        .rst_n (rst_n),
        .o_clk (o_clk)
    );

    // ---- pixel source -----------------------------------------------------
    // Bring-up pattern.  The eight colour bars across the top make a swapped
    // R/G/B channel obvious at a glance; the grey ramp along the bottom makes
    // a reversed bit order within a channel obvious.
    localparam integer BAR_W  = H_ACTIVE / 8;
    localparam integer RAMP_Y = (V_ACTIVE * 3) / 4;

    reg [23:0] pattern;
    always @(*) begin
        if (o_y >= RAMP_Y) begin
            // horizontal black-to-white ramp
            pattern = {3{o_x[9:2]}};
        end
        else begin
            case (o_x / BAR_W)
                12'd0:   pattern = 24'h000000; // black
                12'd1:   pattern = 24'h0000FF; // blue
                12'd2:   pattern = 24'h00FF00; // green
                12'd3:   pattern = 24'h00FFFF; // cyan
                12'd4:   pattern = 24'hFF0000; // red
                12'd5:   pattern = 24'hFF00FF; // magenta
                12'd6:   pattern = 24'hFFFF00; // yellow
                default: pattern = 24'hFFFFFF; // white
            endcase
        end
    end

    wire [23:0] px_src = TEST_PATTERN ? pattern : i_pixel;

    // One register stage, matching lcd_timing's, so data lands aligned with DE.
    reg [23:0] px_q;
    always @(posedge clk) begin
        if (!rst_n)
            px_q <= 24'd0;
        else
            px_q <= (blank || !o_active) ? 24'd0 : px_src;
    end

    assign o_red   = px_q[23:16];
    assign o_green = px_q[15:8];
    assign o_blue  = px_q[7:0];
    assign o_de    = de_i;
    assign o_hsync = hsync_i;
    assign o_vsync = vsync_i;

endmodule

`default_nettype wire
