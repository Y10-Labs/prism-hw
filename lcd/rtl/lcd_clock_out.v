// ---------------------------------------------------------------------------
// lcd_clock_out - forward the pixel clock to an I/O pin
//
// A clock must never reach an output pin through a plain `assign`: that routes
// it clk -> BUFG -> IOB, a path several ns long that no timing constraint
// accounts for, leaving the phase between DCLK and the data at the connector
// uncharacterised.  An ODDR sits in the IOB itself, so the forwarded clock and
// the data share the same output path and delay.
//
// i_invert is a RUNTIME input, not a parameter, and that is deliberate.  The
// ST7262 has a DCLKPOL bit (register 1Bh) whose reset default is 1, i.e.
// negative polarity, while the CH500WV05A-T module datasheet states the panel
// latches on the RISING edge.  Those disagree, DCLKPOL is also settable by
// hardware strap on the module, and the module does not bring SPI or I2C out
// to the 40-pin FPC, so there is no way to read back which it actually is.
// Making this switchable at runtime means the polarity can be flipped during
// bring-up without a rebuild.
//
// i_invert = 0 forwards `clk` as is: data changes on DCLK's rising edge and
// DCLK's FALLING edge lands mid-eye.  That is what the Prism panel needs - it
// was measured to latch on the falling edge (DCLKPOL = 1), so 0 is the default
// (lcd_defaults.vh).  i_invert = 1 forwards a clock 180 degrees out of phase,
// centring the RISING edge instead, for a panel strapped the other way.
//
// i_force = 1 parks DCLK statically at i_force_val (pin-override mode, for
// checking the trace with a meter).
//
// Define LCD_USE_ODDR for synthesis (the Vivado script does); simulators get
// the behavioural version.
// ---------------------------------------------------------------------------

`default_nettype none

module lcd_clock_out (
    input  wire clk,
    input  wire rst_n,
    input  wire i_invert,
    input  wire i_force,
    input  wire i_force_val,
    output wire o_clk
);

`ifdef LCD_USE_ODDR
    // D1 is driven while clk is high, D2 while clk is low.
    wire d1 = i_force ? i_force_val : ~i_invert;
    wire d2 = i_force ? i_force_val :  i_invert;

    ODDR #(
        .DDR_CLK_EDGE ("SAME_EDGE"),
        .INIT         (1'b0),
        .SRTYPE       ("SYNC")
    ) u_oddr (
        .Q  (o_clk),
        .C  (clk),
        .CE (1'b1),
        .D1 (d1),
        .D2 (d2),
        .R  (~rst_n),
        .S  (1'b0)
    );
`else
    assign o_clk = i_force ? i_force_val : (i_invert ? ~clk : clk);
`endif

endmodule

`default_nettype wire
