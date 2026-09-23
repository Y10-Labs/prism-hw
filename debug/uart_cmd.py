#!/usr/bin/env python3
"""
Send one command to the board's UART shell and print what comes back.

    ./uart_cmd.py --port /dev/ttyUSB0 'devmem 0x41200000 32 0x1'
    ./uart_cmd.py --port /dev/ttyUSB0 --timeout 30 'fpgautil -b /lib/firmware/prism.bit'

Exits non-zero if the prompt never came back, so this composes in a script.

This is a one-shot tool on purpose.  Each invocation opens the port, does one
thing and closes it, which means a hung command can never wedge the session -
the worst case is one non-zero exit.  Run uart_mon.py alongside it to keep the
continuous log; only uart_mon reads, so the two do not fight over bytes.
"""

import argparse
import re
import sys
import time

try:
    import serial
except ImportError:
    sys.exit("pyserial missing:  pip install pyserial")

# Matches a shell prompt at end of output: "# ", "$ ", "root@prism:~# ".
PROMPT = re.compile(rb"[\r\n][^\r\n]*[#$]\s*$")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", required=True)
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--timeout", type=float, default=10.0,
                    help="seconds to wait for the prompt to return")
    ap.add_argument("--no-wait", action="store_true",
                    help="fire and forget; for commands that never return a prompt")
    ap.add_argument("cmd")
    args = ap.parse_args()

    ser = serial.Serial(args.port, args.baud, timeout=0.1)

    # Nudge the shell and drain anything stale, so the output we collect below
    # belongs to our command and not to whatever scrolled past earlier.
    ser.write(b"\r")
    time.sleep(0.3)
    ser.reset_input_buffer()

    ser.write(args.cmd.encode() + b"\r")

    if args.no_wait:
        return 0

    buf = b""
    deadline = time.time() + args.timeout
    while time.time() < deadline:
        buf += ser.read(4096)
        if PROMPT.search(buf):
            break
    else:
        sys.stdout.write(buf.decode("utf-8", errors="replace"))
        print(f"\n[uart_cmd] TIMEOUT after {args.timeout}s - no prompt",
              file=sys.stderr)
        return 1

    text = buf.decode("utf-8", errors="replace")
    # Drop the echoed command line; keep everything else verbatim.
    lines = text.splitlines()
    if lines and args.cmd in lines[0]:
        lines = lines[1:]
    sys.stdout.write("\n".join(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main())
