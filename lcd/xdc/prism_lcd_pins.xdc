# ---------------------------------------------------------------------------
# Prism console - LCD panel pin constraints
# Device: XC7Z020-CLG484-2      Panel: ChengHao CH500WV05A-T (Adafruit 1596)
#
# Every signal below is in BANK 13, whose VCCO is tied to +3V3 on the board
# (package pins T5, U8, V11, W4, Y7, AA10, AB3), so LVCMOS33 is correct and
# satisfies the panel's VIH of 0.7*VDD = 2.31 V.
#
# Pin assignments were extracted directly from DFTBoard.kicad_pcb, not from
# the (stale, 2019-era) DFTBoard.net.
# ---------------------------------------------------------------------------

# ---- pixel clock, J701.30 (panel PCLK) ----
set_property -dict {PACKAGE_PIN Y5   IOSTANDARD LVCMOS33} [get_ports o_clk]

# ---- control ----
set_property -dict {PACKAGE_PIN Y6   IOSTANDARD LVCMOS33} [get_ports o_disp]   ;# J701.31
set_property -dict {PACKAGE_PIN AA6  IOSTANDARD LVCMOS33} [get_ports o_hsync]  ;# J701.32
set_property -dict {PACKAGE_PIN AA7  IOSTANDARD LVCMOS33} [get_ports o_vsync]  ;# J701.33
set_property -dict {PACKAGE_PIN AB1  IOSTANDARD LVCMOS33} [get_ports o_de]     ;# J701.34

# ---- red, J701.5..12 = panel R0..R7 ----
set_property -dict {PACKAGE_PIN V9   IOSTANDARD LVCMOS33} [get_ports {o_red[0]}]
set_property -dict {PACKAGE_PIN V10  IOSTANDARD LVCMOS33} [get_ports {o_red[1]}]
set_property -dict {PACKAGE_PIN W8   IOSTANDARD LVCMOS33} [get_ports {o_red[2]}]
set_property -dict {PACKAGE_PIN V8   IOSTANDARD LVCMOS33} [get_ports {o_red[3]}]
set_property -dict {PACKAGE_PIN W10  IOSTANDARD LVCMOS33} [get_ports {o_red[4]}]
set_property -dict {PACKAGE_PIN AB6  IOSTANDARD LVCMOS33} [get_ports {o_red[5]}]
set_property -dict {PACKAGE_PIN W12  IOSTANDARD LVCMOS33} [get_ports {o_red[6]}]
set_property -dict {PACKAGE_PIN V12  IOSTANDARD LVCMOS33} [get_ports {o_red[7]}]

# ---- green, J701.13..20 = panel G0..G7 ----
set_property -dict {PACKAGE_PIN U11  IOSTANDARD LVCMOS33} [get_ports {o_green[0]}]
set_property -dict {PACKAGE_PIN U12  IOSTANDARD LVCMOS33} [get_ports {o_green[1]}]
set_property -dict {PACKAGE_PIN U9   IOSTANDARD LVCMOS33} [get_ports {o_green[2]}]
set_property -dict {PACKAGE_PIN U10  IOSTANDARD LVCMOS33} [get_ports {o_green[3]}]
set_property -dict {PACKAGE_PIN AB12 IOSTANDARD LVCMOS33} [get_ports {o_green[4]}]
set_property -dict {PACKAGE_PIN AA12 IOSTANDARD LVCMOS33} [get_ports {o_green[5]}]
set_property -dict {PACKAGE_PIN AB11 IOSTANDARD LVCMOS33} [get_ports {o_green[6]}]
set_property -dict {PACKAGE_PIN AA11 IOSTANDARD LVCMOS33} [get_ports {o_green[7]}]

# ---- blue, J701.21..28 = panel B0..B7 ----
set_property -dict {PACKAGE_PIN AB9  IOSTANDARD LVCMOS33} [get_ports {o_blue[0]}]
set_property -dict {PACKAGE_PIN AB10 IOSTANDARD LVCMOS33} [get_ports {o_blue[1]}]
set_property -dict {PACKAGE_PIN Y10  IOSTANDARD LVCMOS33} [get_ports {o_blue[2]}]
set_property -dict {PACKAGE_PIN AB7  IOSTANDARD LVCMOS33} [get_ports {o_blue[3]}]
set_property -dict {PACKAGE_PIN AA8  IOSTANDARD LVCMOS33} [get_ports {o_blue[4]}]
set_property -dict {PACKAGE_PIN AA9  IOSTANDARD LVCMOS33} [get_ports {o_blue[5]}]
set_property -dict {PACKAGE_PIN Y8   IOSTANDARD LVCMOS33} [get_ports {o_blue[6]}]
set_property -dict {PACKAGE_PIN Y9   IOSTANDARD LVCMOS33} [get_ports {o_blue[7]}]

# ---- backlight boost enable: MT3608 (U701) EN.  NOT a panel connector pin. ----
set_property -dict {PACKAGE_PIN AA4  IOSTANDARD LVCMOS33} [get_ports o_bl_en]

# ---------------------------------------------------------------------------
# Unused-pin policy.  The 7-series default is PULLDOWN, which would hold DISP
# low and hold the ACTIVE-LOW syncs permanently asserted on any pin this design
# leaves unconstrained.  Force no pull so an unconstrained pin floats rather
# than being driven to a harmful level, and drive every LCD pin explicitly.
# ---------------------------------------------------------------------------
set_property BITSTREAM.CONFIG.UNUSEDPIN PULLNONE [current_design]
