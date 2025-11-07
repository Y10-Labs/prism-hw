onbreak {quit -f}
onerror {quit -f}

vsim -voptargs="+acc" -L axis_infrastructure_v1_1_0 -L xil_defaultlib -L axis_broadcaster_v1_1_21 -L unisims_ver -L unimacro_ver -L secureip -lib xil_defaultlib xil_defaultlib.axis_broadcaster_0 xil_defaultlib.glbl

do {wave.do}

view wave
view structure
view signals

do {axis_broadcaster_0.udo}

run -all

quit -force
