vlib work
vlib riviera

vlib riviera/axis_infrastructure_v1_1_0
vlib riviera/axis_combiner_v1_1_20
vlib riviera/xil_defaultlib

vmap axis_infrastructure_v1_1_0 riviera/axis_infrastructure_v1_1_0
vmap axis_combiner_v1_1_20 riviera/axis_combiner_v1_1_20
vmap xil_defaultlib riviera/xil_defaultlib

vlog -work axis_infrastructure_v1_1_0  -v2k5 "+incdir+../../../ipstatic/hdl" \
"../../../ipstatic/hdl/axis_infrastructure_v1_1_vl_rfs.v" \

vlog -work axis_combiner_v1_1_20  -v2k5 "+incdir+../../../ipstatic/hdl" \
"../../../ipstatic/hdl/axis_combiner_v1_1_vl_rfs.v" \

vlog -work xil_defaultlib  -v2k5 "+incdir+../../../ipstatic/hdl" \
"../../../../testAll.gen/sources_1/ip/axis_combiner_0/sim/axis_combiner_0.v" \


vlog -work xil_defaultlib \
"glbl.v"

