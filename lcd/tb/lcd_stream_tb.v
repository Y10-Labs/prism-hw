// Self-checking testbench for the DDR-to-panel video path:
//   AXIS source (VDMA MM2S model) -> lcd_stream_src -> lcd_controller (ext)
//
// Small mode (32 x 16) so many frames run quickly.  AXIS clock 50 MHz with
// random tvalid gaps, pixel clock 25 MHz.  Each stream pixel encodes
// {frame id, y, x}, so a displayed frame can be checked pixel by pixel.
//
//   1. The source starts MID-FRAME: the first panel frames must be black or
//      whole, never torn, and the source must lock within a few frames.
//   2. Once locked, every frame must be whole: every pixel {fid, y, x} with
//      one fid for the whole frame, and consecutive fids.
//   3. The source then stalls for a while: underflow must be flagged, and
//      the path must re-lock to whole frames afterwards.
`timescale 1ns/1ps
`default_nettype none

module lcd_stream_tb;

    localparam integer H_ACTIVE = 32, H_FRONT = 4, H_SYNC = 4, H_BACK = 8;
    localparam integer V_ACTIVE = 16, V_FRONT = 2, V_SYNC = 2, V_BACK = 4;
    localparam integer NPIX = H_ACTIVE * V_ACTIVE;

    reg aclk = 1'b0, pclk = 1'b0;
    always #10 aclk = ~aclk;          // 50 MHz
    always #20 pclk = ~pclk;          // 25 MHz

    reg aresetn = 1'b0, prst_n = 1'b0, enable = 1'b0;

    // ---- AXIS source: a VDMA MM2S in free-running park mode -----------------
    reg  [31:0] tdata;
    reg         tuser, tlast, tvalid;
    wire        tready;
    reg  [7:0]  fid;
    integer     sx, sy;
    reg         stall = 1'b0;
    integer     seed = 7;

    // start at pixel (5, 3) of frame 0: mid-frame on purpose
    initial begin fid = 8'd0; sx = 5; sy = 3; tvalid = 1'b0; end

    always @(posedge aclk) begin
        if (!aresetn) begin
            tvalid <= 1'b0;
        end
        else begin
            if (tvalid && tready) begin
                // advance
                if (sx == H_ACTIVE - 1) begin
                    sx = 0;
                    if (sy == V_ACTIVE - 1) begin sy = 0; fid = fid + 1'b1; end
                    else sy = sy + 1;
                end
                else sx = sx + 1;
            end
            if (!(tvalid && !tready)) begin
                // present the next beat, sometimes with a gap
                tvalid <= !stall && ($random(seed) % 4 != 0);
                tdata  <= {8'h00, fid, sy[7:0], sx[7:0]};
                tuser  <= (sx == 0 && sy == 0);
                tlast  <= (sx == H_ACTIVE - 1);
            end
        end
    end

    // ---- DUT ----------------------------------------------------------------
    wire [11:0] x, y;
    wire        active;
    wire [23:0] ext;
    wire [1:0]  src_state;
    wire        uf, mis;
    wire        dclk, hs, vs, de, disp, bl, ready;
    wire [7:0]  r, g, b;

    lcd_stream_src #(.FIFO_AW(6)) u_src (
        .s_axis_aclk(aclk), .s_axis_aresetn(aresetn),
        .s_axis_tdata(tdata), .s_axis_tuser(tuser), .s_axis_tlast(tlast),
        .s_axis_tvalid(tvalid), .s_axis_tready(tready),
        .clk(pclk), .rst_n(prst_n), .i_x(x), .i_y(y), .i_active(active),
        .o_pixel(ext), .o_state(src_state), .o_underflow(uf), .o_misalign(mis)
    );

    lcd_controller u_lcd (
        .clk(pclk), .rst_n(prst_n), .i_enable(enable), .i_clk_invert(1'b0),
        .i_h_active(H_ACTIVE[11:0]), .i_h_front(H_FRONT[11:0]),
        .i_h_sync(H_SYNC[11:0]),     .i_h_back(H_BACK[11:0]),
        .i_v_active(V_ACTIVE[11:0]), .i_v_front(V_FRONT[11:0]),
        .i_v_sync(V_SYNC[11:0]),     .i_v_back(V_BACK[11:0]),
        .i_hs_active_low(1'b1), .i_vs_active_low(1'b1), .i_de_active_low(1'b0),
        .i_de_only(1'b0),
        .i_vdd_wait(24'd20), .i_blank_frames(8'd1), .i_disp_frames(8'd1),
        .i_off_frames(8'd1),
        .i_pattern(4'd6), .i_pattern_arg(8'd0), .i_solid(24'd0),
        .o_x(x), .o_y(y), .o_active(active), .i_pixel(ext),
        .i_pin_override(1'b0), .i_pin_value(30'd0),
        .o_clk(dclk), .o_hsync(hs), .o_vsync(vs), .o_de(de), .o_disp(disp),
        .o_red(r), .o_green(g), .o_blue(b), .o_bl_en(bl),
        .o_ready(ready), .o_seq_state(), .o_frame_start()
    );

    integer errors = 0;
    task check(input cond, input [1023:0] msg);
        begin
            if (!cond) begin $display("  FAIL: %0s", msg); errors = errors + 1; end
        end
    endtask

    // ---- frame checker at the pins -------------------------------------------
    // Classify each displayed frame: BLACK (all zero), GOOD (whole, one fid,
    // every pixel {fid, y, x}), or TORN (anything else).
    integer px = 0, py = 0, nde = 0;
    integer n_good = 0, n_black = 0, n_torn = 0;
    reg     frame_black, frame_good;
    reg [7:0] frame_fid, last_fid;
    reg     have_last = 1'b0;
    integer fid_skips = 0;
    reg     prev_de = 1'b0, prev_vs = 1'b1;
    integer first_good_frame = -1, frame_no = 0;
    reg     counting = 1'b0;

    always @(posedge pclk) begin
        if (bl) begin
            if (!vs && prev_vs) begin
                // vsync: close the previous frame
                if (counting && nde == NPIX) begin
                    if (frame_black)      n_black = n_black + 1;
                    else if (frame_good) begin
                        n_good = n_good + 1;
                        if (first_good_frame < 0) first_good_frame = frame_no;
                        if (have_last && frame_fid != last_fid + 1'b1)
                            fid_skips = fid_skips + 1;
                        last_fid = frame_fid; have_last = 1'b1;
                    end
                    else n_torn = n_torn + 1;
                end
                counting = 1'b1; frame_no = frame_no + 1;
                nde = 0; px = 0; py = 0;
                frame_black = 1'b1; frame_good = 1'b1;
            end
            if (de) begin
                if ({r, g, b} != 24'd0) frame_black = 1'b0;
                if (nde == 0) frame_fid = r;
                if ({r, g, b} != {frame_fid, py[7:0], px[7:0]}) frame_good = 1'b0;
                nde = nde + 1;
                px = px + 1;
            end
            else if (prev_de) begin
                px = 0; py = py + 1;
            end
        end
        prev_de = de; prev_vs = vs;
    end

    reg uf_seen = 1'b0, mis_seen = 1'b0;
    always @(posedge pclk) begin
        if (uf)  uf_seen  <= 1'b1;
        if (mis) mis_seen <= 1'b1;
    end

    localparam integer FRAME = (H_ACTIVE + H_FRONT + H_SYNC + H_BACK) *
                               (V_ACTIVE + V_FRONT + V_SYNC + V_BACK);
    integer good_before, torn_before;

    initial begin
        $display("== lcd_stream_tb ==");
        repeat (5) @(posedge aclk);
        aresetn = 1'b1;
        @(posedge pclk); prst_n = 1'b1;
        repeat (5) @(posedge pclk);
        enable = 1'b1;

        // phase 1+2: lock from a mid-frame start, then run clean
        repeat (FRAME * 20) @(posedge pclk);
        $display("   locked phase : good=%0d black=%0d torn=%0d first_good=frame %0d fid_skips=%0d",
                 n_good, n_black, n_torn, first_good_frame, fid_skips);
        check(n_torn == 0,               "a torn frame reached the panel");
        check(first_good_frame >= 0 && first_good_frame <= 4,
              "did not lock onto whole frames within 4 frames");
        check(n_good >= 12,              "too few good frames once locked");
        check(fid_skips == 0,            "frames skipped or repeated while locked");
        check(uf_seen == 1'b0,           "underflow while the source kept up");

        // phase 3: stall the source for ~2 frames
        good_before = n_good; torn_before = n_torn;
        stall = 1'b1;
        repeat (FRAME * 2) @(posedge pclk);
        stall = 1'b0;
        repeat (FRAME * 10) @(posedge pclk);
        $display("   after stall  : good=%0d (+%0d) black=%0d torn=%0d underflow_seen=%0d misalign_seen=%0d",
                 n_good, n_good - good_before, n_black, n_torn, uf_seen, mis_seen);
        check(uf_seen == 1'b1,             "a stalled source did not flag underflow");
        check(n_good - good_before >= 6,   "did not re-lock to whole frames after the stall");

        if (errors == 0) $display("== PASS ==");
        else             $display("== FAIL : %0d error(s) ==", errors);
        $finish;
    end

endmodule

`default_nettype wire
