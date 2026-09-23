# Debug harness

Tools for the camera-in-the-loop LCD bring-up.  These run on the **host that
has the UART cable and Vivado**, not on a dev laptop.

    pip install pyserial

## UART

Start the logger once, leave it running for the whole session:

    ./uart_mon.py --port /dev/ttyUSB0 --log /tmp/prism-uart.log &

Then issue commands.  Only `uart_mon` reads the port, so the two coexist:

    ./uart_cmd.py --port /dev/ttyUSB0 'devmem 0x41200000 32 0x1'
    ./uart_cmd.py --port /dev/ttyUSB0 --timeout 60 'fpgautil -b /lib/firmware/prism.bit'

`uart_cmd` exits non-zero if the prompt never returns, so it composes in a
script.  Use `--no-wait` for commands that never give the prompt back.

## Camera

Capture to a file per iteration.  Naming them for the knob state under test is
what makes shots comparable across a session:

    capture.sh  ->  /tmp/prism-shots/<iso8601>-<knobs>.png

**Lock white balance, exposure and focus before the first shot.**  Auto-WB will
silently "correct" a red/blue channel swap, which is the single most diagnostic
thing the test pattern shows.  Auto-exposure re-normalises the black-to-white
ramp and hides banding.  Use >= 1/30 s so the exposure averages over several
60.1 Hz frames, and avoid heavy JPEG compression - it smears the ramp into
false bands.

## What to look at

`lcd/README.md` has the failure-mode table.  The `TEST_PATTERN=1` bars make a
swapped channel obvious; the ramp makes a reversed or stuck bit obvious.

First split, before anything subtle: **is the backlight on?**  `o_bl_en` drives
the MT3608 boost (U701).  Backlight on but no image, versus no backlight at
all, halves the search space immediately.

## Pin verification

    ./verify_lcd_pins.py                                    # offline, no tools needed
    vivado -mode batch -source check_banks.tcl -tclargs xc7z020clg484-2

`verify_lcd_pins.py` re-derives the pin map from `DFTBoard.kicad_pcb` and
checks it three ways: every pin lands on the net its port name implies, every
RGB bit reaches the right J701 pad in order, and the result agrees with the
independently-generated `Prism-RTL/XDC_files/zyncPCB.xdc`.  Exits non-zero, so
it works as a pre-synthesis gate.

Bank membership is the one thing it cannot check - that lives in the Xilinx
package database, not the KiCad file - so `check_banks.tcl` covers it.
