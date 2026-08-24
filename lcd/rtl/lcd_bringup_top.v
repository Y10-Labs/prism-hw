// ---------------------------------------------------------------------------
// lcd_bringup_top - minimal panel bring-up bitstream
//
// Nothing but the LCD controller in test-pattern mode.  No DDR, no VDMA, no
// raster core.  If this puts colour bars on the panel then the connector,
// the traces, the bank-13 I/O, the power sequence and the timing are all good,
// and everything after that is a framebuffer problem.
//
// CLOCKING, IMPORTANT: the Prism board has exactly one oscillator (U18) and it
// drives PS_CLK only - see DFTBoard.kicad_pcb, net CLK33.33 -> R100 -> U20.F7
// (PS_CLK_500).  There is NO oscillator on any PL clock pin.  So `clk` here
// cannot come from a package pin; it must be driven by the PS, either from
// FCLK_CLK0 directly or from an MMCM fed by FCLK_CLK0.  That means the
// bring-up bitstream still needs a PS7 instance - a PL-only bitstream is not
// possible on this board.  Wrap this module in a block design with
// processing_system7 and set FCLK_CLK0 to 25.000 MHz (or MMCM to it).
// ---------------------------------------------------------------------------

`default_nettype none

module lcd_bringup_top #(
    // The ST7262's DCLKPOL default and the module datasheet disagree about
    // which DCLK edge latches data, and the module exposes no way to ask.
    // Drive o_clk inverted by default (rising edge mid data eye if the panel
    // latches on the rising edge) and flip this if the image is unstable.
    parameter CLK_INVERT = 1'b1
)(
    input  wire clk,        // 25.000 MHz from the PS, not a package pin
    input  wire rst_n,
    input  wire i_enable,

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

    lcd_controller #(
        .TEST_PATTERN (1'b1)
    ) u_lcd (
        .clk          (clk),
        .rst_n        (rst_n),
        .i_enable     (i_enable),
        .i_clk_invert (CLK_INVERT),

        .o_x      (),          // unused in test-pattern mode
        .o_y      (),
        .o_active (),
        .i_pixel  (24'd0),

        .o_clk    (o_clk),
        .o_hsync  (o_hsync),
        .o_vsync  (o_vsync),
        .o_de     (o_de),
        .o_disp   (o_disp),
        .o_red    (o_red),
        .o_green  (o_green),
        .o_blue   (o_blue),
        .o_bl_en  (o_bl_en),
        .o_ready  ()
    );

endmodule

`default_nettype wire
