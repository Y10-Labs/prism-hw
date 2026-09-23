# ---------------------------------------------------------------------------
# Build the runtime-tunable LCD debug bitstream for the Prism board.
#
#   vivado -mode batch -source syn/build_debug.tcl [-tclargs <outdir>]
#
# Produces, in <outdir> (default lcd/build/debug):
#   lcd_debug.bit       full bitstream (compressed)
#   lcd_debug.bit.bin   the same, byte-swapped for the Linux FPGA manager:
#                         fpgautil -b /home/root/lcd_debug.bit.bin
#   *.rpt               utilisation, timing, DRC, IO
#
# Block design prism_ps: the PS7 configured exactly as the board's FSBL
# configured it (ps7_prism_config.tcl, lifted from the reference XSA), plus
#   FCLK0 50 MHz  -> M_AXI_GP0 -> AXI3-to-AXI4-Lite -> port M_AXI_LCD
#   FCLK1         -> port pix_clk (rate set at runtime from Linux)
# M_AXI_LCD is mapped at 0x43C0_0000, 4 KB.
# ---------------------------------------------------------------------------

set script_dir [file normalize [file dirname [info script]]]
set lcd_dir    [file dirname $script_dir]
set part       xc7z020clg484-2

set outdir [lindex $argv 0]
if {$outdir eq ""} { set outdir [file join $lcd_dir build debug] }
file mkdir $outdir
set prjdir [file join $outdir prj]

# Build stamp readable at 0x43C0_0004: seconds since the epoch.
set build_id [clock seconds]
puts "== outdir   : $outdir"
puts "== build_id : [format 0x%08X $build_id]"

create_project -force lcd_debug $prjdir -part $part
set_property target_language Verilog [current_project]

# ---- block design ---------------------------------------------------------
create_bd_design prism_ps

set ps [create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 ps7]
source [file join $script_dir ps7_prism_config.tcl]
set_property -dict $PRISM_PS7_CONFIG $ps
set_property -dict [list \
    CONFIG.PCW_USE_M_AXI_GP0             {1} \
    CONFIG.PCW_FPGA_FCLK0_ENABLE         {1} \
    CONFIG.PCW_FPGA_FCLK1_ENABLE         {1} \
    CONFIG.PCW_EN_CLK0_PORT              {1} \
    CONFIG.PCW_EN_CLK1_PORT              {1} \
    CONFIG.PCW_EN_RST0_PORT              {1} \
    CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ  {50} \
    CONFIG.PCW_FPGA1_PERIPHERAL_FREQMHZ  {28} \
] $ps

apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
    -config {make_external "FIXED_IO, DDR" apply_board_preset "0" Master "Disable" Slave "Disable"} $ps

set pc [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_protocol_converter:2.1 axi_pc]
set_property -dict [list CONFIG.MI_PROTOCOL {AXI4LITE} CONFIG.TRANSLATION_MODE {2}] $pc

set rst_axi [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_axi]
set rst_pix [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_pix]

set m_axi [create_bd_intf_port -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 M_AXI_LCD]
set_property -dict [list CONFIG.PROTOCOL {AXI4LITE} CONFIG.ADDR_WIDTH {32} \
                         CONFIG.DATA_WIDTH {32}] $m_axi

create_bd_port -dir O -type clk axi_clk
create_bd_port -dir O -type clk pix_clk
create_bd_port -dir O -type rst axi_aresetn
create_bd_port -dir O -type rst pix_aresetn
set_property CONFIG.ASSOCIATED_BUSIF {M_AXI_LCD} [get_bd_ports axi_clk]
set_property CONFIG.ASSOCIATED_RESET {axi_aresetn} [get_bd_ports axi_clk]
set_property CONFIG.ASSOCIATED_RESET {pix_aresetn} [get_bd_ports pix_clk]

connect_bd_intf_net [get_bd_intf_pins ps7/M_AXI_GP0] [get_bd_intf_pins axi_pc/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_pc/M_AXI] $m_axi

connect_bd_net [get_bd_pins ps7/FCLK_CLK0] \
    [get_bd_pins ps7/M_AXI_GP0_ACLK] [get_bd_pins axi_pc/aclk] \
    [get_bd_pins rst_axi/slowest_sync_clk] [get_bd_ports axi_clk]
connect_bd_net [get_bd_pins ps7/FCLK_CLK1] \
    [get_bd_pins rst_pix/slowest_sync_clk] [get_bd_ports pix_clk]
connect_bd_net [get_bd_pins ps7/FCLK_RESET0_N] \
    [get_bd_pins rst_axi/ext_reset_in] [get_bd_pins rst_pix/ext_reset_in]
connect_bd_net [get_bd_pins rst_axi/peripheral_aresetn] \
    [get_bd_pins axi_pc/aresetn] [get_bd_ports axi_aresetn]
connect_bd_net [get_bd_pins rst_pix/peripheral_aresetn] [get_bd_ports pix_aresetn]

assign_bd_address -offset 0x43C00000 -range 4K \
    -target_address_space [get_bd_addr_spaces ps7/Data] \
    [get_bd_addr_segs M_AXI_LCD/Reg] -force

validate_bd_design
save_bd_design

set bd_file [get_files prism_ps.bd]
generate_target all $bd_file
add_files -norecurse [make_wrapper -files $bd_file -top]

# ---- RTL and constraints --------------------------------------------------
add_files -norecurse [list \
    [file join $lcd_dir rtl lcd_defaults.vh]  \
    [file join $lcd_dir rtl lcd_timing.v]     \
    [file join $lcd_dir rtl lcd_power_seq.v]  \
    [file join $lcd_dir rtl lcd_clock_out.v]  \
    [file join $lcd_dir rtl lcd_controller.v] \
    [file join $lcd_dir rtl lcd_regs_axil.v]  \
    [file join $lcd_dir rtl lcd_debug_top.v] ]
set_property file_type {Verilog Header} [get_files lcd_defaults.vh]
set_property include_dirs [file join $lcd_dir rtl] [current_fileset]
set_property verilog_define {LCD_USE_ODDR} [current_fileset]
set_property top lcd_debug_top [current_fileset]
set_property generic "BUILD_ID=32'h[format %08X $build_id]" [current_fileset]

add_files -fileset constrs_1 -norecurse [list \
    [file join $lcd_dir xdc prism_lcd_pins.xdc] \
    [file join $lcd_dir xdc prism_lcd_debug_timing.xdc] ]
set_property PROCESSING_ORDER LATE [get_files prism_lcd_debug_timing.xdc]
# Timing constraints only make sense after synthesis created the ODDR.
set_property USED_IN_SYNTHESIS false [get_files prism_lcd_debug_timing.xdc]

# ---- run --------------------------------------------------------------------
launch_runs synth_1 -jobs 8
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} { error "synthesis failed" }

launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} { error "implementation failed" }

open_run impl_1
report_utilization    -file [file join $outdir utilization.rpt]
report_timing_summary -file [file join $outdir timing_summary.rpt]
report_drc            -file [file join $outdir drc.rpt]
report_io             -file [file join $outdir io.rpt]
report_cdc            -file [file join $outdir cdc.rpt]

set wns [get_property SLACK [get_timing_paths -delay_type max]]
set whs [get_property SLACK [get_timing_paths -delay_type min]]

# Every panel output flop must actually be placed in an OLOGIC (IOB) site.
set out_ffs [get_cells -regexp {u_lcd/(rgb|hs|vs|de|disp|bl)_q_reg.*}]
set not_iob [filter $out_ffs {LOC !~ OLOGIC*}]
puts "RESULT OUT_FFS=[llength $out_ffs]" 

set bit_src [lindex [glob [file join $prjdir lcd_debug.runs impl_1 *.bit]] 0]
set bit     [file join $outdir lcd_debug.bit]
file copy -force $bit_src $bit

set bif [file join $outdir lcd_debug.bif]
set fh [open $bif w]; puts $fh "all:\n{\n    $bit\n}"; close $fh
exec bootgen -image $bif -arch zynq -process_bitstream bin -w on

puts "=========================================="
puts "RESULT BUILD_ID=[format 0x%08X $build_id]"
puts "RESULT WNS=$wns"
puts "RESULT WHS=$whs"
puts "RESULT NOT_IN_IOB=[llength $not_iob] $not_iob"
puts "RESULT BIT=$bit"
puts "RESULT BIN=$bit.bin"
if {$wns >= 0 && $whs >= 0} { puts "RESULT TIMING=MET" } else { puts "RESULT TIMING=VIOLATED" }
puts "=========================================="
