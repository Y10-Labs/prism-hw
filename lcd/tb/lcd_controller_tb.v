// Self-checking testbench for the full lcd_controller, focused on the
// power-up / power-down ORDER.  Uses a small frame and a short VDD wait so
// the sequence completes quickly; the timing ratios are covered separately
// by lcd_timing_tb at the real 832 x 500.  Also checks the bit-walk pattern
// and the raw pin override.
`timescale 1ns/1ps
`default_nettype none

module lcd_controller_tb;

    localparam integer H_ACTIVE = 32, H_FRONT = 4, H_SYNC = 4, H_BACK = 8;
    localparam integer V_ACTIVE = 16, V_FRONT = 2, V_SYNC = 2, V_BACK = 4;
    localparam integer H_TOTAL  = H_ACTIVE + H_FRONT + H_SYNC + H_BACK;  // 48
    localparam integer V_TOTAL  = V_ACTIVE + V_FRONT + V_SYNC + V_BACK;  // 24
    localparam integer FRAME    = H_TOTAL * V_TOTAL;                     // 1152

    localparam integer VDD_WAIT     = 200;
    localparam integer BLANK_FRAMES = 2;
    localparam integer DISP_FRAMES  = 3;
    localparam integer OFF_FRAMES   = 2;

    reg clk = 1'b0;
    always #15 clk = ~clk;

    reg rst_n = 1'b0, enable = 1'b0;
    reg [3:0]  pattern  = 4'd0;
    reg [7:0]  pat_arg  = 8'd0;
    reg        pin_ovr  = 1'b0;
    reg [29:0] pin_val  = 30'd0;

    wire [11:0] x, y;
    wire        active, dclk, hsync, vsync, de, disp, bl_en, ready;
    wire [7:0]  red, green, blue;

    lcd_controller dut (
        .clk(clk), .rst_n(rst_n), .i_enable(enable), .i_clk_invert(1'b0),
        .i_h_active(H_ACTIVE[11:0]), .i_h_front(H_FRONT[11:0]),
        .i_h_sync(H_SYNC[11:0]),     .i_h_back(H_BACK[11:0]),
        .i_v_active(V_ACTIVE[11:0]), .i_v_front(V_FRONT[11:0]),
        .i_v_sync(V_SYNC[11:0]),     .i_v_back(V_BACK[11:0]),
        .i_hs_active_low(1'b1), .i_vs_active_low(1'b1), .i_de_active_low(1'b0),
        .i_de_only(1'b0),
        .i_vdd_wait(VDD_WAIT[23:0]), .i_blank_frames(BLANK_FRAMES[7:0]),
        .i_disp_frames(DISP_FRAMES[7:0]), .i_off_frames(OFF_FRAMES[7:0]),
        .i_pattern(pattern), .i_pattern_arg(pat_arg), .i_solid(24'd0),
        .o_x(x), .o_y(y), .o_active(active), .i_pixel(24'd0),
        .i_pin_override(pin_ovr), .i_pin_value(pin_val),
        .o_clk(dclk), .o_hsync(hsync), .o_vsync(vsync), .o_de(de), .o_disp(disp),
        .o_red(red), .o_green(green), .o_blue(blue),
        .o_bl_en(bl_en), .o_ready(ready), .o_seq_state(), .o_frame_start()
    );

    integer errors = 0;
    task check(input cond, input [1023:0] msg);
        begin
            if (!cond) begin $display("  FAIL: %0s", msg); errors = errors + 1; end
        end
    endtask

    // ---- observation ------------------------------------------------------
    integer t = 0;
    integer t_first_de   = -1;   // first valid timing
    integer t_disp_rise  = -1;
    integer t_bl_rise    = -1;
    integer t_bl_fall    = -1;
    integer t_disp_fall  = -1;
    integer t_de_stop    = -1;
    integer nonblack_before_disp = 0;
    integer nonblack_before_bl   = 0;
    integer de_frames_before_disp = 0;
    integer de_frames_before_bl   = 0;

    integer walk_bad = 0, walk_seen = 0, ovr_bad = 0;

    reg prev_disp = 1'b0, prev_bl = 1'b0, prev_de = 1'b0;
    reg prev_vs = 1'b1;

    always @(posedge clk) if (rst_n) begin
        t = t + 1;

        if (de && t_first_de < 0) t_first_de = t;
        if (de) t_de_stop = t;

        // count frames of valid timing via vsync falling edges
        if (!vsync && prev_vs) begin
            if (t_disp_rise < 0) de_frames_before_disp = de_frames_before_disp + 1;
            if (t_bl_rise   < 0) de_frames_before_bl   = de_frames_before_bl   + 1;
        end

        if (disp && !prev_disp) t_disp_rise = t;
        if (!disp && prev_disp) t_disp_fall = t;
        if (bl_en && !prev_bl)  t_bl_rise   = t;
        if (!bl_en && prev_bl)  t_bl_fall   = t;

        // the panel must never be shown non-black data before DISP and the
        // backlight have come up in order
        if (de && ({red, green, blue} != 24'd0)) begin
            if (t_disp_rise < 0) nonblack_before_disp = nonblack_before_disp + 1;
            if (t_bl_rise   < 0) nonblack_before_bl   = nonblack_before_bl   + 1;
        end

        prev_disp = disp; prev_bl = bl_en; prev_de = de; prev_vs = vsync;
    end

    initial begin
        $display("== lcd_controller_tb : power sequence ==");
        repeat (10) @(posedge clk);
        rst_n = 1'b1;

        // nothing should be on before enable
        repeat (50) @(posedge clk);
        check(disp  == 1'b0, "DISP asserted before i_enable");
        check(bl_en == 1'b0, "backlight enabled before i_enable");
        check(de    == 1'b0, "DE running before i_enable");

        enable = 1'b1;
        repeat (VDD_WAIT + FRAME * (BLANK_FRAMES + DISP_FRAMES + 3)) @(posedge clk);

        check(ready == 1'b1, "sequencer never reached RUN");
        check(t_first_de  > 0, "timing never started");
        check(t_disp_rise > 0, "DISP never asserted");
        check(t_bl_rise   > 0, "backlight never enabled");

        // ---- ordering on the way up ----
        check(t_first_de  < t_disp_rise, "DISP asserted before valid timing was running");
        check(t_disp_rise < t_bl_rise,   "backlight enabled before DISP");
        check(nonblack_before_disp == 0, "non-black pixels driven before DISP");
        check(nonblack_before_bl   == 0, "non-black pixels driven before backlight");
        // exact, not >=: the frame counts are the whole point of the sequencer
        check(de_frames_before_disp == BLANK_FRAMES,
              "wrong number of blank frames before DISP");
        check(de_frames_before_bl   == BLANK_FRAMES + DISP_FRAMES,
              "wrong number of frames between DISP and backlight");

        $display("   t(first DE)=%0d  t(DISP^)=%0d  t(BL^)=%0d", t_first_de, t_disp_rise, t_bl_rise);
        $display("   blank frames before DISP=%0d  frames before BL=%0d",
                 de_frames_before_disp, de_frames_before_bl - de_frames_before_disp);

        // ---- patterns, while running ----
        // walk: every active pixel carries exactly one data bit
        walk_bad = 0; walk_seen = 0;
        pattern = 4'd2; pat_arg = 8'd13;           // walk: G5 only
        repeat (FRAME * 2) @(posedge clk);         // let it apply
        repeat (FRAME) @(posedge clk) begin
            if (de) begin
                walk_seen = walk_seen + 1;
                if ({red, green, blue} != (24'd1 << 13)) walk_bad = walk_bad + 1;
            end
        end
        check(walk_seen > 0,  "no DE while checking the walk pattern");
        check(walk_bad == 0,  "walk pattern drove something other than bit 13");
        pattern = 4'd0;

        // raw pin override: every pin follows PIN_VALUE, DCLK parked
        pin_val = {1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 1'b1, 24'hA5C33C};
        pin_ovr = 1'b1;
        repeat (4) @(posedge clk);
        repeat (20) @(posedge clk) begin
            if ({bl_en, disp, de, vsync, hsync} != 5'b10101 ||
                {red, green, blue} != 24'hA5C33C)
                ovr_bad = ovr_bad + 1;
        end
        @(negedge clk); if (dclk !== 1'b1) ovr_bad = ovr_bad + 1;
        @(posedge clk); #1; if (dclk !== 1'b1) ovr_bad = ovr_bad + 1;
        check(ovr_bad == 0, "pin override did not drive the pins");
        pin_ovr = 1'b0;
        repeat (4) @(posedge clk);

        // ---- ordering on the way down ----
        enable = 1'b0;
        repeat (FRAME * (OFF_FRAMES * 2 + 3)) @(posedge clk);

        check(t_bl_fall   > 0, "backlight never turned off");
        check(t_disp_fall > 0, "DISP never deasserted");
        check(t_bl_fall < t_disp_fall, "DISP dropped before the backlight");
        check(t_de_stop >= t_disp_fall, "timing stopped before DISP dropped");
        check(bl_en == 1'b0 && disp == 1'b0, "did not return to the off state");

        $display("   t(BL v)=%0d  t(DISP v)=%0d  t(last DE)=%0d",
                 t_bl_fall, t_disp_fall, t_de_stop);

        if (errors == 0) $display("== PASS ==");
        else             $display("== FAIL : %0d error(s) ==", errors);
        $finish;
    end

endmodule

`default_nettype wire
