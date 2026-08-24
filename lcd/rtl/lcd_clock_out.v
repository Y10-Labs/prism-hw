// ---------------------------------------------------------------------------
// lcd_clock_out - forward the pixel clock to an I/O pin
//
// A clock must never reach an output pin through a plain `assign`: that routes
// it clk -> BUFG -> IOB, a path several ns long that is not accounted for in
// any timing constraint, so the phase between DCLK and the data at the
// connector ends up uncharacterised.  An ODDR sits in the IOB itself, so the
// forwarded clock and the data share the same output path and delay.
//
// With INVERT=1 (the default) the forwarded clock is 180 degrees out of phase
// with `clk`.  Pixel data is registered on the rising edge of `clk`, so DCLK's
// rising edge - the edge this panel latches on - lands in the middle of the
// data eye: half a pixel period of setup and half of hold.
//
// Define LCD_USE_ODDR for synthesis (the Vivado script does).  Simulators get
// the behavioural version.
// ---------------------------------------------------------------------------

`default_nettype none

module lcd_clock_out #(
    parameter INVERT = 1'b1
)(
    input  wire clk,
    input  wire rst_n,
    output wire o_clk
);

`ifdef LCD_USE_ODDR
    ODDR #(
        .DDR_CLK_EDGE ("SAME_EDGE"),
        .INIT         (1'b0),
        .SRTYPE       ("SYNC")
    ) u_oddr (
        .Q  (o_clk),
        .C  (clk),
        .CE (1'b1),
        .D1 (INVERT ? 1'b0 : 1'b1),   // driven while clk is high
        .D2 (INVERT ? 1'b1 : 1'b0),   // driven while clk is low
        .R  (~rst_n),
        .S  (1'b0)
    );
`else
    assign o_clk = INVERT ? ~clk : clk;
`endif

endmodule

`default_nettype wire
