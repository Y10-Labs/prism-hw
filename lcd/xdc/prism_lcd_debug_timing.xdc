# ---------------------------------------------------------------------------
# Prism console - timing for lcd_debug_top (PS7 + AXI registers + LCD)
#
# Clocks come from the PS7 IP's own constraints:
#   clk_fpga_0  FCLK0, 50 MHz, AXI
#   clk_fpga_1  FCLK1, pixel clock.  Constrained at 28.125 MHz (the BD asks
#               for 28, which is IO PLL 1800 / 64), ABOVE the ST7262's 27 MHz
#               maximum, so any rate software sweeps to inside the panel's
#               23-27 MHz window is covered by this analysis.
#
# This file is read with PROCESSING_ORDER LATE so those clocks already exist.
#
# Setup and hold come from the ST7262 datasheet section 9.3.4, 12 ns minimum
# for data, DE, HSYNC and VSYNC alike.  DCLK is forwarded by an ODDR and every
# output flop is in its IOB, so DCLK and data see matched output delays.
# ---------------------------------------------------------------------------

# The forwarded DCLK, non-inverted to match the reset default
# CTRL.clk_invert = 0.  The panel latches on DCLK's FALLING edge (measured on
# the board; ST7262 DCLKPOL = 1), so the output delays below are referenced to
# the falling edge, which sits half a period after the launching rising edge.
# CTRL.clk_invert = 1 is the mirror image (rising edge centred) and is not
# separately analysed.
create_generated_clock -name lcd_dclk \
    -source [get_pins u_lcd/u_clk_out/u_oddr/C] \
    -divide_by 1 \
    [get_ports o_clk]

set LCD_TSU 12.000
set LCD_THD 12.000
set lcd_data_ports [get_ports {o_red[*] o_green[*] o_blue[*] o_de o_hsync o_vsync}]
set_output_delay -clock lcd_dclk -clock_fall -max  $LCD_TSU $lcd_data_ports
set_output_delay -clock lcd_dclk -clock_fall -min [expr {-1 * $LCD_THD}] $lcd_data_ports

# DISP and the backlight enable change at most once per power sequence; the
# ST7262 specifies them only in milliseconds (section 11).
set_false_path -to [get_ports {o_disp o_bl_en}]

# AXI <-> pixel clock crossings.  Only synchroniser inputs and quasi-static
# config / Gray-coded counters cross (lcd_regs_axil.v); bound the data path so
# a captured bus is never skewed by more than one destination period.
set axi_clk [get_clocks -of_objects [get_pins u_regs/r_ctrl_reg[0]/C]]
set pix_clk [get_clocks -of_objects [get_pins u_lcd/u_clk_out/u_oddr/C]]
set_max_delay -datapath_only -from $axi_clk -to $pix_clk 20.000
set_max_delay -datapath_only -from $pix_clk -to $axi_clk 20.000

set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
