// Self-checking testbench for lcd_regs_axil: AXI4-Lite reads/writes and
// byte strobes, the auto-APPLY crossing into the pixel domain and its ack,
// the Gray-coded frame counter, and the pixel clock meter.
//
// AXI clock 50 MHz, pixel clock 25 MHz, deliberately unrelated phases.
// AXI_HZ is shrunk to 1000 so the meter's 100 ms gate is 100 AXI cycles;
// the meter must then read 0.5 * AXI_HZ = 500.
`timescale 1ns/1ps
`default_nettype none

module lcd_regs_tb;

    localparam integer AXI_HZ = 1000;

    reg aclk = 1'b0, pclk = 1'b0;
    always #10    aclk = ~aclk;   // 50 MHz
    always #20.37 pclk = ~pclk;   // ~24.5 MHz, drifts against aclk

    reg aresetn = 1'b0, prst_n = 1'b0;

    reg  [11:0] awaddr = 0, araddr = 0;
    reg  [31:0] wdata = 0;
    reg  [3:0]  wstrb = 4'hF;
    reg         awvalid = 0, wvalid = 0, bready = 0, arvalid = 0, rready = 0;
    wire        awready, wready, bvalid, arready, rvalid;
    wire [1:0]  bresp, rresp;
    wire [31:0] rdata;

    wire        pix_rst_n, enable, clk_inv, hs_al, vs_al, de_al, de_only, ovr;
    wire [11:0] h_act, h_fp, h_sync, h_bp, v_act, v_fp, v_sync, v_bp;
    wire [3:0]  pat;
    wire [7:0]  pat_arg, bl_f, disp_f, off_f;
    wire [23:0] solid, vdd;
    wire [29:0] pin_val;
    reg         frame_start = 1'b0;

    lcd_regs_axil #(.BUILD_ID(32'h12345678), .AXI_HZ(AXI_HZ)) dut (
        .s_axi_aclk(aclk), .s_axi_aresetn(aresetn),
        .s_axi_awaddr(awaddr), .s_axi_awvalid(awvalid), .s_axi_awready(awready),
        .s_axi_wdata(wdata), .s_axi_wstrb(wstrb), .s_axi_wvalid(wvalid), .s_axi_wready(wready),
        .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(bready),
        .s_axi_araddr(araddr), .s_axi_arvalid(arvalid), .s_axi_arready(arready),
        .s_axi_rdata(rdata), .s_axi_rresp(rresp), .s_axi_rvalid(rvalid), .s_axi_rready(rready),
        .pix_clk(pclk), .pix_rst_n(prst_n), .o_pix_rst_n(pix_rst_n),
        .o_enable(enable), .o_clk_invert(clk_inv),
        .o_hs_active_low(hs_al), .o_vs_active_low(vs_al), .o_de_active_low(de_al),
        .o_de_only(de_only),
        .o_h_active(h_act), .o_h_front(h_fp), .o_h_sync(h_sync), .o_h_back(h_bp),
        .o_v_active(v_act), .o_v_front(v_fp), .o_v_sync(v_sync), .o_v_back(v_bp),
        .o_pattern(pat), .o_pattern_arg(pat_arg), .o_solid(solid),
        .o_vdd_wait(vdd), .o_blank_frames(bl_f), .o_disp_frames(disp_f), .o_off_frames(off_f),
        .o_pin_override(ovr), .o_pin_value(pin_val),
        .i_seq_state(3'd4), .i_ready(1'b1), .i_disp(1'b1), .i_bl_en(1'b1),
        .i_frame_start(frame_start),
        .i_src_state(2'd2), .i_src_underflow(1'b0), .i_src_misalign(1'b0)
    );

    integer errors = 0;
    task check(input cond, input [1023:0] msg);
        begin
            if (!cond) begin $display("  FAIL: %0s", msg); errors = errors + 1; end
        end
    endtask

    // AW and W presented together, as the Zynq GP0 -> AXI-Lite path does
    task axi_write(input [11:0] a, input [31:0] d, input [3:0] be);
        begin
            @(posedge aclk);
            awaddr <= a; wdata <= d; wstrb <= be;
            awvalid <= 1'b1; wvalid <= 1'b1; bready <= 1'b1;
            @(posedge aclk);
            while (!(awready && wready)) @(posedge aclk);
            awvalid <= 1'b0; wvalid <= 1'b0;
            while (!bvalid) @(posedge aclk);
            @(posedge aclk);
            bready <= 1'b0;
        end
    endtask

    task axi_read(input [11:0] a, output [31:0] d);
        begin
            @(posedge aclk);
            araddr <= a; arvalid <= 1'b1; rready <= 1'b1;
            @(posedge aclk);
            while (!arready) @(posedge aclk);
            arvalid <= 1'b0;
            while (!rvalid) @(posedge aclk);
            d = rdata;
            @(posedge aclk);
            rready <= 1'b0;
        end
    endtask

    reg [31:0] d;
    integer i;

    initial begin
        $display("== lcd_regs_tb ==");
        repeat (5) @(posedge aclk);
        aresetn = 1'b1;
        @(posedge pclk); prst_n = 1'b1;
        repeat (5) @(posedge aclk);

        axi_read(12'h000, d); check(d == 32'h4C434431, "ID != LCD1");
        axi_read(12'h004, d); check(d == 32'h12345678, "BUILD_ID wrong");

        // reset values must be the default mode
        axi_read(12'h010, d); check(d == {4'd0, 12'd16, 4'd0, 12'd800}, "H_ACT_FP reset");
        axi_read(12'h01C, d); check(d == {4'd0, 12'd6,  4'd0, 12'd4},   "V_SYNC_BP reset");
        axi_read(12'h008, d); check(d[0] == 1'b0, "enable should reset low");
        check(d[1] == 1'b0, "clk_invert should reset low (panel latches on DCLK fall)");
        check(h_act == 800 && h_fp == 16 && v_bp == 6, "pixel-side reset mode wrong");

        // scratch round trip and byte strobes
        axi_write(12'h04C, 32'hCAFEF00D, 4'hF);
        axi_read (12'h04C, d); check(d == 32'hCAFEF00D, "scratch readback");
        axi_write(12'h04C, 32'h11223344, 4'b0101);
        axi_read (12'h04C, d); check(d == 32'hCA22F044, "byte strobes not honoured");

        // config write -> auto APPLY -> pixel domain -> ack
        axi_write(12'h010, {4'd0, 12'd24, 4'd0, 12'd799}, 4'hF);
        axi_write(12'h008, 32'h0000_0221, 4'hF);  // enable, de_only, override
        axi_write(12'h030, 30'h2ABCDEF1, 4'hF);
        axi_write(12'h020, 32'h0000_0D02, 4'hF);  // walk bit 13
        repeat (20) @(posedge aclk);
        axi_read(12'h040, d);
        check(d[4] == 1'b1, "STATUS.applied never set");
        check(d[3:0] == 4'hC, "STATUS seq state / ready not reported");
        check(h_act == 799 && h_fp == 24, "H mode did not reach the pixel domain");
        check(enable && de_only && ovr && !clk_inv, "CTRL did not reach the pixel domain");
        check(pin_val == 30'h2ABCDEF1, "PIN_VALUE did not reach the pixel domain");
        check(pat == 4'd2 && pat_arg == 8'd13, "PATTERN did not reach the pixel domain");

        // soft reset: asserts o_pix_rst_n low but leaves the config alone
        axi_write(12'h008, 32'h0000_0100, 4'hF);
        repeat (20) @(posedge aclk);
        check(pix_rst_n == 1'b0, "soft reset did not reach o_pix_rst_n");
        check(h_act == 799, "soft reset clobbered the captured config");
        axi_write(12'h008, 32'h0000_0000, 4'hF);
        repeat (20) @(posedge aclk);
        check(pix_rst_n == 1'b1, "soft reset did not release");

        // frame counter: 37 pulses
        for (i = 0; i < 37; i = i + 1) begin
            @(posedge pclk); frame_start <= 1'b1;
            @(posedge pclk); frame_start <= 1'b0;
            repeat (3) @(posedge pclk);
        end
        repeat (10) @(posedge aclk);
        axi_read(12'h044, d); check(d == 37, "FRAME_CNT != 37");

        // pixel clock meter: pclk / aclk = 20 / 20.37, over a gate of 100
        // aclk cycles that is ~49 pclk cycles -> ~490 "Hz" at AXI_HZ = 1000
        repeat (400) @(posedge aclk);
        axi_read(12'h048, d);
        $display("   PCLK_HZ = %0d (expect ~491 at AXI_HZ=%0d)", d, AXI_HZ);
        check(d >= 470 && d <= 510, "pixel clock meter out of range");
        axi_read(12'h040, d); check(d[5] == 1'b1, "STATUS.pclk_alive not set");

        axi_read(12'h0FC, d); check(d == 32'hDEADBEEF, "unmapped read should be DEADBEEF");

        if (errors == 0) $display("== PASS ==");
        else             $display("== FAIL : %0d error(s) ==", errors);
        $finish;
    end

endmodule

`default_nettype wire
