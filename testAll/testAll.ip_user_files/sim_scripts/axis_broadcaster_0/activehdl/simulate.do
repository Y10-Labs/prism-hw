onbreak {quit -force}
onerror {quit -force}

asim +access +r +m+axis_broadcaster_0 -L axis_infrastructure_v1_1_0 -L xil_defaultlib -L axis_broadcaster_v1_1_21 -L unisims_ver -L unimacro_ver -L secureip -O5 xil_defaultlib.axis_broadcaster_0 xil_defaultlib.glbl

do {wave.do}

view wave
view structure

do {axis_broadcaster_0.udo}

run -all

endsim

quit -force
