#!/usr/bin/env python3
"""
Check prism_lcd_pins.xdc against the PCB netlist, straight from the KiCad file.

    ./verify_lcd_pins.py

Exits non-zero on any disagreement, so it works as a pre-synthesis gate.  The
XDC's header says its pins were "extracted directly from DFTBoard.kicad_pcb";
this re-derives them and proves it, rather than trusting the comment.

Three things are checked:
  1. every XDC pin lands on the net its port name implies
  2. every RGB bit reaches the right J701 pad, in order (catches bit swaps)
  3. the LCD XDC agrees with the whole-board map in Prism-RTL/XDC_files

What this CANNOT check offline is bank membership - that each pin really is in
bank 13.  That needs the Xilinx package database; see check_banks.tcl.
"""

import json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
PCB      = os.path.join(ROOT, "Prism-PCB", "DFTBoard.kicad_pcb")
LCD_XDC  = os.path.join(ROOT, "prism-hw", "lcd", "xdc", "prism_lcd_pins.xdc")
BOARD_XDC= os.path.join(ROOT, "Prism-RTL", "XDC_files", "zyncPCB.xdc")

FPGA, CONN = "U20", "J701"


def sexpr_blocks(text, tag):
    """Yield each balanced (tag ...) block.  Parens nest, so regex won't do."""
    out, i, needle = [], 0, "(" + tag
    while True:
        i = text.find(needle, i)
        if i < 0:
            return out
        if text[i + len(needle)] not in " \t\n(":
            i += 1
            continue
        depth, j, instr = 0, i, False
        while j < len(text):
            c = text[j]
            if instr:
                if c == "\\":
                    j += 2
                    continue
                if c == '"':
                    instr = False
            elif c == '"':
                instr = True
            elif c == "(":
                depth += 1
            elif c == ")":
                depth -= 1
                if depth == 0:
                    out.append(text[i:j + 1])
                    break
            j += 1
        i = j + 1


def pad_nets(pcb_text, refs):
    ref_re = re.compile(r'\(property\s+"Reference"\s+"([^"]+)"')
    result = {}
    for fp in sexpr_blocks(pcb_text, "footprint"):
        m = ref_re.search(fp)
        if not m or m.group(1) not in refs:
            continue
        pads = {}
        for pad in sexpr_blocks(fp, "pad"):
            pm = re.match(r'\(pad\s+"([^"]*)"', pad)
            nm = re.search(r'\(net\s+\d+\s+"([^"]*)"\)', pad)
            if pm and nm:
                pads[pm.group(1)] = nm.group(1)
        result[m.group(1)] = pads
    return result


def parse_xdc(path):
    """package pin -> port name, skipping commented-out lines."""
    d = {}
    for line in open(path):
        if line.lstrip().startswith("#"):
            continue
        # Two forms: [get_ports {o_red[0]}] and [get_ports o_clk].  The braced
        # form must keep its bus index, so it cannot be matched with a class
        # that excludes "]" - that silently truncates o_red[0] to "o_red[0".
        m = re.search(r"PACKAGE_PIN\s+(\S+).*?\[get_ports\s+"
                      r"(?:\{([^\}]+)\}|([^\s\]]+))\s*\]", line)
        if m:
            d[m.group(1)] = (m.group(2) or m.group(3)).strip()
    return d


def main():
    for p in (PCB, LCD_XDC, BOARD_XDC):
        if not os.path.exists(p):
            sys.exit(f"missing: {p}")

    nets = pad_nets(open(PCB, encoding="utf-8", errors="replace").read(), {FPGA, CONN})
    u20, conn = nets[FPGA], nets[CONN]
    net2pad = {v: k for k, v in conn.items() if v and not v.startswith("unconnected")}

    lcd, board = parse_xdc(LCD_XDC), parse_xdc(BOARD_XDC)
    pin2port = {v: k for k, v in lcd.items()}
    fails = []

    # 1 + 2: RGB buses must be in order and land on consecutive J701 pads.
    for colour, first_pad, prefix in (("red", 5, "LCDRED"),
                                      ("green", 13, "LCDGREEN"),
                                      ("blue", 21, "LCDBLUE")):
        for i in range(8):
            port = f"o_{colour}[{i}]"
            pin = pin2port.get(port)
            net = u20.get(pin)
            want_net, want_pad = f"{prefix}{i}", str(first_pad + i)
            got_pad = net2pad.get(net, "-")
            if net != want_net or got_pad != want_pad:
                fails.append(f"{port}: pin={pin} net={net} {CONN}.{got_pad} "
                             f"(want {want_net} on {CONN}.{want_pad})")

    for port, want_net, want_pad in (
            ("o_clk",   "/Peripherals/LCDDCLK",   "30"),
            ("o_disp",  "/Peripherals/LCDDDISP",  "31"),
            ("o_hsync", "/Peripherals/LCDDHSYNC", "32"),
            ("o_vsync", "/Peripherals/LCDDVSYNC", "33"),
            ("o_de",    "/Peripherals/LCDDDEN",   "34")):
        pin = pin2port.get(port)
        net = u20.get(pin)
        got = net2pad.get(net, "-")
        if net != want_net or got != want_pad:
            fails.append(f"{port}: pin={pin} net={net} {CONN}.{got} "
                         f"(want {want_net} on {CONN}.{want_pad})")

    pin = pin2port.get("o_bl_en")
    if u20.get(pin) != "/Peripherals/BOOSTENABLE":
        fails.append(f"o_bl_en: pin={pin} net={u20.get(pin)}")

    # A pin used twice is silently fatal in Vivado's placer messages.
    seen = {}
    for pin, port in lcd.items():
        seen.setdefault(pin, []).append(port)
    for pin, ports in seen.items():
        if len(ports) > 1:
            fails.append(f"package pin {pin} assigned to {ports}")

    # 3: agreement with the independently-generated whole-board map.
    for pin, port in lcd.items():
        net = u20.get(pin)
        if pin not in board:
            continue                      # board map may legitimately omit it
        mangled = re.sub(r"[^A-Za-z0-9]", "_", (net or "").lstrip("/"))
        if board[pin].replace("pin_", "") != mangled:
            fails.append(f"{pin}: lcd xdc says {port}, zyncPCB.xdc says {board[pin]}")

    print(f"checked {len(lcd)} pins against {os.path.basename(PCB)}")
    if fails:
        print(f"\n{len(fails)} PROBLEM(S):")
        for f in fails:
            print("  -", f)
        return 1
    print("all pins agree: nets, J701 pad order, and the whole-board map")
    return 0


if __name__ == "__main__":
    sys.exit(main())
