# ---------------------------------------------------------------------------
# Rebuild the testAll block design for a different part, from sources only.
#
#   vivado -mode batch -source testAll/retarget.tcl -tclargs <part> [outdir]
#
# The checked-in project is Vivado 2020.2 / xc7z020clg484-2.  Rather than
# migrating it in place (which mutates the tracked project), this creates a
# throwaway project from the same sources so the original is left untouched.
# All paths resolve relative to this script.
# ---------------------------------------------------------------------------

set script_dir [file normalize [file dirname [info script]]]
set repo_dir   [file dirname $script_dir]

set part [lindex $argv 0]
if {$part eq ""} { set part "xc7z020clg400-1" }
set outdir [lindex $argv 1]
if {$outdir eq ""} { set outdir [file join $script_dir build retarget_$part] }

file delete -force $outdir
file mkdir $outdir
puts "== retarget testAll -> $part"
puts "== outdir $outdir"

create_project retarget $outdir -part $part -force

# RTL sources (the BD's own IP is regenerated for the new part below)
add_files -norecurse [list \
    [file join $script_dir testAll.srcs sources_1 new repeater.v] \
    [file join $script_dir testAll.srcs sources_1 imports prism-hw-main raster-core raster_core.v] \
    [file join $script_dir testAll.srcs sources_1 imports prism-hw-main raster-core rc_wrapper.v] \
    [file join $script_dir testAll.srcs sources_1 imports prism-hw-main raster-core RAM_SDP.v] ]

foreach f [glob -nocomplain [file join $script_dir testAll.srcs sources_1 imports lambdagen *.v]] {
    add_files -norecurse $f
}

# The custom `repeater` IP is packaged in place (component.xml lives in
# sources_1), and the AXIS switches/broadcasters/combiners are standalone IP
# outside the block design.  Both have to be available before synthesis or the
# BD's repeater instance cannot elaborate.
set_property ip_repo_paths [file join $script_dir testAll.srcs sources_1] [current_project]
update_ip_catalog -rebuild

foreach xci [glob -nocomplain [file join $script_dir testAll.srcs sources_1 ip * *.xci]] {
    puts "== adding IP [file tail $xci]"
    add_files -norecurse $xci
}

update_compile_order -fileset sources_1

# Re-create the block design from the checked-in .bd.  Vivado retargets the IP
# to the project part on import.
set bd_src [file join $script_dir testAll.srcs sources_1 bd design_1 design_1.bd]
if {[catch {read_bd $bd_src} err]} {
    puts "ERROR_BD_READ: $err"
    exit 1
}
set bd [get_files design_1.bd]
open_bd_design $bd

if {[catch {
    upgrade_ip [get_ips *] -quiet
    export_ip_user_files -of_objects [get_ips *] -no_script -sync -force -quiet
    validate_bd_design
    generate_target all $bd
    make_wrapper -files $bd -top -import
} err]} {
    puts "ERROR_BD_BUILD: $err"
}

generate_target all [get_files *.xci] -quiet
set_property top design_1_wrapper [current_fileset]
update_compile_order -fileset sources_1

launch_runs synth_1 -jobs 16
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
    puts "RESULT SYNTH=FAILED"
    exit 1
}
puts "RESULT SYNTH=OK"

launch_runs impl_1 -jobs 16
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
    puts "RESULT IMPL=FAILED"
    exit 1
}
puts "RESULT IMPL=OK"

open_run impl_1
report_utilization    -file [file join $outdir utilization.rpt]
report_timing_summary -file [file join $outdir timing_summary.rpt]

set wns [get_property SLACK [get_timing_paths -delay_type max]]
set whs [get_property SLACK [get_timing_paths -delay_type min]]
puts "=========================================="
puts "RESULT part=$part"
puts "RESULT WNS=$wns"
puts "RESULT WHS=$whs"
# PRIMITIVE_GROUP does not classify these the way you would expect (it counted
# route-thrus as LUTs and missed BRAM/DSP entirely); match on REF_NAME instead,
# which agrees with report_utilization.
puts "RESULT LUT=[llength [get_cells -hier -filter {REF_NAME =~ LUT*}]]"
puts "RESULT FF=[llength [get_cells -hier -filter {REF_NAME =~ FD*}]]"
puts "RESULT BRAM=[llength [get_cells -hier -filter {REF_NAME =~ RAMB*}]]"
puts "RESULT DSP=[llength [get_cells -hier -filter {REF_NAME =~ DSP*}]]"
if {$wns >= 0 && $whs >= 0} { puts "RESULT TIMING=MET" } else { puts "RESULT TIMING=VIOLATED" }
puts "=========================================="
