onbreak {quit -f}
onerror {quit -f}

vsim -lib xil_defaultlib axis_switch_1_opt

do {wave.do}

view wave
view structure
view signals

do {axis_switch_1.udo}

run -all

quit -force
