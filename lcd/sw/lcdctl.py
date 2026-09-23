#!/usr/bin/env python3
"""
lcdctl - poke the Prism LCD debug bitstream from the PetaLinux shell.

Runs ON THE BOARD (python3, root, /dev/mem).  Talks to lcd_regs_axil at
0x43C0_0000 and to the PS SLCR for the pixel clock (FCLK1).

    lcdctl.py load [lcd_debug.bit.bin]               # ungate clocks, fpgautil, verify
    lcdctl.py status                                 # everything, decoded
    lcdctl.py on | off                               # power sequence up / down
    lcdctl.py set h_fp=16 v_bp=6 invert=1            # any register field(s)
    lcdctl.py mode default | typ | 800,16,4,12,480,10,4,6
    lcdctl.py pattern bars|solid|walk|ramps|grid|checker|ext|black [arg]
    lcdctl.py solid FF8000
    lcdctl.py walk [BIT | all] [--dwell S]            # one data line at a time
    lcdctl.py pclk 25                                 # MHz, nearest reachable
    lcdctl.py pclk list                               # every rate in 23..27 MHz
    lcdctl.py sweep h_fp 4 48 4 [--dwell S]           # any field, or pclk
    lcdctl.py pin on | off | set r0=1 de=0 ... | walk [--dwell S]
    lcdctl.py limits                                  # check mode vs ST7262 7.3.4
    lcdctl.py reset                                   # pulse the pixel soft reset
    lcdctl.py dump                                    # raw registers

SAFETY: with no bitstream in the PL, any access to 0x4000_0000..0xBFFF_FFFF
hangs the AXI bus and the board needs a power cycle.  Every PL access here is
gated on the FPGA manager reporting "operating", the level shifters being on,
the PL reset released and FCLK0 (the AXI clock) running.  SLCR (PS-side)
accesses are always safe.
"""

import ctypes
import mmap
import os
import subprocess
import sys
import time

# ---------------------------------------------------------------------------
# hardware constants
# ---------------------------------------------------------------------------
LCD_BASE  = 0x43C00000
SLCR_BASE = 0xF8000000
PS_CLK_HZ = 50_000_000          # Prism board crystal (U18), per the XSA/FSBL

SLCR_LOCK        = 0x004
SLCR_UNLOCK      = 0x008
SLCR_LOCKSTA     = 0x00C
ARM_PLL_CTRL     = 0x100
DDR_PLL_CTRL     = 0x104
IO_PLL_CTRL      = 0x108
FPGA0_CLK_CTRL   = 0x170
FPGA0_THR_CTRL   = 0x178
FPGA1_CLK_CTRL   = 0x180
FPGA1_THR_CTRL   = 0x188
FPGA_RST_CTRL    = 0x240
LVL_SHFTR_EN     = 0x900

# lcd_regs_axil register offsets
R_ID, R_BUILD, R_CTRL = 0x00, 0x04, 0x08
R_H_ACT_FP, R_H_SYNC_BP, R_V_ACT_FP, R_V_SYNC_BP = 0x10, 0x14, 0x18, 0x1C
R_PATTERN, R_SOLID, R_SEQ_VDD, R_SEQ_FRAMES = 0x20, 0x24, 0x28, 0x2C
R_PIN_VALUE = 0x30
R_STATUS, R_FRAME_CNT, R_PCLK_HZ, R_SCRATCH = 0x40, 0x44, 0x48, 0x4C
LCD_ID = 0x4C434431

# field name -> (register, lsb, width)
FIELDS = {
    "enable":       (R_CTRL, 0, 1),
    "invert":       (R_CTRL, 1, 1),
    "hs_low":       (R_CTRL, 2, 1),
    "vs_low":       (R_CTRL, 3, 1),
    "de_low":       (R_CTRL, 4, 1),
    "de_only":      (R_CTRL, 5, 1),
    "soft_rst":     (R_CTRL, 8, 1),
    "override":     (R_CTRL, 9, 1),
    "h_active":     (R_H_ACT_FP, 0, 12),
    "h_fp":         (R_H_ACT_FP, 16, 12),
    "h_sync":       (R_H_SYNC_BP, 0, 12),
    "h_bp":         (R_H_SYNC_BP, 16, 12),
    "v_active":     (R_V_ACT_FP, 0, 12),
    "v_fp":         (R_V_ACT_FP, 16, 12),
    "v_sync":       (R_V_SYNC_BP, 0, 12),
    "v_bp":         (R_V_SYNC_BP, 16, 12),
    "pattern":      (R_PATTERN, 0, 4),
    "arg":          (R_PATTERN, 8, 8),
    "solid":        (R_SOLID, 0, 24),
    "vdd_wait":     (R_SEQ_VDD, 0, 24),
    "blank_frames": (R_SEQ_FRAMES, 0, 8),
    "disp_frames":  (R_SEQ_FRAMES, 8, 8),
    "off_frames":   (R_SEQ_FRAMES, 16, 8),
    "pins":         (R_PIN_VALUE, 0, 30),
}

PATTERNS = {"bars": 0, "solid": 1, "walk": 2, "ramps": 3, "grid": 4,
            "checker": 5, "ext": 6, "black": 15}

SEQ_STATES = ["OFF", "VDD_WAIT", "BLANK", "DISP_WAIT", "RUN", "BL_OFF",
              "DISP_OFF", "?7"]

# PIN_VALUE bit positions: {bl, disp, de, vs, hs, dclk, R[7:0], G[7:0], B[7:0]}
PINS = {"bl": 29, "disp": 28, "de": 27, "vs": 26, "hs": 25, "dclk": 24}
for _i in range(8):
    PINS["r%d" % _i] = 16 + _i
    PINS["g%d" % _i] = 8 + _i
    PINS["b%d" % _i] = _i
# FPC pin for each, for the meter (J701); bl_en is the MT3608 EN, not on J701
FPC = {"dclk": 30, "disp": 31, "hs": 32, "vs": 33, "de": 34, "bl": None}
for _i in range(8):
    FPC["r%d" % _i] = 5 + _i
    FPC["g%d" % _i] = 13 + _i
    FPC["b%d" % _i] = 21 + _i

MODES = {
    # h_active, h_fp, h_sync, h_bp, v_active, v_fp, v_sync, v_bp
    "default": (800, 16, 4, 12, 480, 10, 4, 6),   # 832 x 500, 60.1 Hz @ 25 MHz
    "typ":     (800, 8, 4, 4, 480, 8, 4, 4),      # ST7262 typical, 816 x 496
}

# ST7262 section 7.3.4; Thbp/Tvbp INCLUDE the sync pulse
LIMITS = {
    "Fclk (MHz)": (23, 27), "Th": (808, 896), "Thbp": (4, 48), "Thfp": (4, 48),
    "Thw": (2, 8), "Tv": (488, 504), "Tvbp": (4, 12), "Tvfp": (4, 12),
    "Tvw": (2, 8),
}


# ---------------------------------------------------------------------------
# /dev/mem access
# ---------------------------------------------------------------------------
class Mem:
    """32-bit register window.  ctypes word access, never byte copies."""

    def __init__(self, base, size=0x1000):
        self.fd = os.open("/dev/mem", os.O_RDWR | os.O_SYNC)
        self.mm = mmap.mmap(self.fd, size, mmap.MAP_SHARED,
                            mmap.PROT_READ | mmap.PROT_WRITE, offset=base)

    def rd(self, off):
        return ctypes.c_uint32.from_buffer(self.mm, off).value

    def wr(self, off, val):
        ctypes.c_uint32.from_buffer(self.mm, off).value = val & 0xFFFFFFFF


_slcr = None
_lcd = None


def slcr():
    global _slcr
    if _slcr is None:
        _slcr = Mem(SLCR_BASE)
    return _slcr


def slcr_write(off, val):
    """Write an SLCR register, leaving the lock as we found it.  Linux keeps
    the SLCR permanently UNLOCKED and writes it without checking (the FPGA
    manager's level-shifter enable, clocks, reboot); re-locking it behind the
    kernel's back makes those writes silently vanish."""
    s = slcr()
    was_locked = s.rd(SLCR_LOCKSTA) & 1
    if was_locked:
        s.wr(SLCR_UNLOCK, 0xDF0D)
    s.wr(off, val)
    if was_locked:
        s.wr(SLCR_LOCK, 0x767B)


def fpga_state():
    try:
        with open("/sys/class/fpga_manager/fpga0/state") as f:
            return f.read().strip()
    except OSError as e:
        return "unreadable (%s)" % e


def pl_safe():
    """Return None if AXI access to the PL is safe, else the reason not."""
    st = fpga_state()
    if st != "operating":
        return "FPGA manager state is %r, not 'operating' - no bitstream?" % st
    s = slcr()
    if s.rd(LVL_SHFTR_EN) & 0xF != 0xF:
        return "PS-PL level shifters are off (LVL_SHFTR_EN=0x%X)" % s.rd(LVL_SHFTR_EN)
    if s.rd(FPGA_RST_CTRL) & 0x1:
        return "PL reset FCLK_RESET0 is asserted (FPGA_RST_CTRL=0x%X)" % s.rd(FPGA_RST_CTRL)
    if s.rd(FPGA0_THR_CTRL) & 0x1:
        return "FCLK0 (the AXI clock) is gated off (FPGA0_THR_CTRL=1)"
    return None


def lcd():
    global _lcd
    if _lcd is None:
        why = pl_safe()
        if why:
            sys.exit("refusing to touch the PL: " + why)
        _lcd = Mem(LCD_BASE)
        ident = _lcd.rd(R_ID)
        if ident != LCD_ID:
            sys.exit("ID at 0x%08X is 0x%08X, expected 0x%08X ('LCD1') - "
                     "wrong bitstream loaded?" % (LCD_BASE, ident, LCD_ID))
    return _lcd


# ---------------------------------------------------------------------------
# fields
# ---------------------------------------------------------------------------
def get_field(name):
    reg, lsb, w = FIELDS[name]
    return (lcd().rd(reg) >> lsb) & ((1 << w) - 1)


def set_fields(pairs):
    """pairs: list of (name, value).  Read-modify-write, grouped per register
    so each register is written once (each write triggers one APPLY)."""
    per_reg = {}
    for name, val in pairs:
        if name not in FIELDS:
            sys.exit("unknown field %r; known: %s" % (name, ", ".join(FIELDS)))
        reg, lsb, w = FIELDS[name]
        if val < 0 or val >= (1 << w):
            sys.exit("%s=%d does not fit in %d bits" % (name, val, w))
        cur = per_reg.get(reg, lcd().rd(reg))
        mask = ((1 << w) - 1) << lsb
        per_reg[reg] = (cur & ~mask) | (val << lsb)
    for reg, v in per_reg.items():
        lcd().wr(reg, v)
    wait_applied()


def wait_applied(timeout=0.5):
    t0 = time.time()
    while time.time() - t0 < timeout:
        if lcd().rd(R_STATUS) & 0x10:
            return True
        time.sleep(0.002)
    print("warning: pixel domain did not acknowledge the write within %.1f s "
          "- is the pixel clock (FCLK1) running?  try `lcdctl.py pclk 25`" % timeout)
    return False


def parse_int(s):
    return int(s, 0)


# ---------------------------------------------------------------------------
# pixel clock (FCLK1)
# ---------------------------------------------------------------------------
def pll_rates():
    s = slcr()
    fdiv = lambda r: (s.rd(r) >> 12) & 0x7F
    # SRCSEL encodings for FPGAn_CLK_CTRL[5:4]: 0x = IO PLL, 10 = ARM, 11 = DDR.
    # ARM PLL is left out on purpose: the CPU runs off it.
    return {"IO": (0, PS_CLK_HZ * fdiv(IO_PLL_CTRL)),
            "DDR": (3, PS_CLK_HZ * fdiv(DDR_PLL_CTRL))}


def fclk_options(lo_hz=None, hi_hz=None):
    """All (hz, pll, srcsel, div0, div1) reachable, deduplicated by rate."""
    opts = {}
    for pll, (sel, f) in pll_rates().items():
        for d0 in range(1, 64):
            for d1 in range(1, 64):
                hz = f / (d0 * d1)
                if lo_hz is not None and not (lo_hz <= hz <= hi_hz):
                    continue
                key = round(hz)
                # prefer IO PLL, then the smaller DIV0 (both are fine)
                if key not in opts:
                    opts[key] = (hz, pll, sel, d0, d1)
    return sorted(opts.values())


def fclk1_decode():
    v = slcr().rd(FPGA1_CLK_CTRL)
    sel = (v >> 4) & 3
    d0 = (v >> 8) & 0x3F
    d1 = (v >> 20) & 0x3F
    rates = pll_rates()
    src = {0: "IO", 1: "IO", 2: "ARM", 3: "DDR"}[sel]
    if src == "ARM":
        f = PS_CLK_HZ * ((slcr().rd(ARM_PLL_CTRL) >> 12) & 0x7F)
    else:
        f = rates[src][1]
    hz = f / (d0 * d1) if d0 and d1 else 0
    gated = slcr().rd(FPGA1_THR_CTRL) & 1
    return hz, src, d0, d1, gated


def set_pclk(mhz):
    target = mhz * 1e6
    hz, pll, sel, d0, d1 = min(fclk_options(), key=lambda o: abs(o[0] - target))
    v = slcr().rd(FPGA1_CLK_CTRL)
    v = (v & ~((0x3F << 20) | (0x3F << 8) | (0x3 << 4))) | \
        (d1 << 20) | (d0 << 8) | (sel << 4)
    slcr_write(FPGA1_CLK_CTRL, v)
    slcr_write(FPGA1_THR_CTRL, 0)          # ungate (Linux disabled it as unused)
    print("FCLK1 -> %.4f MHz  (%s PLL %.0f MHz / %d / %d)%s" % (
        hz / 1e6, pll, pll_rates()[pll][1] / 1e6, d0, d1,
        "" if 23e6 <= hz <= 27e6 else "   ** outside ST7262 23..27 MHz **"))
    return hz


def reapply():
    """A divider change can emit a runt pulse; re-send the config so the
    pixel domain's capture registers are known-good afterwards."""
    if pl_safe() is None:
        lcd().wr(R_CTRL, lcd().rd(R_CTRL))
        wait_applied()


# ---------------------------------------------------------------------------
# commands
# ---------------------------------------------------------------------------
def cmd_status(_args):
    hz, src, d0, d1, gated = fclk1_decode()
    print("FCLK1 (pixel) : %.4f MHz from %s PLL /%d /%d%s" % (
        hz / 1e6, src, d0, d1, "  ** GATED OFF **" if gated else ""))
    print("FPGA manager  : %s" % fpga_state())
    why = pl_safe()
    if why:
        print("PL            : not accessible - %s" % why)
        return
    L = lcd()
    b = L.rd(R_BUILD)
    print("bitstream     : ID OK, build 0x%08X (%s)" % (
        b, time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(b))))
    st = L.rd(R_STATUS)
    f0 = L.rd(R_FRAME_CNT)
    t0 = time.time()
    time.sleep(0.5)
    f1 = L.rd(R_FRAME_CNT)
    fps = (f1 - f0) / (time.time() - t0)
    print("sequencer     : %s%s  DISP=%d BL=%d  applied=%d" % (
        SEQ_STATES[st & 7], " (ready)" if st & 8 else "",
        (st >> 6) & 1, (st >> 7) & 1, (st >> 4) & 1))
    print("pixel clock   : %.3f MHz measured%s" % (
        L.rd(R_PCLK_HZ) / 1e6, "" if st & 0x20 else "  ** NOT RUNNING **"))
    print("frames        : %d  (%.2f fps)" % (f1, fps))
    c = L.rd(R_CTRL)
    print("ctrl          : enable=%d invert=%d hs_low=%d vs_low=%d de_low=%d "
          "de_only=%d override=%d soft_rst=%d" % (
              c & 1, (c >> 1) & 1, (c >> 2) & 1, (c >> 3) & 1, (c >> 4) & 1,
              (c >> 5) & 1, (c >> 9) & 1, (c >> 8) & 1))
    m = [get_field(k) for k in ("h_active", "h_fp", "h_sync", "h_bp",
                                "v_active", "v_fp", "v_sync", "v_bp")]
    ht, vt = sum(m[:4]), sum(m[4:])
    rate = L.rd(R_PCLK_HZ) or hz
    print("mode          : H %d+%d+%d+%d=%d  V %d+%d+%d+%d=%d  -> %.2f Hz" % (
        m[0], m[1], m[2], m[3], ht, m[4], m[5], m[6], m[7], vt,
        rate / (ht * vt) if ht and vt else 0))
    pat = get_field("pattern")
    name = {v: k for k, v in PATTERNS.items()}.get(pat, "?%d" % pat)
    print("pattern       : %s arg=%d solid=%06X" % (name, get_field("arg"),
                                                    get_field("solid")))
    print("sequence      : vdd_wait=%d clk  blank=%d disp=%d off=%d frames" % (
        get_field("vdd_wait"), get_field("blank_frames"),
        get_field("disp_frames"), get_field("off_frames")))
    if c & (1 << 9):
        print("pins (override): 0x%08X" % L.rd(R_PIN_VALUE))
    check_limits(m, rate, quiet_ok=True)


def check_limits(m, rate_hz, quiet_ok=False):
    ha, hf, hs, hb, va, vf, vs, vb = m
    vals = {"Fclk (MHz)": rate_hz / 1e6, "Th": ha + hf + hs + hb,
            "Thbp": hs + hb, "Thfp": hf, "Thw": hs, "Tv": va + vf + vs + vb,
            "Tvbp": vs + vb, "Tvfp": vf, "Tvw": vs}
    bad = 0
    for k, (lo, hi) in LIMITS.items():
        ok = lo <= vals[k] <= hi
        bad += not ok
        if not quiet_ok or not ok:
            print("  %-11s %8.3f   [%g .. %g]  %s" % (k, vals[k], lo, hi,
                                                     "ok" if ok else "** OUT **"))
    if quiet_ok and not bad:
        print("limits        : all inside ST7262 7.3.4")
    return bad


def cmd_limits(_args):
    m = [get_field(k) for k in ("h_active", "h_fp", "h_sync", "h_bp",
                                "v_active", "v_fp", "v_sync", "v_bp")]
    check_limits(m, lcd().rd(R_PCLK_HZ))


def cmd_on(_args):
    set_fields([("override", 0), ("enable", 1)])
    print("enabled; DISP after blank frames, backlight after disp frames "
          "(~0.3 s at defaults)")


def cmd_off(_args):
    set_fields([("enable", 0)])
    print("disabled; backlight off, then DISP, then timing stops")


def cmd_set(args):
    pairs = []
    for a in args:
        if "=" not in a:
            sys.exit("expected name=value, got %r" % a)
        k, v = a.split("=", 1)
        pairs.append((k, parse_int(v)))
    set_fields(pairs)
    for k, _ in pairs:
        print("%s = %d" % (k, get_field(k)))


def cmd_mode(args):
    if not args:
        sys.exit("mode default | typ | h_act,h_fp,h_sync,h_bp,v_act,v_fp,v_sync,v_bp")
    m = MODES.get(args[0])
    if m is None:
        m = tuple(parse_int(x) for x in args[0].split(","))
        if len(m) != 8:
            sys.exit("need 8 comma-separated values")
    keys = ("h_active", "h_fp", "h_sync", "h_bp", "v_active", "v_fp", "v_sync", "v_bp")
    set_fields(list(zip(keys, m)))
    check_limits(list(m), lcd().rd(R_PCLK_HZ), quiet_ok=True)


def cmd_pattern(args):
    if not args or args[0] not in PATTERNS:
        sys.exit("pattern one of: " + " ".join(PATTERNS))
    pairs = [("pattern", PATTERNS[args[0]])]
    if len(args) > 1:
        pairs.append(("arg", parse_int(args[1])))
    set_fields(pairs)


def cmd_solid(args):
    set_fields([("solid", int(args[0], 16)), ("pattern", PATTERNS["solid"])])


def bit_name(b):
    return "%s%d" % ("bgr"[b // 8], b % 8)


def dwell_arg(args, default):
    if "--dwell" in args:
        i = args.index("--dwell")
        d = float(args[i + 1])
        del args[i:i + 2]
        return d
    return default


def cmd_walk(args):
    dwell = dwell_arg(args, 3.0)
    if args and args[0] != "all":
        b = parse_int(args[0])
        set_fields([("pattern", PATTERNS["walk"]), ("arg", b)])
        print("only %s high (J701.%d)" % (bit_name(b), FPC[bit_name(b)]))
        return
    for b in range(24):
        set_fields([("pattern", PATTERNS["walk"]), ("arg", b)])
        print("[%2d] only %s high (J701.%d)" % (b, bit_name(b), FPC[bit_name(b)]),
              flush=True)
        time.sleep(dwell)


def cmd_pclk(args):
    if not args:
        hz, src, d0, d1, gated = fclk1_decode()
        print("FCLK1 = %.4f MHz (%s /%d /%d)%s" % (hz / 1e6, src, d0, d1,
                                                  " GATED" if gated else ""))
        return
    if args[0] == "list":
        for hz, pll, _, d0, d1 in fclk_options(22.5e6, 27.5e6):
            print("  %8.4f MHz   %s /%d /%d" % (hz / 1e6, pll, d0, d1))
        return
    set_pclk(float(args[0]))
    reapply()
    if pl_safe() is None:
        time.sleep(0.25)       # one full meter gate
        print("measured: %.4f MHz" % (lcd().rd(R_PCLK_HZ) / 1e6))


def cmd_sweep(args):
    dwell = dwell_arg(args, 3.0)
    if len(args) != 4:
        sys.exit("sweep <field|pclk> <start> <stop> <step> [--dwell S]")
    name = args[0]
    if name == "pclk":
        start, stop, step = (float(x) for x in args[1:])
    else:
        start, stop, step = (parse_int(x) for x in args[1:])
    v = start
    n = 0
    try:
        while (step > 0 and v <= stop + 1e-9) or (step < 0 and v >= stop - 1e-9):
            if name == "pclk":
                set_pclk(v)
                reapply()
            else:
                set_fields([(name, v)])
            print("[%d] %s = %s" % (n, name, v), flush=True)
            time.sleep(dwell)
            v += step
            n += 1
    except KeyboardInterrupt:
        print("\nstopped at %s = %s" % (name, v))


def cmd_pin(args):
    if not args:
        sys.exit("pin on | off | set name=0|1 ... | walk [--dwell S]")
    sub = args[0]
    if sub == "on":
        set_fields([("pins", 0), ("override", 1)])
        print("override ON, every panel pin and BL_EN driven low")
    elif sub == "off":
        set_fields([("override", 0)])
        print("override OFF, controller drives the pins again")
    elif sub == "set":
        v = get_field("pins")
        for a in args[1:]:
            k, x = a.split("=")
            if k not in PINS:
                sys.exit("pin names: " + " ".join(PINS))
            v = (v & ~(1 << PINS[k])) | ((parse_int(x) & 1) << PINS[k])
        set_fields([("pins", v), ("override", 1)])
        print("pins = 0x%08X" % v)
    elif sub == "walk":
        dwell = dwell_arg(args, 5.0)
        order = ["r%d" % i for i in range(8)] + ["g%d" % i for i in range(8)] + \
                ["b%d" % i for i in range(8)] + ["dclk", "disp", "hs", "vs", "de", "bl"]
        try:
            for k in order:
                set_fields([("pins", 1 << PINS[k]), ("override", 1)])
                where = "J701.%d" % FPC[k] if FPC[k] else "U701 EN (backlight boost)"
                print("%-5s HIGH  -> %s = 3.3 V, all others 0 V" % (k, where), flush=True)
                time.sleep(dwell)
        except KeyboardInterrupt:
            pass
        set_fields([("pins", 0)])
        print("all pins low (override still on; `pin off` to release)")
    else:
        sys.exit("unknown pin subcommand %r" % sub)


def cmd_reset(_args):
    set_fields([("soft_rst", 1)])
    set_fields([("soft_rst", 0)])
    print("pixel domain reset pulsed")


def cmd_dump(_args):
    L = lcd()
    for off in (0x00, 0x04, 0x08, 0x10, 0x14, 0x18, 0x1C, 0x20, 0x24, 0x28,
                0x2C, 0x30, 0x40, 0x44, 0x48, 0x4C):
        print("  0x%02X : 0x%08X" % (off, L.rd(off)))


def cmd_load(args):
    # NOT under /lib/firmware: fpgautil copies its argument there and deletes
    # that copy after loading, which would delete the only copy.
    path = args[0] if args else "/home/root/lcd_debug.bit.bin"
    # The pixel-side resets only release once FCLK1 runs, and Linux gated it
    # at boot as unused; start it at the default 25 MHz before loading.
    set_pclk(25.0)
    if slcr().rd(FPGA0_THR_CTRL) & 1:
        slcr_write(FPGA0_THR_CTRL, 0)
        print("FCLK0 was gated; ungated")
    r = subprocess.run(["fpgautil", "-b", path], capture_output=True, text=True)
    sys.stdout.write(r.stdout + r.stderr)
    if r.returncode != 0:
        sys.exit("fpgautil failed (%d)" % r.returncode)
    why = pl_safe()
    if why:
        sys.exit("loaded, but PL still not accessible: " + why)
    L = lcd()
    L.wr(R_SCRATCH, 0x5A5AA5A5)
    ok = L.rd(R_SCRATCH) == 0x5A5AA5A5
    print("ID OK, build 0x%08X, scratch %s" % (L.rd(R_BUILD), "OK" if ok else "FAILED"))


COMMANDS = {
    "status": cmd_status, "limits": cmd_limits, "on": cmd_on, "off": cmd_off,
    "set": cmd_set, "mode": cmd_mode, "pattern": cmd_pattern, "solid": cmd_solid,
    "walk": cmd_walk, "pclk": cmd_pclk, "sweep": cmd_sweep, "pin": cmd_pin,
    "reset": cmd_reset, "dump": cmd_dump, "load": cmd_load,
}


def main(argv):
    if len(argv) < 2 or argv[1] not in COMMANDS:
        sys.exit(__doc__)
    COMMANDS[argv[1]](argv[2:])


if __name__ == "__main__":
    main(sys.argv)
