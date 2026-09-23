// ---------------------------------------------------------------------------
// lcd_bringup_top - minimal panel bring-up, fixed default mode, colour bars
//
// Nothing but the LCD controller in test-pattern mode with every runtime knob
// tied to lcd_defaults.vh.  For the runtime-tunable version, with an AXI
// register block and the PS7, see lcd_debug_top.v.
//
// CLOCKING: the Prism board's only oscillator (50 MHz) drives PS_CLK; there is
// NO oscillator on any PL clock pin.  `clk` must come from a PS FCLK, so this
// module on its own is only good for synthesis checks and simulation.
// ---------------------------------------------------------------------------

`default_nettype none
`include "lcd_defaults.vh"

module lcd_bringup_top (
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

    lcd_controller u_lcd (
        .clk             (clk),
        .rst_n           (rst_n),
        .i_enable        (i_enable),
        .i_clk_invert    (`LCD_DEF_CLK_INVERT),

        .i_h_active (`LCD_DEF_H_ACTIVE), .i_h_front (`LCD_DEF_H_FRONT),
        .i_h_sync   (`LCD_DEF_H_SYNC),   .i_h_back  (`LCD_DEF_H_BACK),
        .i_v_active (`LCD_DEF_V_ACTIVE), .i_v_front (`LCD_DEF_V_FRONT),
        .i_v_sync   (`LCD_DEF_V_SYNC),   .i_v_back  (`LCD_DEF_V_BACK),
        .i_hs_active_low (`LCD_DEF_HS_ACTIVE_LOW),
        .i_vs_active_low (`LCD_DEF_VS_ACTIVE_LOW),
        .i_de_active_low (`LCD_DEF_DE_ACTIVE_LOW),
        .i_de_only       (1'b0),

        .i_vdd_wait     (`LCD_DEF_VDD_WAIT),
        .i_blank_frames (`LCD_DEF_BLANK_FRAMES),
        .i_disp_frames  (`LCD_DEF_DISP_FRAMES),
        .i_off_frames   (`LCD_DEF_OFF_FRAMES),

        .i_pattern      (4'd0),        // colour bars + ramp
        .i_pattern_arg  (8'd0),
        .i_solid        (24'd0),
        .o_x            (),
        .o_y            (),
        .o_active       (),
        .i_pixel        (24'd0),

        .i_pin_override (1'b0),
        .i_pin_value    (30'd0),

        .o_clk    (o_clk),
        .o_hsync  (o_hsync),
        .o_vsync  (o_vsync),
        .o_de     (o_de),
        .o_disp   (o_disp),
        .o_red    (o_red),
        .o_green  (o_green),
        .o_blue   (o_blue),
        .o_bl_en  (o_bl_en),

        .o_ready       (),
        .o_seq_state   (),
        .o_frame_start ()
    );

endmodule

`default_nettype wire
