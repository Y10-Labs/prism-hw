// ---------------------------------------------------------------------------
// lcd_debug_top - runtime-tunable LCD bring-up bitstream for the Prism board
//
//   PS7 (block design prism_ps, built by syn/build_debug.tcl)
//     FCLK0  50 MHz  -> AXI clock (M_AXI_GP0 -> AXI4-Lite -> lcd_regs_axil)
//     FCLK1  pixel   -> lcd_controller.  Rate set at runtime from Linux by
//                       rewriting FPGA1_CLK_CTRL (sw/lcdctl.py `pclk`).
//     AXI VDMA (in the BD, regs at 0x4300_0000): reads frame buffers from DDR
//                       through S_AXI_HP0 and streams them out on M_AXIS_VID
//                       (FCLK0) -> lcd_stream_src -> i_pixel (pattern `ext`).
//
// The Prism board has no PL oscillator (its only one feeds PS_CLK), so both
// clocks necessarily come from the PS.  No MMCM: the pixel clock is a pure
// PS FCLK, stepped with the FCLK dividers.
//
// Registers at 0x43C0_0000; map in lcd_regs_axil.v and lcd/README.md.
// ---------------------------------------------------------------------------

`default_nettype none

module lcd_debug_top #(
    parameter [31:0] BUILD_ID = 32'h0
)(
    // PS7 fixed I/O, passed straight through to the block design
    inout  wire [14:0] DDR_addr,
    inout  wire [2:0]  DDR_ba,
    inout  wire        DDR_cas_n,
    inout  wire        DDR_ck_n,
    inout  wire        DDR_ck_p,
    inout  wire        DDR_cke,
    inout  wire        DDR_cs_n,
    inout  wire [3:0]  DDR_dm,
    inout  wire [31:0] DDR_dq,
    inout  wire [3:0]  DDR_dqs_n,
    inout  wire [3:0]  DDR_dqs_p,
    inout  wire        DDR_odt,
    inout  wire        DDR_ras_n,
    inout  wire        DDR_reset_n,
    inout  wire        DDR_we_n,
    inout  wire        FIXED_IO_ddr_vrn,
    inout  wire        FIXED_IO_ddr_vrp,
    inout  wire [53:0] FIXED_IO_mio,
    inout  wire        FIXED_IO_ps_clk,
    inout  wire        FIXED_IO_ps_porb,
    inout  wire        FIXED_IO_ps_srstb,

    // panel
    output wire       o_clk,
    output wire       o_hsync,
    output wire       o_vsync,
    output wire       o_de,
    output wire       o_disp,
    output wire [7:0] o_red,
    output wire [7:0] o_green,
    output wire [7:0] o_blue,
    output wire       o_bl_en
);

    wire axi_clk, axi_aresetn, pix_clk, pix_aresetn;

    wire [31:0] awaddr, wdata, araddr, rdata;
    wire [3:0]  wstrb;
    wire [1:0]  bresp, rresp;
    wire awvalid, awready, wvalid, wready, bvalid, bready;
    wire arvalid, arready, rvalid, rready;

    wire [31:0] vid_tdata;
    wire [0:0]  vid_tuser;
    wire        vid_tlast, vid_tvalid, vid_tready;

    prism_ps_wrapper u_ps (
        .DDR_addr (DDR_addr), .DDR_ba (DDR_ba), .DDR_cas_n (DDR_cas_n),
        .DDR_ck_n (DDR_ck_n), .DDR_ck_p (DDR_ck_p), .DDR_cke (DDR_cke),
        .DDR_cs_n (DDR_cs_n), .DDR_dm (DDR_dm), .DDR_dq (DDR_dq),
        .DDR_dqs_n (DDR_dqs_n), .DDR_dqs_p (DDR_dqs_p), .DDR_odt (DDR_odt),
        .DDR_ras_n (DDR_ras_n), .DDR_reset_n (DDR_reset_n), .DDR_we_n (DDR_we_n),
        .FIXED_IO_ddr_vrn (FIXED_IO_ddr_vrn), .FIXED_IO_ddr_vrp (FIXED_IO_ddr_vrp),
        .FIXED_IO_mio (FIXED_IO_mio), .FIXED_IO_ps_clk (FIXED_IO_ps_clk),
        .FIXED_IO_ps_porb (FIXED_IO_ps_porb), .FIXED_IO_ps_srstb (FIXED_IO_ps_srstb),

        .axi_clk     (axi_clk),
        .axi_aresetn (axi_aresetn),
        .pix_clk     (pix_clk),
        .pix_aresetn (pix_aresetn),

        .M_AXI_LCD_awaddr  (awaddr),  .M_AXI_LCD_awprot  (),
        .M_AXI_LCD_awvalid (awvalid), .M_AXI_LCD_awready (awready),
        .M_AXI_LCD_wdata   (wdata),   .M_AXI_LCD_wstrb   (wstrb),
        .M_AXI_LCD_wvalid  (wvalid),  .M_AXI_LCD_wready  (wready),
        .M_AXI_LCD_bresp   (bresp),   .M_AXI_LCD_bvalid  (bvalid),
        .M_AXI_LCD_bready  (bready),
        .M_AXI_LCD_araddr  (araddr),  .M_AXI_LCD_arprot  (),
        .M_AXI_LCD_arvalid (arvalid), .M_AXI_LCD_arready (arready),
        .M_AXI_LCD_rdata   (rdata),   .M_AXI_LCD_rresp   (rresp),
        .M_AXI_LCD_rvalid  (rvalid),  .M_AXI_LCD_rready  (rready),

        .M_AXIS_VID_tdata  (vid_tdata),
        .M_AXIS_VID_tuser  (vid_tuser),
        .M_AXIS_VID_tlast  (vid_tlast),
        .M_AXIS_VID_tvalid (vid_tvalid),
        .M_AXIS_VID_tready (vid_tready)
    );

    // ---- registers --------------------------------------------------------
    wire        pix_rst_n;
    wire        enable, clk_invert, hs_al, vs_al, de_al, de_only, pin_ovr;
    wire [11:0] h_active, h_front, h_sync, h_back;
    wire [11:0] v_active, v_front, v_sync, v_back;
    wire [3:0]  pattern;
    wire [7:0]  pattern_arg, blank_frames, disp_frames, off_frames;
    wire [23:0] solid, vdd_wait;
    wire [29:0] pin_value;
    wire [2:0]  seq_state;
    wire        ready, frame_start;
    wire [11:0] px_x, px_y;
    wire        px_active;
    wire [23:0] ext_pixel;
    wire [1:0]  src_state;
    wire        src_underflow, src_misalign;

    lcd_regs_axil #(
        .BUILD_ID (BUILD_ID),
        .AXI_HZ   (50000000)
    ) u_regs (
        .s_axi_aclk    (axi_clk),
        .s_axi_aresetn (axi_aresetn),
        .s_axi_awaddr  (awaddr[11:0]), .s_axi_awvalid (awvalid), .s_axi_awready (awready),
        .s_axi_wdata   (wdata),        .s_axi_wstrb   (wstrb),
        .s_axi_wvalid  (wvalid),       .s_axi_wready  (wready),
        .s_axi_bresp   (bresp),        .s_axi_bvalid  (bvalid),  .s_axi_bready (bready),
        .s_axi_araddr  (araddr[11:0]), .s_axi_arvalid (arvalid), .s_axi_arready (arready),
        .s_axi_rdata   (rdata),        .s_axi_rresp   (rresp),
        .s_axi_rvalid  (rvalid),       .s_axi_rready  (rready),

        .pix_clk     (pix_clk),
        .pix_rst_n   (pix_aresetn),
        .o_pix_rst_n (pix_rst_n),

        .o_enable        (enable),
        .o_clk_invert    (clk_invert),
        .o_hs_active_low (hs_al),
        .o_vs_active_low (vs_al),
        .o_de_active_low (de_al),
        .o_de_only       (de_only),
        .o_h_active (h_active), .o_h_front (h_front), .o_h_sync (h_sync), .o_h_back (h_back),
        .o_v_active (v_active), .o_v_front (v_front), .o_v_sync (v_sync), .o_v_back (v_back),
        .o_pattern      (pattern),
        .o_pattern_arg  (pattern_arg),
        .o_solid        (solid),
        .o_vdd_wait     (vdd_wait),
        .o_blank_frames (blank_frames),
        .o_disp_frames  (disp_frames),
        .o_off_frames   (off_frames),
        .o_pin_override (pin_ovr),
        .o_pin_value    (pin_value),

        .i_seq_state   (seq_state),
        .i_ready       (ready),
        // decoded from the sequencer state, NOT read back from the pins: the
        // pin flops are in the IOBs and cannot also feed fabric logic
        .i_disp        (seq_state == 3'd3 || seq_state == 3'd4 || seq_state == 3'd5),
        .i_bl_en       (ready),
        .i_frame_start (frame_start),
        .i_src_state     (src_state),
        .i_src_underflow (src_underflow),
        .i_src_misalign  (src_misalign)
    );

    // ---- DDR frame stream -> pixels ------------------------------------------
    lcd_stream_src u_src (
        .s_axis_aclk    (axi_clk),
        .s_axis_aresetn (axi_aresetn),
        .s_axis_tdata   (vid_tdata),
        .s_axis_tuser   (vid_tuser),
        .s_axis_tlast   (vid_tlast),
        .s_axis_tvalid  (vid_tvalid),
        .s_axis_tready  (vid_tready),
        .clk            (pix_clk),
        .rst_n          (pix_aresetn),     // external reset only, see lcd_async_fifo
        .i_x            (px_x),
        .i_y            (px_y),
        .i_active       (px_active),
        .o_pixel        (ext_pixel),
        .o_state        (src_state),
        .o_underflow    (src_underflow),
        .o_misalign     (src_misalign)
    );

    // ---- controller -------------------------------------------------------
    lcd_controller u_lcd (
        .clk          (pix_clk),
        .rst_n        (pix_rst_n),
        .i_enable     (enable),
        .i_clk_invert (clk_invert),

        .i_h_active (h_active), .i_h_front (h_front), .i_h_sync (h_sync), .i_h_back (h_back),
        .i_v_active (v_active), .i_v_front (v_front), .i_v_sync (v_sync), .i_v_back (v_back),
        .i_hs_active_low (hs_al),
        .i_vs_active_low (vs_al),
        .i_de_active_low (de_al),
        .i_de_only       (de_only),

        .i_vdd_wait     (vdd_wait),
        .i_blank_frames (blank_frames),
        .i_disp_frames  (disp_frames),
        .i_off_frames   (off_frames),

        .i_pattern      (pattern),
        .i_pattern_arg  (pattern_arg),
        .i_solid        (solid),
        .o_x            (px_x),
        .o_y            (px_y),
        .o_active       (px_active),
        .i_pixel        (ext_pixel),

        .i_pin_override (pin_ovr),
        .i_pin_value    (pin_value),

        .o_clk   (o_clk),
        .o_hsync (o_hsync),
        .o_vsync (o_vsync),
        .o_de    (o_de),
        .o_disp  (o_disp),
        .o_red   (o_red),
        .o_green (o_green),
        .o_blue  (o_blue),
        .o_bl_en (o_bl_en),

        .o_ready       (ready),
        .o_seq_state   (seq_state),
        .o_frame_start (frame_start)
    );

endmodule

`default_nettype wire
