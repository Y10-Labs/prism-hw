# Debug harness

Tools for the camera-in-the-loop LCD bring-up.  These run on the **host that
has the UART cable and Vivado**, not on a dev laptop.

    pip install pyserial

## UART

The board's console is `/dev/ttyUSB0` at 115200 8N1, root autologin. Only
**one** process can use the port at a time: close any `screen`/`minicom`
session first (a root `sudo screen` needs `sudo kill`), and never run two of
these tools at once - `uart_mon` and `uart_cmd` both read the port and would
steal each other's bytes.

**Run a command** and print its output. The tool exits non-zero if the prompt
never returns, so it works in scripts; use `--no-wait` for commands that
never give the prompt back:

    ./uart_cmd.py --port /dev/ttyUSB0 'uname -a'
    ./uart_cmd.py --port /dev/ttyUSB0 --timeout 60 'cd /home/root; python3 lcdctl.py status'

**Copy a file to the board.** There's no network or SD card involved: the
file is gzip + base64 here, decoded by python3 on the board (busybox has
neither base64 nor xz), then sha256-checked. It moves about 8 KB/s of
payload:

    ./uart_push.py --port /dev/ttyUSB0 ../lcd/build/debug/lcd_debug.bit.bin /home/root/lcd_debug.bit.bin
    ./uart_push.py --port /dev/ttyUSB0 ../lcd/sw/lcdctl.py /home/root/lcdctl.py

Stage bitstreams in `/home/root`, **not** `/lib/firmware`: `fpgautil -b`
copies its argument into /lib/firmware and deletes that copy after loading,
so a file that was already there is lost. Load with `lcdctl.py load` (see
`lcd/README.md`), which also starts the pixel clock and checks the result.

**Log everything**, e.g. across a power cycle, with nothing else using the
port:

    ./uart_mon.py --port /dev/ttyUSB0 --log /tmp/prism-uart.log

**Measuring the port.** Test it with a round trip that proves the shell ran
the command (`echo MARK$((20+22))` must come back as `MARK42`). Don't measure
the byte rate with a raw `os.read` on a port you haven't configured: that
once reported a bogus 800 KB/s "flood" of repeated data.

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

`lcd/README.md` has the failure-mode table.  The `bars` pattern makes a
swapped channel obvious; `ramps` and `walk all` make a reversed or stuck bit
obvious; `grid` shows offsets, mirroring and a wrong DCLK edge (a coloured
border column).

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
