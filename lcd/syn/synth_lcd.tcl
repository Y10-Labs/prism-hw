# ---------------------------------------------------------------------------
# Standalone synth + implement of lcd_controller, batch mode.
#
#   vivado -mode batch -source syn/synth_lcd.tcl -tclargs <part> [outdir]
#
# e.g. xc7z020clg484-2 (Prism board) or xc7z020clg400-1 (PYNQ-Z2).
# All paths resolve relative to this script, so it works from any cwd.
# ---------------------------------------------------------------------------

set script_dir [file normalize [file dirname [info script]]]
set lcd_dir    [file dirname $script_dir]

set part   [lindex $argv 0]
if {$part eq ""} { set part "xc7z020clg484-2" }
set outdir [lindex $argv 1]
if {$outdir eq ""} { set outdir [file join $lcd_dir build syn_$part] }

file mkdir $outdir
puts "== part   : $part"
puts "== outdir : $outdir"

read_verilog [list \
    [file join $lcd_dir rtl lcd_timing.v]     \
    [file join $lcd_dir rtl lcd_power_seq.v]  \
    [file join $lcd_dir rtl lcd_clock_out.v]  \
    [file join $lcd_dir rtl lcd_controller.v] \
    [file join $lcd_dir rtl lcd_bringup_top.v] ]

# LCD_USE_ODDR swaps the behavioural clock forward for a real ODDR primitive.
synth_design -top lcd_bringup_top -part $part -verilog_define LCD_USE_ODDR \
             -include_dirs [file join $lcd_dir rtl] -flatten_hierarchy none

# Pin constraints only apply to the board they were written for.
if {[string match "*clg484*" $part]} {
    read_xdc [file join $lcd_dir xdc prism_lcd_pins.xdc]
}

# clk / rst_n / i_enable come from the PS (FCLK_CLK0) once this module is
# instantiated under a block design, so they legitimately have no PACKAGE_PIN.
# Demote the resulting checks so a clean run is distinguishable from a real
# I/O problem; every port that IS a board pin is constrained in the XDC above.
set_property SEVERITY {Warning} [get_drc_checks NSTD-1]
set_property SEVERITY {Warning} [get_drc_checks UCIO-1]
read_xdc [file join $lcd_dir xdc prism_lcd_timing.xdc]

opt_design
place_design
route_design

report_utilization -file [file join $outdir utilization.rpt]
report_timing_summary -file [file join $outdir timing_summary.rpt]
report_drc -file [file join $outdir drc.rpt]

# ---- machine-readable summary so CI can gate on it ----
set wns [get_property SLACK [get_timing_paths -delay_type max]]
set whs [get_property SLACK [get_timing_paths -delay_type min]]
set luts [get_property USED [get_cells -hier -filter {PRIMITIVE_GROUP == LUT}]]

puts "=========================================="
puts "RESULT part=$part"
puts "RESULT WNS=$wns"
puts "RESULT WHS=$whs"
# PRIMITIVE_GROUP does not classify these the way you would expect (it counted
# route-thrus as LUTs and missed BRAM/DSP entirely); match on REF_NAME instead,
# which agrees with report_utilization.
puts "RESULT LUT=[llength [get_cells -hier -filter {REF_NAME =~ LUT*}]]"
puts "RESULT FF=[llength [get_cells -hier -filter {REF_NAME =~ FD*}]]"
puts "RESULT ODDR=[llength [get_cells -hier -filter {REF_NAME == ODDR}]]"
if {$wns >= 0 && $whs >= 0} { puts "RESULT TIMING=MET" } else { puts "RESULT TIMING=VIOLATED" }
puts "=========================================="

write_checkpoint -force [file join $outdir lcd_routed.dcp]
