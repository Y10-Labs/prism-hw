// Self-checking testbench for lcd_timing at the real 1056 x 525 @ 60 Hz mode.
// Every check is an assertion; the run fails loudly rather than needing eyes
// on a waveform.
`timescale 1ns/1ps
`default_nettype none

module lcd_timing_tb;

    localparam integer H_ACTIVE = 800, H_FRONT = 16, H_SYNC = 4, H_BACK = 12;
    localparam integer V_ACTIVE = 480, V_FRONT = 10, V_SYNC = 4, V_BACK = 6;
    localparam integer H_TOTAL  = H_ACTIVE + H_FRONT + H_SYNC + H_BACK; // 832
    localparam integer V_TOTAL  = V_ACTIVE + V_FRONT + V_SYNC + V_BACK; // 500
    localparam integer FRAME    = H_TOTAL * V_TOTAL;                    // 416000

    // 25.000 MHz -> 40 ns
    reg clk = 1'b0;
    always #20 clk = ~clk;

    // ---- ST7262 section 7.3.4 limits, in the datasheet's own terms.
    // Note Thbp/Tvbp INCLUDE the sync pulse, hence the H_SYNC + H_BACK sums.
    localparam integer DS_Th_MIN = 808, DS_Th_MAX = 896;
    localparam integer DS_Tv_MIN = 488, DS_Tv_MAX = 504;
    localparam integer DS_HBP_MIN = 4, DS_HBP_MAX = 48;
    localparam integer DS_HFP_MIN = 4, DS_HFP_MAX = 48;
    localparam integer DS_HW_MIN  = 2, DS_HW_MAX  = 8;
    localparam integer DS_VBP_MIN = 4, DS_VBP_MAX = 12;
    localparam integer DS_VFP_MIN = 4, DS_VFP_MAX = 12;
    localparam integer DS_VW_MIN  = 2, DS_VW_MAX  = 8;

    reg rst_n  = 1'b0;
    reg enable = 1'b0;

    wire [11:0] x, y;
    wire        active, hsync, vsync, de, frame_start;

    lcd_timing #(
        .H_ACTIVE(H_ACTIVE), .H_FRONT(H_FRONT), .H_SYNC(H_SYNC), .H_BACK(H_BACK),
        .V_ACTIVE(V_ACTIVE), .V_FRONT(V_FRONT), .V_SYNC(V_SYNC), .V_BACK(V_BACK),
        .SYNC_ACTIVE_LOW(1'b1)
    ) dut (
        .clk(clk), .rst_n(rst_n), .i_enable(enable),
        .o_x(x), .o_y(y), .o_active(active),
        .o_hsync(hsync), .o_vsync(vsync), .o_de(de), .o_frame_start(frame_start)
    );

    integer errors = 0;
    task check(input cond, input [1023:0] msg);
        begin
            if (!cond) begin
                $display("  FAIL: %0s", msg);
                errors = errors + 1;
            end
        end
    endtask

    // ---- measurement ------------------------------------------------------
    integer de_run = 0, de_gap = 0;
    integer lines_this_frame = 0;
    integer bad_line_len = 0;
    integer min_interline_gap = 1<<30;
    integer max_vblank_gap = 0;
    integer frames_done = 0;
    integer frame_len_err = 0;

    integer hs_low = 0, hs_period = 0;
    integer bad_hs_width = 0, bad_hs_period = 0, hs_pulses = 0;
    integer vs_low = 0, bad_vs_width = 0, vs_pulses = 0;

    integer last_frame_start = -1;
    reg prev_de = 1'b0, prev_hs = 1'b1, prev_vs = 1'b1;
    integer t = 0;

    always @(posedge clk) if (rst_n && enable) begin
        t = t + 1;

        // --- DE: active pixels per line, lines per frame, blanking gaps ---
        if (de) begin
            de_run = de_run + 1;
            if (!prev_de && de_gap > 0) begin
                if (de_gap > max_vblank_gap) max_vblank_gap = de_gap;
                if (lines_this_frame > 0 && de_gap < min_interline_gap)
                    min_interline_gap = de_gap;
                de_gap = 0;
            end
        end
        else begin
            de_gap = de_gap + 1;
            if (prev_de) begin
                lines_this_frame = lines_this_frame + 1;
                if (de_run != H_ACTIVE) bad_line_len = bad_line_len + 1;
                de_run = 0;
            end
        end

        // --- HSYNC width and period (active low) ---
        hs_period = hs_period + 1;
        if (!hsync) hs_low = hs_low + 1;
        if (hsync && !prev_hs) begin           // rising edge: pulse just ended
            hs_pulses = hs_pulses + 1;
            if (hs_pulses > 1) begin
                if (hs_low != H_SYNC)  bad_hs_width  = bad_hs_width + 1;
                if (hs_period != H_TOTAL) bad_hs_period = bad_hs_period + 1;
            end
            hs_low = 0; hs_period = 0;
        end

        // --- VSYNC width (active low), in clocks ---
        if (!vsync) vs_low = vs_low + 1;
        if (vsync && !prev_vs) begin
            vs_pulses = vs_pulses + 1;
            if (vs_pulses > 1 && vs_low != V_SYNC * H_TOTAL)
                bad_vs_width = bad_vs_width + 1;
            vs_low = 0;
        end

        // --- frame period and lines per frame ---
        if (frame_start) begin
            if (last_frame_start >= 0) begin
                if ((t - last_frame_start) != FRAME) frame_len_err = frame_len_err + 1;
                if (lines_this_frame != V_ACTIVE) begin
                    $display("  FAIL: frame %0d had %0d DE lines (expected %0d)",
                             frames_done, lines_this_frame, V_ACTIVE);
                    errors = errors + 1;
                end
                frames_done = frames_done + 1;
            end
            last_frame_start = t;
            lines_this_frame = 0;
        end

        prev_de = de; prev_hs = hsync; prev_vs = vsync;
    end

    initial begin
        $display("== lcd_timing_tb : %0d x %0d, frame = %0d clocks ==",
                 H_TOTAL, V_TOTAL, FRAME);
        repeat (10) @(posedge clk);
        rst_n = 1'b1;
        repeat (10) @(posedge clk);
        enable = 1'b1;

        // let three whole frames elapse
        repeat (FRAME * 3 + 4000) @(posedge clk);

        $display("-- measured --");
        $display("   frames completed      : %0d", frames_done);
        $display("   lines with != %0d DE   : %0d", H_ACTIVE, bad_line_len);
        $display("   frame period errors   : %0d", frame_len_err);
        $display("   hsync width errors    : %0d  (of %0d pulses)", bad_hs_width, hs_pulses);
        $display("   hsync period errors   : %0d", bad_hs_period);
        $display("   vsync width errors    : %0d  (of %0d pulses)", bad_vs_width, vs_pulses);
        $display("   max DE-low gap        : %0d clocks  (panel needs >= 2048)", max_vblank_gap);
        $display("   min inter-line DE gap : %0d clocks  (must stay < 2048)", min_interline_gap);

        // ---- the configured mode must be inside the ST7262's limits ----
        check(H_TOTAL >= DS_Th_MIN && H_TOTAL <= DS_Th_MAX,   "Th out of ST7262 range 808..896 DCLK");
        check(V_TOTAL >= DS_Tv_MIN && V_TOTAL <= DS_Tv_MAX,   "Tv out of ST7262 range 488..504 HSYNC");
        check((H_SYNC + H_BACK) >= DS_HBP_MIN && (H_SYNC + H_BACK) <= DS_HBP_MAX, "Thbp out of range 4..48 DCLK");
        check(H_FRONT >= DS_HFP_MIN && H_FRONT <= DS_HFP_MAX, "Thfp out of range 4..48 DCLK");
        check(H_SYNC  >= DS_HW_MIN  && H_SYNC  <= DS_HW_MAX,  "Thw out of range 2..8 DCLK");
        check((V_SYNC + V_BACK) >= DS_VBP_MIN && (V_SYNC + V_BACK) <= DS_VBP_MAX, "Tvbp out of range 4..12 HSYNC");
        check(V_FRONT >= DS_VFP_MIN && V_FRONT <= DS_VFP_MAX, "Tvfp out of range 4..12 HSYNC");
        check(V_SYNC  >= DS_VW_MIN  && V_SYNC  <= DS_VW_MAX,  "Tvw out of range 2..8 HSYNC");

        check(frames_done   >= 2,    "fewer than 2 complete frames observed");
        check(bad_line_len  == 0,    "some lines did not have H_ACTIVE DE clocks");
        check(frame_len_err == 0,    "frame period != H_TOTAL * V_TOTAL");
        check(bad_hs_width  == 0,    "hsync low width != H_SYNC");
        check(bad_hs_period == 0,    "hsync period != H_TOTAL");
        check(bad_vs_width  == 0,    "vsync low width != V_SYNC lines");
        check(hs_pulses     >  100,  "hsync did not toggle");
        check(vs_pulses     >= 2,    "vsync did not toggle");
        // the panel derives end-of-frame from a DE-low gap of >= 2048 DCLKs,
        // and must not see one between lines
        check(max_vblank_gap    >= 2048, "vertical blank shorter than 2048 DCLKs");
        check(min_interline_gap <  2048, "inter-line gap >= 2048, panel would false-trigger VSD");

        if (errors == 0) $display("== PASS ==");
        else             $display("== FAIL : %0d error(s) ==", errors);
        $finish;
    end

endmodule

`default_nettype wire
