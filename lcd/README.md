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

## Board quickstart

These steps take a freshly powered Prism board to the panel running. The
host tools are in `debug/` (see `debug/README.md`); `lcdctl.py` runs on the
board.

**What you need to know first:**
- The console is `/dev/ttyUSB0`, 115200 8N1, root autologin. Only one process
  can hold the port: close `screen`/`minicom` first. Host tools need
  `pip install pyserial`.
- **After every power-up the PL is empty.** Any access to
  0x4000_0000-0xBFFF_FFFF before a bitstream is loaded hangs the board.
  `lcdctl.py` checks this for you; raw `devmem` does not.
- **Power-cycle; never `reboot`.** A software reboot on this board stops at
  "Restarting system" and doesn't come back.
- **Leave the SLCR unlocked.** Linux runs with it unlocked. If you poke SLCR
  registers by hand, don't write the lock key (0x767B to 0xF8000004):
  the FPGA manager's level-shifter enable then fails silently, and the PL
  stays unreachable.

**One time: reserve DDR for the frame buffers.** This is only needed for
`fb` / `video` / `flip` / `anim`; test patterns work without it. On the board:

```sh
echo "bootargs=console=ttyPS0,115200 earlycon root=/dev/mmcblk0p2 ro rootwait mem=448M" \
    > /run/media/BOOT-mmcblk0p1/uEnv.txt && sync
# power-cycle, then check:
grep "System RAM" /proc/iomem          # 00000000-1bffffff
```

Delete that `uEnv.txt` to undo. Details are in "Images from DDR" below.

**Each session, on the host:**

```sh
make -C lcd                                           # all testbenches
vivado -mode batch -source lcd/syn/build_debug.tcl    # -> lcd/build/debug/lcd_debug.bit.bin
./lcd/sw/make_anim.py lcd/build/anim/loop32.anim      # optional: the 60 fps demo
debug/uart_push.py --port /dev/ttyUSB0 lcd/build/debug/lcd_debug.bit.bin /home/root/lcd_debug.bit.bin
debug/uart_push.py --port /dev/ttyUSB0 lcd/sw/lcdctl.py /home/root/lcdctl.py
debug/uart_push.py --port /dev/ttyUSB0 lcd/build/anim/loop32.anim /home/root/loop32.anim
```

Rebuild or re-push only what changed: the files stay in `/home/root` across
power cycles.

**Each power-up, on the board** (`cd /home/root`):

```sh
python3 lcdctl.py load                 # FCLK1 = 25 MHz, fpgautil, checks ID "LCD1"
python3 lcdctl.py on                   # power sequence -> colour bars, backlight on
python3 lcdctl.py status               # 25.000 MHz, RUN, ~60 fps, limits OK
python3 lcdctl.py pattern grid         # white border exactly on the panel edge

python3 lcdctl.py anim load loop32.anim && python3 lcdctl.py anim play
python3 lcdctl.py anim check           # expect 60.00 stores/s = panel fps, 0 skips
```

Then see "Debugging from PetaLinux" and "Images from DDR" below for every
knob.

## Files

```
rtl/lcd_defaults.vh    the default mode + power sequence, in one place
rtl/lcd_timing.v       H/V counters, DE, HSYNC/VSYNC, frame_start (runtime mode)
rtl/lcd_power_seq.v    power-up / power-down ordering (DISP, backlight, blank)
rtl/lcd_clock_out.v    DCLK forwarding through an ODDR
rtl/lcd_controller.v   timing + sequencer + test patterns + pin override
rtl/lcd_regs_axil.v    AXI4-Lite registers, CDC into the pixel domain
rtl/lcd_debug_top.v    debug bitstream: PS7 + VDMA + registers + controller
rtl/lcd_stream_src.v   AXI4-Stream video (VDMA MM2S) -> i_pixel, frame-aligned on SOF
rtl/lcd_async_fifo.v   dual-clock first-word-fall-through FIFO (AXI -> pixel clock)
rtl/lcd_bringup_top.v  fixed-mode wrapper, defaults only (synth checks)
tb/                    self-checking testbenches
xdc/                   Prism board pin + timing constraints
syn/build_debug.tcl    Vivado batch build of the debug bitstream
syn/ps7_prism_config.tcl  the board's PS7 config (generated from the XSA)
syn/synth_lcd.tcl      batch synth/impl of lcd_bringup_top for any part
sw/lcdctl.py           runs on the board: drive every knob from the shell
sw/make_test_images.py host: the two 800x480 XRGB test frames for the DDR path
sw/make_anim.py        host: N-frame animation as background + per-frame patches
```

## Test

```sh
make -C lcd            # both testbenches, asserts only, no waveform needed
```

`lcd_timing_tb` runs the default 832x500 mode, the ST7262 typical 816x496
mode, and 832x500 with active-high syncs.  In each it checks active pixels per
line, lines per frame, frame period, sync widths and periods, and both DE-gap
constraints.  `lcd_controller_tb` checks the power sequence ordering and the
exact frame counts, up and down, plus the bit-walk pattern and the pin
override.  `lcd_regs_tb` checks the AXI4-Lite registers, byte strobes, the
config crossing into the pixel domain, the frame counter and the pixel clock
meter.

## Synthesise

```sh
vivado -mode batch -source lcd/syn/synth_lcd.tcl -tclargs xc7z020clg484-2
vivado -mode batch -source lcd/syn/synth_lcd.tcl -tclargs xc7z020clg400-1
```

The debug bitstream (what actually goes on the board):

```sh
vivado -mode batch -source lcd/syn/build_debug.tcl    # -> lcd/build/debug/lcd_debug.bit.bin
```

It prints `RESULT` lines (WNS/WHS, output flops not in IOBs) and writes its
reports next to the bitstream. `syn/ps7_prism_config.tcl` is generated from
the reference XSA by `syn/gen_ps7_config.py`. Regenerate it if the board's
FSBL/PetaLinux hardware changes: the PS7 in a runtime-loaded bitstream must
match what the FSBL configured.

The older standalone flow, for `lcd_bringup_top` on any part:

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
board and it drives PS_CLK alone (`DFTBoard.kicad_pcb`: R100 -> U20.F7 /
PS_CLK_500). The net there is called `CLK33.33`, but the part is **50 MHz**. The
reference XSA (`prism_lcctrl.xsa`) says `PCW_CRYSTAL_PERIPHERAL_FREQMHZ = 50`,
and the running board agrees: its PLL registers read back ARM x27 = 1350,
DDR x21 = 1050 and IO x36 = 1800 MHz, and the console works at 115200. Trust
the 50, not the net name.

So every PL clock comes from the PS. The debug bitstream uses
**FCLK0 = 50 MHz** for AXI and **FCLK1** as the pixel clock, with no MMCM.
Linux sets FCLK1's rate at runtime by rewriting `FPGA1_CLK_CTRL`
(0xF8000180). IO PLL / 72 gives exactly 25.000 MHz, and the IO and DDR PLLs
together reach 23-27 MHz in 0.25-0.6 MHz steps (`lcdctl.py pclk list`).

At boot Linux **gates FCLK1 off** ("clk: Disabling unused clocks" sets
`FPGA1_THR_CTRL` bit 0). `lcdctl.py pclk` / `load` clear that bit.

Data is registered on the rising edge of `clk`, and every output flop is
packed into its IOB. DCLK is forwarded through an ODDR, **not inverted**, so
DCLK's **falling** edge lands in the middle of the data eye with ~20 ns of
margin against the ST7262's 12 ns setup/hold.

**Measured on the board (2026-09-24): the panel latches on the falling edge.**
That is the ST7262's DCLKPOL reset default (1 = negative); the module
datasheet's "rising edge" is wrong. With the clock inverted, the grid pattern's
right border column came out red: R was sampled from the current pixel, G and
B from the previous one, because the falling edge sat on the data transitions
and channel skew decided each bit.

`CTRL.clk_invert` is a **runtime** bit because which edge the panel latches on
is genuinely uncertain. The ST7262's DCLKPOL bit (1Bh) defaults to 1 (negative
polarity), while the module datasheet says the panel latches on the rising
edge. DCLKPOL is also hardware-strappable on the module, and with no SPI/I2C
brought out there is no way to read it back. The bit picks which DCLK edge is
centred in the data eye; the other edge then sits on the data transitions.
The default is 0 (falling edge centred), which is correct for this panel; keep
the bit for a replacement panel that might be strapped the other way.

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

At 25 MHz a frame is 16.64 ms, so the defaults (`rtl/lcd_defaults.vh`) are
VDD wait = 250000 clocks (10 ms), disp frames = 16 (266 ms, clearing the
250 ms T2) and off frames = 2 (33 ms, clearing the 5 ms). All of them are
runtime registers (`lcdctl.py set vdd_wait=... disp_frames=...`). That 250 ms is not optional - it is what stops
a white flash on turn-on.

Note the off-sequence T1: after DISP drops, the IC needs **100 ms** to
discharge internally before VDD is removed. Nothing in the PL can enforce
that; it is a constraint on whoever cuts board power.

Absolute Maximum Ratings still apply: `Vin = -0.3 V .. VDD+0.3 V`, so never
drive a panel input before VDD is up. On this board that is satisfied
structurally, because panel VDD (J701.4) and the Zynq VCCO_13 powering every
signal driver are the same +3V3 net.

## Bring-up

Pattern `bars` (the default) puts eight colour bars across the top three
quarters and a black-to-white ramp along the bottom. The bars make a swapped
R/G/B channel obvious; the ramp makes a reversed bit order within a channel
obvious. If those look right, the connector, traces, bank-13 I/O, power
sequence and timing are all good and anything left is a framebuffer problem.

Reading the failure modes, given the panel's defaults cannot be changed:

| symptom | likely cause | lcdctl |
|---|---|---|
| red and blue swapped | ST7262 `SBGR` (19h[4]) strapped to 1 - not a wiring fault | |
| image mirrored left/right | `HDIR` (19h[5]) strap | `pattern grid` |
| image flipped top/bottom | `VDIR` (19h[6]) strap | `pattern grid` |
| unstable / column noise, wrong colour on a border column | wrong DCLK edge | `set invert=1` (default 0 is right for this panel) |
| ramp banded or reversed | a data bit swapped or stuck on the FPC | `walk all` |
| nothing at all, backlight on | DISP, or the 250 ms T2 being violated | `set disp_frames=40` |
| image shifted / cropped | porches | `sweep h_bp ...` |
| no backlight | BL_EN / MT3608 | `pin set bl=1` |

Pattern `ext` takes pixels from `i_pixel`, which is sampled **in the same
cycle** as `o_x` / `o_y` / `o_active` (zero latency): it must be the pixel
for the coordinates currently presented. `lcd_stream_src` meets this with a
first-word-fall-through FIFO popped on `o_active`.

## Debugging from PetaLinux

From the host, with the UART on `/dev/ttyUSB0` and nothing else holding it:

```sh
vivado -mode batch -source lcd/syn/build_debug.tcl
debug/uart_push.py --port /dev/ttyUSB0 lcd/build/debug/lcd_debug.bit.bin /home/root/lcd_debug.bit.bin
debug/uart_push.py --port /dev/ttyUSB0 lcd/sw/lcdctl.py /home/root/lcdctl.py
```

On the board:

```sh
python3 lcdctl.py load                 # FCLK1 = 25 MHz, ungate, fpgautil, check ID
                                       # (keep the .bin out of /lib/firmware: fpgautil
                                       #  deletes its own copy there after loading)
python3 lcdctl.py on                   # power sequence up, colour bars
python3 lcdctl.py status
python3 lcdctl.py set invert=1         # other DCLK edge, for a differently strapped panel
python3 lcdctl.py pattern grid
python3 lcdctl.py mode typ             # ST7262 typical 816 x 496
python3 lcdctl.py pclk 24.0            # nearest reachable, then measured
python3 lcdctl.py sweep h_bp 2 40 2 --dwell 3
python3 lcdctl.py sweep pclk 23 27 0.5 --dwell 3
python3 lcdctl.py walk all --dwell 2   # one data bit per step
python3 lcdctl.py pin walk --dwell 8   # one PIN at a time at 3.3 V, for a meter
python3 lcdctl.py pin off
```

**Never** read or write 0x4000_0000-0xBFFF_FFFF (e.g. with `devmem`) while no
bitstream is loaded: the AXI bus hangs and the board needs a power cycle.
`lcdctl.py` refuses unless the FPGA manager reports `operating`, the level
shifters are on, the PL reset is released, FCLK0 is running and the ID
register reads `LCD1`.

Registers, at 0x43C0_0000 (every config write is applied at once):

| off | name | bits |
|---|---|---|
| 0x00 | ID | RO `0x4C434431` "LCD1" |
| 0x04 | BUILD | RO build time, seconds since the epoch |
| 0x08 | CTRL | [0] enable [1] clk_invert [2] hs_active_low [3] vs_active_low [4] de_active_low [5] de_only [8] pix_soft_rst [9] pin_override |
| 0x10 | H_ACT_FP | [11:0] h_active, [27:16] h_front |
| 0x14 | H_SYNC_BP | [11:0] h_sync, [27:16] h_back |
| 0x18 | V_ACT_FP | [11:0] v_active, [27:16] v_front |
| 0x1C | V_SYNC_BP | [11:0] v_sync, [27:16] v_back |
| 0x20 | PATTERN | [3:0] 0 bars, 1 solid, 2 walk, 3 ramps, 4 grid, 5 checker, 6 ext; [15:8] arg (walk bit) |
| 0x24 | SOLID | [23:0] RGB |
| 0x28 | SEQ_VDD | [23:0] clocks from enable to timing start |
| 0x2C | SEQ_FRAMES | [7:0] blank, [15:8] disp, [23:16] off |
| 0x30 | PIN_VALUE | [29:0] {bl, disp, de, vs, hs, dclk, R, G, B} |
| 0x40 | STATUS | RO [2:0] seq state, [3] ready, [4] applied, [5] pixel clock alive, [6] disp, [7] bl_en |
| 0x44 | FRAME_CNT | RO |
| 0x48 | PCLK_HZ | RO measured pixel clock (100 ms gate) |
| 0x4C | SCRATCH | RW, no effect |

CTRL[10] `src_clear` clears the sticky stream flags; STATUS[9:8] is the
stream source state (0 SEEK, 1 READY, 2 RUN), [10] underflow seen, [11]
misalign seen.

## Images from DDR (AXI VDMA)

```
DDR 0x1C000000 + n*1.5MiB (32 stores) -> S_AXI_HP0 -> AXI VDMA MM2S (0x4300_0000)
  -> AXI4-Stream (FCLK0) -> lcd_async_fifo -> lcd_stream_src -> pattern `ext`
```

**Frame buffers.** The top 64 MB of DDR (0x1C000000-0x1FFFFFFF) is hidden
from Linux by adding `mem=448M` to the kernel command line through
`/run/media/BOOT-mmcblk0p1/uEnv.txt` (PetaLinux's boot.scr imports it):

```
bootargs=console=ttyPS0,115200 earlycon root=/dev/mmcblk0p2 ro rootwait mem=448M
```

Check with `grep "System RAM" /proc/iomem` -> `00000000-1bffffff`. Delete
uEnv.txt to undo. **Power-cycle, don't `reboot`:** a software reboot on this
board stops after "Restarting system" and never comes back. The kernel's own 16 MB CMA pool has no userspace path on
this image (no dma-heap / udmabuf, no kernel headers), hence the reservation.
Frames are XRGB8888, little-endian `0x00RRGGBB`, stride 3200 B, 1,536,000 B
each, one frame store every 1.5 MiB: 32 stores, the VDMA's maximum. Stores
16-31 are programmed through `MM2S_REG_INDEX` (0x14): only 16 start-address
registers exist, banked (PG020). `/dev/mem` maps the reserved region uncached, so the VDMA
(which is not cache-coherent on HP0) always reads what the CPU wrote.

**Alignment.** The VDMA free-runs (no fsync); `lcd_stream_src` locks every
panel frame to the stream's SOF (`tuser`), dropping data until one arrives,
so frames are always whole: switching the park pointer never tears.

```sh
./sw/make_test_images.py build/frames          # on the host: frame0/1 .png + .raw
python3 lcdctl.py fb load 0 frame0.raw         # on the board
python3 lcdctl.py fb load 1 frame1.raw
python3 lcdctl.py video start                  # VDMA on, pattern ext
python3 lcdctl.py flip --fps 5                 # alternate 0/1 (nohup ... & to detach)
python3 lcdctl.py video status                 # VDMA SR + stream underflow/misalign
python3 lcdctl.py video stop
```

**60 fps animation.** In circular mode the VDMA moves to the next frame store
at every frame boundary, and because the panel back-pressures the stream that
is exactly one store per panel refresh - no software timing involved.
`make_anim.py` renders a seamless 32-frame loop (orbiting ball, spoke, frame
counter) and stores it as one background plus each frame's changed
rectangles (84 KB gzipped instead of 48 MB); `anim load` rebuilds the frames
in DDR on the board.

```sh
./sw/make_anim.py build/anim/loop32.anim --frames 32 --png-dir build/anim   # host
python3 lcdctl.py anim load loop32.anim     # board: 32 frames built in ~0.7 s
python3 lcdctl.py anim play                 # circular over stores 0..31
python3 lcdctl.py anim check                # measured: 60.00 stores/s = 60.00 panel fps,
                                            # 0 skipped/repeated, no underflow
```
