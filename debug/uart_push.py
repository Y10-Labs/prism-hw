#!/usr/bin/env python3
"""
Copy a file to the board over its UART shell - no network, no SD card.

    ./uart_push.py --port /dev/ttyUSB0 build/debug/lcd_debug.bit.bin /home/root/lcd_debug.bit.bin
    ./uart_push.py --port /dev/ttyUSB0 lcd/sw/lcdctl.py /home/root/lcdctl.py

The board's busybox has neither base64 nor xz, but it has python3, so:
gzip + base64 here, `cat > tmp` on the board with echo off, decode with
python3 there, then compare sha256 of the result against the local file.
Exits non-zero on any mismatch.

~115200 baud moves about 11 KB/s of base64, i.e. ~8 KB/s of payload.
Do not run uart_mon.py at the same time: both would read the port.
"""

import argparse
import base64
import gzip
import hashlib
import os
import re
import sys
import time

try:
    import serial
except ImportError:
    sys.exit("pyserial missing:  pip install pyserial")

PROMPT = re.compile(rb"[#$] $")


def wait_prompt(ser, timeout):
    buf = b""
    end = time.time() + timeout
    while time.time() < end:
        buf += ser.read(4096)
        if PROMPT.search(buf):
            return buf
    raise TimeoutError("no prompt after %.0fs; last output:\n%s"
                       % (timeout, buf[-500:].decode(errors="replace")))


def run(ser, cmd, timeout=10):
    ser.reset_input_buffer()
    ser.write(cmd.encode() + b"\r")
    return wait_prompt(ser, timeout).decode(errors="replace")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", required=True)
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("src")
    ap.add_argument("dst")
    a = ap.parse_args()

    raw = open(a.src, "rb").read()
    sha = hashlib.sha256(raw).hexdigest()
    b64 = base64.b64encode(gzip.compress(raw, 9))
    lines = [b64[i:i + 76] for i in range(0, len(b64), 76)]
    print("%s: %d bytes -> %d gzip+base64 (%d lines), ~%.0f s" % (
        a.src, len(raw), len(b64), len(lines), len(b64) * 10 / a.baud))

    ser = serial.Serial(a.port, a.baud, timeout=0.1)
    ser.write(b"\r")
    wait_prompt(ser, 5)

    tmp = "/tmp/.uart_push.b64"
    run(ser, "mkdir -p %s" % os.path.dirname(a.dst) if os.path.dirname(a.dst) else "true")
    # Echo off, so the board does not stream every line back at us; cat reads
    # until ^D at the start of a line.
    ser.write(("stty -echo; cat > %s\r" % tmp).encode())
    time.sleep(0.5)
    ser.reset_input_buffer()

    t0 = time.time()
    for i, ln in enumerate(lines):
        ser.write(ln + b"\n")
        if i % 200 == 0:
            ser.flush()
            sys.stdout.write("\r  %3d%%" % (100 * i // len(lines)))
            sys.stdout.flush()
    ser.flush()
    ser.write(b"\x04")
    wait_prompt(ser, 30)
    print("\r  100%%  (%.1f s)" % (time.time() - t0))

    out = run(ser, "stty echo; python3 -c \"import base64,gzip;"
                   "open('%s','wb').write(gzip.decompress(base64.b64decode("
                   "open('%s','rb').read())))\" && rm -f %s && sha256sum %s"
                   % (a.dst, tmp, tmp, a.dst), timeout=60)
    if sha not in out:
        print(out)
        sys.exit("sha256 MISMATCH (expected %s)" % sha)
    print("ok  %s  sha256 %s" % (a.dst, sha[:16]))


if __name__ == "__main__":
    main()
