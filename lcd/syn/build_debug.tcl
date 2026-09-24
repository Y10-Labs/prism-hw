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
#   FCLK0 50 MHz  -> M_AXI_GP0 -> SmartConnect -> port M_AXI_LCD (AXI4-Lite)
#                                              -> AXI VDMA control
#   AXI VDMA MM2S -> SmartConnect -> S_AXI_HP0 (DDR);  stream -> port M_AXIS_VID
#   FCLK1         -> port pix_clk (rate set at runtime from Linux)
# Address map (GP0): M_AXI_LCD 0x43C0_0000 (4 KB), VDMA 0x4300_0000 (64 KB).
# The VDMA reads frame buffers the board reserves with mem=448M at
# 0x1C00_0000 and up (see lcd/README.md).
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
    CONFIG.PCW_USE_S_AXI_HP0             {1} \
    CONFIG.PCW_S_AXI_HP0_DATA_WIDTH      {64} \
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

set smc_ctl [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smc_ctl]
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {2}] $smc_ctl
set smc_hp [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smc_hp]
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1}] $smc_hp

# MM2S only, free-running (no fsync).  32 frame stores (the maximum), and the
# FRMSTORE register so software picks how many are live: park mode for a
# still image, circular mode to play an animation at the panel's frame rate.
set vdma [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_vdma:6.3 vdma]
set_property -dict [list \
    CONFIG.c_include_s2mm             {0} \
    CONFIG.c_include_mm2s             {1} \
    CONFIG.c_include_sg               {0} \
    CONFIG.c_num_fstores              {32} \
    CONFIG.c_enable_mm2s_frmstr_reg   {1} \
    CONFIG.c_m_axi_mm2s_data_width    {64} \
    CONFIG.c_m_axis_mm2s_tdata_width  {32} \
    CONFIG.c_mm2s_max_burst_length    {16} \
    CONFIG.c_mm2s_linebuffer_depth    {2048} \
    CONFIG.c_use_mm2s_fsync           {0} \
    CONFIG.c_mm2s_genlock_mode        {0} \
] $vdma

set rst_axi [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_axi]
set rst_pix [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_pix]

set m_axis [create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 M_AXIS_VID]
set m_axi [create_bd_intf_port -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 M_AXI_LCD]
set_property -dict [list CONFIG.PROTOCOL {AXI4LITE} CONFIG.ADDR_WIDTH {32} \
                         CONFIG.DATA_WIDTH {32}] $m_axi

create_bd_port -dir O -type clk axi_clk
create_bd_port -dir O -type clk pix_clk
create_bd_port -dir O -type rst axi_aresetn
create_bd_port -dir O -type rst pix_aresetn
set_property CONFIG.ASSOCIATED_BUSIF {M_AXI_LCD:M_AXIS_VID} [get_bd_ports axi_clk]
set_property CONFIG.ASSOCIATED_RESET {axi_aresetn} [get_bd_ports axi_clk]
set_property CONFIG.ASSOCIATED_RESET {pix_aresetn} [get_bd_ports pix_clk]

connect_bd_intf_net [get_bd_intf_pins ps7/M_AXI_GP0] [get_bd_intf_pins smc_ctl/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins smc_ctl/M00_AXI] $m_axi
connect_bd_intf_net [get_bd_intf_pins smc_ctl/M01_AXI] [get_bd_intf_pins vdma/S_AXI_LITE]
connect_bd_intf_net [get_bd_intf_pins vdma/M_AXI_MM2S] [get_bd_intf_pins smc_hp/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins smc_hp/M00_AXI] [get_bd_intf_pins ps7/S_AXI_HP0]
connect_bd_intf_net [get_bd_intf_pins vdma/M_AXIS_MM2S] $m_axis

connect_bd_net [get_bd_pins ps7/FCLK_CLK0] \
    [get_bd_pins ps7/M_AXI_GP0_ACLK] [get_bd_pins ps7/S_AXI_HP0_ACLK] \
    [get_bd_pins smc_ctl/aclk] [get_bd_pins smc_hp/aclk] \
    [get_bd_pins vdma/s_axi_lite_aclk] [get_bd_pins vdma/m_axi_mm2s_aclk] \
    [get_bd_pins vdma/m_axis_mm2s_aclk] \
    [get_bd_pins rst_axi/slowest_sync_clk] [get_bd_ports axi_clk]
connect_bd_net [get_bd_pins ps7/FCLK_CLK1] \
    [get_bd_pins rst_pix/slowest_sync_clk] [get_bd_ports pix_clk]
connect_bd_net [get_bd_pins ps7/FCLK_RESET0_N] \
    [get_bd_pins rst_axi/ext_reset_in] [get_bd_pins rst_pix/ext_reset_in]
connect_bd_net [get_bd_pins rst_axi/peripheral_aresetn] \
    [get_bd_pins smc_ctl/aresetn] [get_bd_pins smc_hp/aresetn] \
    [get_bd_pins vdma/axi_resetn] [get_bd_ports axi_aresetn]
connect_bd_net [get_bd_pins rst_pix/peripheral_aresetn] [get_bd_ports pix_aresetn]

assign_bd_address -offset 0x43C00000 -range 4K \
    -target_address_space [get_bd_addr_spaces ps7/Data] \
    [get_bd_addr_segs M_AXI_LCD/Reg] -force
assign_bd_address -offset 0x43000000 -range 64K \
    -target_address_space [get_bd_addr_spaces ps7/Data] \
    [get_bd_addr_segs vdma/S_AXI_LITE/Reg] -force
# VDMA -> HP0 -> the whole of DDR (it only ever reads the reserved 16 MB)
assign_bd_address -target_address_space [get_bd_addr_spaces vdma/Data_MM2S] \
    [get_bd_addr_segs ps7/S_AXI_HP0/HP0_DDR_LOWOCM] -force
foreach seg [get_bd_addr_segs -of_objects [get_bd_addr_spaces {ps7/Data vdma/Data_MM2S}]] {
    puts [format "ADDR %-40s 0x%08X  %s" [get_property NAME $seg] \
        [get_property OFFSET $seg] [get_property RANGE $seg]]
}

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
    [file join $lcd_dir rtl lcd_async_fifo.v] \
    [file join $lcd_dir rtl lcd_stream_src.v] \
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
