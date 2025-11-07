vlib modelsim_lib/work
vlib modelsim_lib/msim

vlib modelsim_lib/msim/axis_infrastructure_v1_1_0
vlib modelsim_lib/msim/axis_combiner_v1_1_20
vlib modelsim_lib/msim/xil_defaultlib

vmap axis_infrastructure_v1_1_0 modelsim_lib/msim/axis_infrastructure_v1_1_0
vmap axis_combiner_v1_1_20 modelsim_lib/msim/axis_combiner_v1_1_20
vmap xil_defaultlib modelsim_lib/msim/xil_defaultlib

vlog -work axis_infrastructure_v1_1_0  -incr "+incdir+../../../ipstatic/hdl" \
"../../../ipstatic/hdl/axis_infrastructure_v1_1_vl_rfs.v" \

vlog -work axis_combiner_v1_1_20  -incr "+incdir+../../../ipstatic/hdl" \
"../../../ipstatic/hdl/axis_combiner_v1_1_vl_rfs.v" \

vlog -work xil_defaultlib  -incr "+incdir+../../../ipstatic/hdl" \
"../../../../testAll.gen/sources_1/ip/axis_combiner_0/sim/axis_combiner_0.v" \


vlog -work xil_defaultlib \
"glbl.v"

