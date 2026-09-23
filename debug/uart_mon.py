#!/usr/bin/env python3
"""
Continuously log the board's UART to a file.

Run this once, in the background, for the whole debug session:

    ./uart_mon.py --port /dev/ttyUSB0 --log /tmp/prism-uart.log &

Everything the board says lands in the log with a timestamp, so a crash or a
kernel oops that happens between commands is still captured.  uart_cmd.py
writes to the same port; the two coexist because only this one reads.

Deliberately append-only and line-buffered: the log is meant to be tailed by
something else while this is running.
"""

import argparse
import datetime
import sys
import time

try:
    import serial
except ImportError:
    sys.exit("pyserial missing:  pip install pyserial")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", required=True, help="e.g. /dev/ttyUSB0")
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--log", required=True)
    args = ap.parse_args()

    # No read timeout juggling: block briefly, write whatever arrived.  The
    # board is idle most of the time and we care about latency, not throughput.
    ser = serial.Serial(args.port, args.baud, timeout=0.2)

    with open(args.log, "a", buffering=1) as log:
        stamp = datetime.datetime.now().isoformat(timespec="seconds")
        log.write(f"\n===== uart_mon attached {stamp} @ {args.baud} =====\n")

        partial = ""
        while True:
            try:
                chunk = ser.read(4096)
            except serial.SerialException as e:
                log.write(f"[uart_mon] port lost: {e}\n")
                time.sleep(1)
                continue

            if not chunk:
                continue

            # Decode leniently.  Garbage bytes are themselves a symptom (wrong
            # baud, floating TX), so never drop them - make them visible.
            partial += chunk.decode("utf-8", errors="replace")
            *lines, partial = partial.split("\n")
            now = datetime.datetime.now().strftime("%H:%M:%S.%f")[:-3]
            for line in lines:
                log.write(f"[{now}] {line.rstrip()}\n")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
