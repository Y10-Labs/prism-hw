onbreak {quit -force}
onerror {quit -force}

asim +access +r +m+axis_combiner_0 -L axis_infrastructure_v1_1_0 -L axis_combiner_v1_1_20 -L xil_defaultlib -L unisims_ver -L unimacro_ver -L secureip -O5 xil_defaultlib.axis_combiner_0 xil_defaultlib.glbl

do {wave.do}

view wave
view structure

do {axis_combiner_0.udo}

run -all

endsim

quit -force
