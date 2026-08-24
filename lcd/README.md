# Prism LCD controller

Drives a **ChengHao CH500WV05A-T** (Adafruit 1596) 5.0" 800x480 24-bit parallel
RGB panel from the Zynq PL. The panel must be refreshed continuously.

The driver IC inside the module is a **Sitronix ST7262** (`LCD datasheet..pdf`
in the repo root). Where the module datasheet and the IC datasheet disagree,
**believe the IC** - the module sheet is demonstrably wrong about the pixel
clock (see below).

The ST7262 does have 3-wire SPI and I2C configuration interfaces, but the
module does **not** bring them out: FPC pin 35 is NC and 37-40 are the
touchscreen. So the panel runs entirely on its OTP / hardware-strap defaults
and there is no way to configure or interrogate it.

```
rtl/lcd_timing.v       H/V counters, DE, active-low HSYNC/VSYNC, frame_start
rtl/lcd_power_seq.v    power-up / power-down ordering (DISP, backlight, blank)
rtl/lcd_clock_out.v    DCLK forwarding through an ODDR
rtl/lcd_controller.v   top: timing + sequencer + pixel mux + test pattern
rtl/lcd_bringup_top.v  minimal bring-up bitstream, test pattern only
tb/                    self-checking testbenches
xdc/                   Prism board pin + timing constraints
syn/synth_lcd.tcl      batch synth/impl for any part
```

## Test

```sh
make -C lcd            # both testbenches, asserts only, no waveform needed
```

`lcd_timing_tb` runs the real 1056x525 mode and checks active pixels per line,
lines per frame, frame period, sync widths and periods, and both DE-gap
constraints. `lcd_controller_tb` checks the power sequence ordering and the
exact frame counts, up and down.

## Synthesise

```sh
vivado -mode batch -source lcd/syn/synth_lcd.tcl -tclargs xc7z020clg484-2
vivado -mode batch -source lcd/syn/synth_lcd.tcl -tclargs xc7z020clg400-1
```

Last measured (Vivado 2021.2, `lcd_bringup_top`) under the **superseded**
33.264 MHz / 8 ns constraints:

| part | board | WNS | WHS | LUT | FF |
|---|---|---|---|---|---|
| xc7z020clg484-2 | Prism | +4.704 ns | +0.193 ns | 186 | 79 |
| xc7z020clg400-1 | PYNQ-Z2 | +0.620 ns | +0.215 ns | 186 | 79 |

**These numbers need re-measuring.** They predate the move to the ST7262's
real timing: the clock period went 30.062 -> 40.000 ns and the output delay
8 -> 12 ns, a net ~6 ns easier, so both should improve - but that is a
prediction, not a measurement. The logic is unchanged, so the LUT/FF counts
should hold.

The clg484 run uses the real pin constraints. The clg400 run has none (no
verified PYNQ header pinout yet), so its I/O placement is arbitrary and the
number is indicative only.

## Default video mode

**832 x 500 @ 25.000 MHz = 60.1 Hz.**

| | active | front | sync | back | total |
|---|---|---|---|---|---|
| H | 800 | 16 | 4 | 12 | 832 |
| V | 480 | 10 | 4 | 6 | 500 |

Every value sits inside the ST7262's limits (section 7.3.4). The module
datasheet's claim of Fclk typ 40 MHz / max 50 MHz is **wrong**; the IC
specifies 23 / 25 / 27 MHz:

| | symbol | min | typ | max | unit | ours |
|---|---|---|---|---|---|---|
| DCLK frequency | Fclk | 23 | 25 | 27 | MHz | **25.000** |
| H period | Th | 808 | 816 | 896 | DCLK | **832** |
| H back porch | Thbp | 4 | 8 | 48 | DCLK | **16** |
| H front porch | Thfp | 4 | 8 | 48 | DCLK | **16** |
| H sync width | Thw | 2 | 4 | 8 | DCLK | **4** |
| V period | Tv | 488 | 496 | 504 | HSYNC | **500** |
| V back porch | Tvbp | 4 | 8 | 12 | HSYNC | **10** |
| V front porch | Tvfp | 4 | 8 | 12 | HSYNC | **10** |
| V sync width | Tvw | 2 | 4 | 8 | HSYNC | **4** |

Careful with the porch definitions: the ST7262's **Thbp and Tvbp include the
sync pulse** (Th = Thbp + Thdisp + Thfp, and 8 + 800 + 8 = 816 = the typical
Th). This module splits them, so `H_SYNC + H_BACK` is what must land inside
Thbp, and `V_SYNC + V_BACK` inside Tvbp. `lcd_timing_tb` asserts all eight
limits in the datasheet's own terms so a bad mode cannot be committed.

**Known contradiction in the IC datasheet:** section 9.3.4 lists "HSYNC Period
Th 55 / 60 / 65 us", which cannot be reconciled with section 7.3.4 - 60 us x
496 lines would be 33.6 Hz. Section 7.3.4 is internally consistent (Fclk /
(Th x Tv) lands at ~60 Hz with the typical values) and is what this uses; 9.3.4's
Th row looks like it was copied from another part.

We run in **SYNC-DE mode**: DCLK, HSYNC, VSYNC and DE are all driven. Note
that the ST7262's pure *DE mode* requires HSYNC and VSYNC to be tied to **GND**,
not driven - do not switch modes without changing what those pins do.

Both syncs are **active low** and DE is **active high**, matching the ST7262
reset defaults (register 1Bh = D7h: VDPOL = HDPOL = 1, DEPOL = 0).

## Clocking

**The Prism board has no PL oscillator.** U18 is the only oscillator on the
board and it drives PS_CLK alone (`DFTBoard.kicad_pcb`: net `CLK33.33` ->
R100 -> U20.F7 / PS_CLK_500). The pixel clock therefore has to come from the
PS, so even a bring-up bitstream needs a `processing_system7` instance -
a PL-only bitstream is not possible here. Feed `lcd_bringup_top.clk` from
FCLK_CLK0, or from an MMCM off FCLK_CLK0 for a more exact 33.264 MHz.

Data is registered on the rising edge of `clk` and DCLK is forwarded through an
ODDR, inverted by default, so DCLK's rising edge lands in the middle of the
data eye with ~20 ns of margin against the ST7262's 12 ns setup/hold.

`i_clk_invert` is a **runtime input**, not a parameter, because which edge the
panel latches on is genuinely uncertain: the ST7262's DCLKPOL bit (1Bh)
defaults to 1 (negative polarity) while the module datasheet says the panel
latches on the rising edge. DCLKPOL is also hardware-strappable on the module,
and with no SPI/I2C brought out there is no way to read it back. If the image
is unstable or shows column noise, flip this first.

## Power sequencing

The module datasheet gives no numbers for this at all. The ST7262 datasheet
(section 11) does, and `lcd_power_seq.v` implements them:

| | | min |
|---|---|---|
| T0 | system power stable -> GRB reset | 0 ms |
| T1 | GRB reset high -> DISP high | **10 ms** |
| T2 | display signal out -> backlight on | **250 ms** |
| off T0 | backlight off -> DISP low | **5 ms** |
| off T1 | DISP low -> internal discharge done | **100 ms** |

At 25 MHz a frame is 16.64 ms, so the defaults are `VDD_WAIT_CYCLES` = 250000
(10 ms), `DISP_FRAMES` = 16 (266 ms, clearing the 250 ms T2) and `OFF_FRAMES`
= 2 (33 ms, clearing the 5 ms). That 250 ms is not optional - it is what stops
a white flash on turn-on.

Note the off-sequence T1: after DISP drops, the IC needs **100 ms** to
discharge internally before VDD is removed. Nothing in the PL can enforce
that; it is a constraint on whoever cuts board power.

Absolute Maximum Ratings still apply: `Vin = -0.3 V .. VDD+0.3 V`, so never
drive a panel input before VDD is up. On this board that is satisfied
structurally, because panel VDD (J701.4) and the Zynq VCCO_13 powering every
signal driver are the same +3V3 net.

## Bring-up

`TEST_PATTERN=1` (the default) puts eight colour bars across the top three
quarters and a black-to-white ramp along the bottom. The bars make a swapped
R/G/B channel obvious; the ramp makes a reversed bit order within a channel
obvious. If those look right, the connector, traces, bank-13 I/O, power
sequence and timing are all good and anything left is a framebuffer problem.

Reading the failure modes, given the panel's defaults cannot be changed:

| symptom | likely cause |
|---|---|
| red and blue swapped | ST7262 `SBGR` (19h[4]) strapped to 1 - not a wiring fault |
| image mirrored left/right | `HDIR` (19h[5]) strap |
| image flipped top/bottom | `VDIR` (19h[6]) strap |
| unstable / column noise | wrong DCLK edge - flip `i_clk_invert` |
| ramp banded or reversed | a data bit swapped or stuck on the FPC |
| nothing at all, backlight on | DISP, or the 250 ms T2 being violated |

Set `TEST_PATTERN=0` to take pixels from `i_pixel`. The source must register
off `o_x` / `o_y` with **exactly one cycle** of latency so its data lands in the
same stage as `o_de`.
