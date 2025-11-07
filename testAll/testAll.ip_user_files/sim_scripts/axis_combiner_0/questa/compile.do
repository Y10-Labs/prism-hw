vlib questa_lib/work
vlib questa_lib/msim

vlib questa_lib/msim/axis_infrastructure_v1_1_0
vlib questa_lib/msim/axis_combiner_v1_1_20
vlib questa_lib/msim/xil_defaultlib

vmap axis_infrastructure_v1_1_0 questa_lib/msim/axis_infrastructure_v1_1_0
vmap axis_combiner_v1_1_20 questa_lib/msim/axis_combiner_v1_1_20
vmap xil_defaultlib questa_lib/msim/xil_defaultlib

vlog -work axis_infrastructure_v1_1_0  "+incdir+../../../ipstatic/hdl" \
"../../../ipstatic/hdl/axis_infrastructure_v1_1_vl_rfs.v" \

vlog -work axis_combiner_v1_1_20  "+incdir+../../../ipstatic/hdl" \
"../../../ipstatic/hdl/axis_combiner_v1_1_vl_rfs.v" \

vlog -work xil_defaultlib  "+incdir+../../../ipstatic/hdl" \
"../../../../testAll.gen/sources_1/ip/axis_combiner_0/sim/axis_combiner_0.v" \


vlog -work xil_defaultlib \
"glbl.v"

