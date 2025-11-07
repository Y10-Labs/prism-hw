onbreak {quit -f}
onerror {quit -f}

vsim -lib xil_defaultlib axis_combiner_1_opt

do {wave.do}

view wave
view structure
view signals

do {axis_combiner_1.udo}

run -all

quit -force
