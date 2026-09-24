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

  DDR frame buffers -> AXI VDMA -> panel (needs mem=448M, see lcd/README.md):
    lcdctl.py fb load N frameN.raw                    # 800x480 XRGB8888 into store N
    lcdctl.py video start | stop | park N | status    # VDMA MM2S, park mode
    lcdctl.py flip [--fps 5] [--seconds S]            # alternate stores 0 and 1
    lcdctl.py anim load loop.anim                     # background + patches -> stores
    lcdctl.py anim play [N]                           # circular: 1 store per panel frame
    lcdctl.py anim check                              # measure fps, count skips/repeats

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

# AXI VDMA (MM2S only) and the frame buffers.  The buffers live in the top
# 64 MB of DDR, which the board hides from Linux with mem=448M: 32 frame
# stores (the VDMA maximum) of 1.5 MiB, each holding one 1,536,000 B frame.
VDMA_BASE     = 0x43000000
FB_BASE       = 0x1C000000
FB_SPACING    = 0x00180000       # 1.5 MiB per frame store
FB_COUNT      = 32
BPP           = 4                # XRGB8888, little-endian 0x00RRGGBB
V_CR, V_SR, V_REG_INDEX, V_FRMSTORE, V_PARK, V_VERSION = 0x00, 0x04, 0x14, 0x18, 0x28, 0x2C
V_VSIZE, V_HSIZE, V_STRIDE, V_ADDR0 = 0x50, 0x54, 0x58, 0x5C

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
    "src_clear":    (R_CTRL, 10, 1),
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
            "checker": 5, "ext": 6, "black": 15}   # ext = DDR frames via VDMA

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


# ---------------------------------------------------------------------------
# DDR frame buffers + VDMA
# ---------------------------------------------------------------------------
def fb_region_is_free():
    """True if the frame-buffer region is outside every System RAM range.
    Writing it while Linux owns it would corrupt the kernel."""
    lo, hi = FB_BASE, FB_BASE + FB_COUNT * FB_SPACING - 1
    with open("/proc/iomem") as f:
        for line in f:
            if "System RAM" in line:
                a, b = (int(x, 16) for x in line.split(":")[0].strip().split("-"))
                if a <= hi and lo <= b:
                    return False
    return True


_fb = None


def fb():
    global _fb
    if _fb is None:
        if not fb_region_is_free():
            sys.exit("0x%08X.. is System RAM - boot with mem=448M (uEnv.txt) "
                     "before using frame buffers" % FB_BASE)
        _fb = Mem(FB_BASE, FB_COUNT * FB_SPACING)
    return _fb


_vdma = None


def vdma():
    global _vdma
    if _vdma is None:
        lcd()                              # the same PL safety gate + ID check
        _vdma = Mem(VDMA_BASE, 0x10000)
    return _vdma


def frame_geometry():
    return get_field("h_active"), get_field("v_active")


def cmd_fb(args):
    if len(args) != 3 or args[0] != "load":
        sys.exit("fb load N file.raw")
    n, path = int(args[1]), args[2]
    if not 0 <= n < FB_COUNT:
        sys.exit("frame store 0..%d" % (FB_COUNT - 1))
    data = open(path, "rb").read()
    w, h = frame_geometry()
    if len(data) != w * h * BPP:
        sys.exit("%s is %d bytes, expected %d (%dx%dx%d)" % (
            path, len(data), w * h * BPP, w, h, BPP))
    off = n * FB_SPACING
    t0 = time.time()
    fb().mm[off:off + len(data)] = data
    ok = fb().mm[off:off + len(data)] == data
    print("frame %d @ 0x%08X: %d bytes in %.2f s, readback %s" % (
        n, FB_BASE + off, len(data), time.time() - t0, "OK" if ok else "MISMATCH"))


def vdma_status_str():
    v = vdma()
    sr = v.rd(V_SR)
    flags = [name for bit, name in ((0, "halted"), (4, "INT_ERR"), (5, "SLV_ERR"),
                                    (6, "DEC_ERR"), (7, "SOF_EARLY"))
             if sr >> bit & 1]
    return "CR=0x%08X SR=0x%08X [%s] park=%d (reading %d)" % (
        v.rd(V_CR), sr, " ".join(flags) or "running",
        v.rd(V_PARK) & 0x1F, (v.rd(V_PARK) >> 16) & 0x1F)


def vdma_run(circular, nstores):
    """(Re)start MM2S over frame stores 0..nstores-1: park mode (store in
    PARK_PTR) or circular mode (advance one store per frame, i.e. one per
    panel refresh, because the panel back-pressures the stream)."""
    fb()                                   # refuses unless the region is reserved
    v = vdma()
    w, h = frame_geometry()
    v.wr(V_CR, 0x4)                        # soft reset
    t0 = time.time()
    while v.rd(V_CR) & 0x4 and time.time() - t0 < 0.1:
        pass
    v.wr(V_FRMSTORE, nstores)
    v.wr(V_CR, 0x1 | (0x2 if circular else 0))   # RS, Circular_Park
    # Only 16 start-address registers exist (0x5C..0x98); with more than 16
    # frame stores, stores 16..31 sit behind the same offsets, selected by
    # MM2S_REG_INDEX = 1 (PG020).  Writing 0x9C.. instead silently does
    # nothing and the VDMA later halts with SLV_ERR on store 16.
    for i in range(FB_COUNT):
        v.wr(V_REG_INDEX, i // 16)
        v.wr(V_ADDR0 + 4 * (i % 16), FB_BASE + i * FB_SPACING)
    v.wr(V_REG_INDEX, 0)
    v.wr(V_PARK, 0)
    v.wr(V_STRIDE, w * BPP)                # frame delay 0
    v.wr(V_HSIZE, w * BPP)
    v.wr(V_VSIZE, h)                       # writing VSIZE starts the channel
    set_fields([("src_clear", 1)])
    set_fields([("src_clear", 0), ("pattern", PATTERNS["ext"])])
    time.sleep(0.1)


def cmd_anim(args):
    import gzip
    import struct
    sub = args[0] if args else "check"
    if sub == "load":
        blob = gzip.decompress(open(args[1], "rb").read())
        if blob[:8] != b"LCDANIM1":
            sys.exit("not an LCDANIM1 file")
        w, h, n, bpp = struct.unpack_from("<4H", blob, 8)
        if (w, h, bpp) != (*frame_geometry(), BPP) or not 1 <= n <= FB_COUNT:
            sys.exit("file is %dx%dx%d with %d frames; need %dx%dx%d, <= %d frames"
                     % (w, h, bpp, n, *frame_geometry(), BPP, FB_COUNT))
        pos = 16
        bg = blob[pos:pos + w * h * bpp]
        pos += len(bg)
        m = fb().mm
        t0 = time.time()
        for i in range(n):
            base = i * FB_SPACING
            m[base:base + len(bg)] = bg
            (nr,) = struct.unpack_from("<H", blob, pos)
            pos += 2
            for _ in range(nr):
                x, y, rw, rh = struct.unpack_from("<4H", blob, pos)
                pos += 8
                row = rw * bpp
                for yy in range(rh):
                    o = base + ((y + yy) * w + x) * bpp
                    m[o:o + row] = blob[pos:pos + row]
                    pos += row
        print("%d frames built in stores 0..%d in %.1f s" % (n, n - 1, time.time() - t0))
        with open("/tmp/lcd_anim_frames", "w") as f:
            f.write(str(n))
    elif sub == "play":
        try:
            n = int(args[1]) if len(args) > 1 else int(open("/tmp/lcd_anim_frames").read())
        except OSError:
            sys.exit("anim play N  (or run `anim load` first)")
        vdma_run(circular=True, nstores=n)
        print("playing %d frames in circular mode: VDMA %s" % (n, vdma_status_str()))
    elif sub == "check":
        # Sample which store the VDMA is reading, as fast as Python can, for
        # one second.  At 60 fps a store lasts 16.6 ms, far longer than a
        # sample, so every change is seen: +1 (mod N) is a clean step,
        # anything else is a skip or a repeat.
        v, L = vdma(), lcd()
        n = v.rd(V_FRMSTORE) & 0x3F
        fc0, t0 = L.rd(R_FRAME_CNT), time.time()
        last = (v.rd(V_PARK) >> 16) & 0x1F
        steps = bad = samples = 0
        while time.time() - t0 < 1.0:
            cur = (v.rd(V_PARK) >> 16) & 0x1F
            samples += 1
            if cur != last:
                steps += 1
                if cur != (last + 1) % n:
                    bad += 1
                last = cur
        dt = time.time() - t0
        fc = L.rd(R_FRAME_CNT) - fc0
        st = L.rd(R_STATUS)
        print("VDMA stores/s : %.2f   panel frames/s : %.2f   (%d stores in the loop)"
              % (steps / dt, fc / dt, n))
        print("out-of-order steps: %d   samples: %d   underflow_seen=%d misalign_seen=%d"
              % (bad, samples, (st >> 10) & 1, (st >> 11) & 1))
        print("VDMA: " + vdma_status_str())
    else:
        sys.exit("anim load FILE | play [N] | check")


def cmd_video(args):
    sub = args[0] if args else "status"
    v = vdma()
    if sub == "start":
        vdma_run(circular=False, nstores=FB_COUNT)
        print("VDMA: " + vdma_status_str())
        cmd_video(["status"])
    elif sub == "stop":
        set_fields([("pattern", PATTERNS["bars"])])
        v.wr(V_CR, 0x0)
        print("VDMA stopped, back to colour bars")
    elif sub == "park":
        n = int(args[1])
        v.wr(V_PARK, n & 0x1F)
        print("park -> frame %d" % n)
    elif sub == "status":
        st = lcd().rd(R_STATUS)
        print("VDMA   : " + vdma_status_str())
        print("stream : %s  underflow_seen=%d misalign_seen=%d" % (
            ["SEEK", "READY", "RUN", "?"][(st >> 8) & 3], (st >> 10) & 1, (st >> 11) & 1))
    else:
        sys.exit("video start | stop | park N | status")


def cmd_flip(args):
    fps = 5.0
    seconds = None
    if "--fps" in args:
        fps = float(args[args.index("--fps") + 1])
    if "--seconds" in args:
        seconds = float(args[args.index("--seconds") + 1])
    v = vdma()
    period = 1.0 / fps
    n, t_next, t0 = 0, time.time(), time.time()
    print("flipping frames 0/1 at %.2f fps%s (Ctrl-C to stop)" % (
        fps, "" if seconds is None else " for %.0f s" % seconds), flush=True)
    try:
        while seconds is None or time.time() - t0 < seconds:
            v.wr(V_PARK, n % FB_COUNT)
            n += 1
            t_next += period
            time.sleep(max(0.0, t_next - time.time()))
    except KeyboardInterrupt:
        pass
    print("%d flips in %.1f s (%.2f fps)" % (n, time.time() - t0, n / (time.time() - t0)))


COMMANDS = {
    "status": cmd_status, "limits": cmd_limits, "on": cmd_on, "off": cmd_off,
    "set": cmd_set, "mode": cmd_mode, "pattern": cmd_pattern, "solid": cmd_solid,
    "walk": cmd_walk, "pclk": cmd_pclk, "sweep": cmd_sweep, "pin": cmd_pin,
    "reset": cmd_reset, "dump": cmd_dump, "load": cmd_load,
    "fb": cmd_fb, "video": cmd_video, "flip": cmd_flip, "anim": cmd_anim,
}


def main(argv):
    if len(argv) < 2 or argv[1] not in COMMANDS:
        sys.exit(__doc__)
    COMMANDS[argv[1]](argv[2:])


if __name__ == "__main__":
    main(sys.argv)
