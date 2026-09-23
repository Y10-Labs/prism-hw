# Verify every LCD pin really is in bank 13, and that no pin is dedicated/
# unusable.  verify_lcd_pins.py cannot do this offline - bank membership lives
# in the Xilinx package database, not in the KiCad file.
#
#   vivado -mode batch -source check_banks.tcl -tclargs xc7z020clg484-2
#
# Exits non-zero if anything is not in bank 13.

set part [lindex $argv 0]
if {$part eq ""} { set part xc7z020clg484-2 }
link_design -part $part

set pins {
    Y5 Y6 AA6 AA7 AB1 AA4
    V9 V10 W8 V8 W10 AB6 W12 V12
    U11 U12 U9 U10 AB12 AA12 AB11 AA11
    AB9 AB10 Y10 AB7 AA8 AA9 Y8 Y9
}

set bad 0
foreach p $pins {
    set site [get_package_pins $p]
    if {$site eq ""} {
        puts "MISSING  $p : no such package pin on $part"
        incr bad
        continue
    }
    set bank [get_property BANK $site]
    set isio [get_property IS_GENERAL_PURPOSE $site]
    if {$bank != 13} {
        puts "BANK     $p : bank $bank, expected 13"
        incr bad
    } elseif {!$isio} {
        puts "NOT GPIO $p : dedicated pin, cannot be used as user I/O"
        incr bad
    } else {
        puts "ok       $p : bank $bank"
    }
}

# VCCO for bank 13 must be 3.3 V for LVCMOS33 to be legal.
puts ""
puts "bank 13 VCCO requirement: [get_property VCCO [get_iobanks 13]]"

if {$bad} {
    puts "\n$bad PROBLEM(S)"
    exit 1
}
puts "\nall [llength $pins] LCD pins are bank-13 general-purpose I/O"
exit 0
