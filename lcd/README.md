# Prism LCD controller

Drives a **ChengHao CH500WV05A-T** (Adafruit 1596) 5.0" 800x480 24-bit parallel
RGB panel from the Zynq PL. The panel has no controller and no RAM: it must be
refreshed continuously.

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

Results (Vivado 2021.2, `lcd_bringup_top`, 33.264 MHz):

| part | board | WNS | WHS | LUT | FF |
|---|---|---|---|---|---|
| xc7z020clg484-2 | Prism | +4.704 ns | +0.193 ns | 186 | 79 |
| xc7z020clg400-1 | PYNQ-Z2 | +0.620 ns | +0.215 ns | 186 | 79 |

The clg484 run uses the real pin constraints. The clg400 run has none (no
verified PYNQ header pinout yet), so its I/O placement is arbitrary and the
number is indicative only.

## Default video mode

1056 x 525 @ 33.264 MHz = **60.0 Hz**.

| | active | front | sync | back | total |
|---|---|---|---|---|---|
| H | 800 | 40 | 48 | 168 | 1056 |
| V | 480 | 13 | 3 | 29 | 525 |

Both syncs are **active low**, as the datasheet requires. Vertical blank is
47,520 DCLKs, comfortably past the >= 2048 the panel needs to detect
end-of-frame in DE-only mode; the inter-line DE-low gap is 256 DCLKs, safely
under it so the panel will not false-trigger.

## Clocking

**The Prism board has no PL oscillator.** U18 is the only oscillator on the
board and it drives PS_CLK alone (`DFTBoard.kicad_pcb`: net `CLK33.33` ->
R100 -> U20.F7 / PS_CLK_500). The pixel clock therefore has to come from the
PS, so even a bring-up bitstream needs a `processing_system7` instance -
a PL-only bitstream is not possible here. Feed `lcd_bringup_top.clk` from
FCLK_CLK0, or from an MMCM off FCLK_CLK0 for a more exact 33.264 MHz.

Data is registered on the rising edge of `clk` and DCLK is forwarded **inverted**
through an ODDR, so DCLK's rising edge - the edge this panel latches on - lands
in the middle of the data eye with about 15 ns of margin either side.

## What the datasheet does not say

Two gaps worth knowing about, because they are not oversights in this code:

- **Power sequencing.** Section 7.2 documents only the panel's *internal* rail
  order (VDD -> VEE -> VGH) and names six intervals without giving a numeric
  value for any of them. It says nothing about the ordering of DISP / DCLK /
  DE / backlight. The sequence in `lcd_power_seq.v` is the standard convention
  for DE-mode RGB TFTs, not a datasheet figure - tune the delays on hardware.
- **Setup/hold.** `tdsu` and `tdhd` appear as labels on the timing diagram with
  no values anywhere. `xdc/prism_lcd_timing.xdc` assumes a conservative
  8 ns / 8 ns.

The one hard rule that *is* in the datasheet is Absolute Maximum Ratings,
`Vin = -0.3 V .. VDD+0.3 V`: never drive a panel input before VDD is up. On
this board that is satisfied structurally, because panel VDD (J701.4) and the
Zynq VCCO_13 powering every signal driver are the same +3V3 net.

## Bring-up

`TEST_PATTERN=1` (the default) puts eight colour bars across the top three
quarters and a black-to-white ramp along the bottom. The bars make a swapped
R/G/B channel obvious; the ramp makes a reversed bit order within a channel
obvious. If those look right, the connector, traces, bank-13 I/O, power
sequence and timing are all good and anything left is a framebuffer problem.

Set `TEST_PATTERN=0` to take pixels from `i_pixel`. The source must register
off `o_x` / `o_y` with **exactly one cycle** of latency so its data lands in the
same stage as `o_de`.
