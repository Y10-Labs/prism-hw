// ---------------------------------------------------------------------------
// lcd_defaults.vh - the default panel mode and power sequence, in one place.
//
// Used as the reset values of the AXI registers (lcd_regs_axil.v), as the
// constants of the fixed bring-up top (lcd_bringup_top.v) and by the tbs.
//
// 832 x 500 @ 25.000 MHz = 60.096 Hz.  From the ST7262 datasheet section
// 7.3.4, NOT the CH500WV05A-T module datasheet, which is wrong about the
// clock (it claims typ 40 / max 50 MHz; the IC specifies 23 / 25 / 27):
//
//   Fclk  23   25    27  MHz     -> 25.000
//   Th    808  816  896  DCLK    -> 832   (Thbp + 800 + Thfp)
//   Thbp  4    8    48   DCLK    -> 16    (H_SYNC + H_BACK; Thbp
//                                          INCLUDES the sync pulse)
//   Thfp  4    8    48   DCLK    -> 16
//   Thw   2    4    8    DCLK    -> 4
//   Tv    488  496  504  HSYNC   -> 500   (Tvbp + 480 + Tvfp)
//   Tvbp  4    8    12   HSYNC   -> 10    (V_SYNC + V_BACK)
//   Tvfp  4    8    12   HSYNC   -> 10
//   Tvw   2    4    8    HSYNC   -> 4
//
// Power sequencing, from ST7262 section 11.  At 25 MHz a frame is 16.64 ms.
//   T1 >= 10 ms   reset high -> DISP high       (VDD_WAIT = 250000 = 10 ms)
//   T2 >= 250 ms  display signal -> backlight   (16 frames = 266 ms)
//   off: >= 5 ms  backlight off -> DISP low     (2 frames = 33 ms)
// ---------------------------------------------------------------------------

`define LCD_DEF_H_ACTIVE     12'd800
`define LCD_DEF_H_FRONT      12'd16   // Thfp
`define LCD_DEF_H_SYNC       12'd4    // Thw
`define LCD_DEF_H_BACK       12'd12   // Thbp - Thw
`define LCD_DEF_V_ACTIVE     12'd480
`define LCD_DEF_V_FRONT      12'd10   // Tvfp
`define LCD_DEF_V_SYNC       12'd4    // Tvw
`define LCD_DEF_V_BACK       12'd6    // Tvbp - Tvw

// ST7262 reset defaults (register 1Bh = D7h): VDPOL = HDPOL = 1 (syncs active
// low), DEPOL = 0 (DE active high).
`define LCD_DEF_HS_ACTIVE_LOW 1'b1
`define LCD_DEF_VS_ACTIVE_LOW 1'b1
`define LCD_DEF_DE_ACTIVE_LOW 1'b0

`define LCD_DEF_VDD_WAIT     24'd250000
`define LCD_DEF_BLANK_FRAMES 8'd2
`define LCD_DEF_DISP_FRAMES  8'd16
`define LCD_DEF_OFF_FRAMES   8'd2

// DCLK forwarded NON-inverted: its FALLING edge lands mid data eye.  Verified
// on the Prism panel 2026-09-24: it latches on the falling edge (the ST7262's
// DCLKPOL reset default, 1 = negative), NOT on the rising edge the module
// datasheet claims.  With 1 here the last column of a white border showed
// red (R from the current pixel, G/B from the previous one).
`define LCD_DEF_CLK_INVERT   1'b0
