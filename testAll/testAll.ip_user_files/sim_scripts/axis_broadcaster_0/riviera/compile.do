vlib work
vlib riviera

vlib riviera/axis_infrastructure_v1_1_0
vlib riviera/xil_defaultlib
vlib riviera/axis_broadcaster_v1_1_21

vmap axis_infrastructure_v1_1_0 riviera/axis_infrastructure_v1_1_0
vmap xil_defaultlib riviera/xil_defaultlib
vmap axis_broadcaster_v1_1_21 riviera/axis_broadcaster_v1_1_21

vlog -work axis_infrastructure_v1_1_0  -v2k5 "+incdir+../../../ipstatic/hdl" \
"../../../ipstatic/hdl/axis_infrastructure_v1_1_vl_rfs.v" \

vlog -work xil_defaultlib  -v2k5 "+incdir+../../../ipstatic/hdl" \
"../../../../testAll.gen/sources_1/ip/axis_broadcaster_0/hdl/tdata_axis_broadcaster_0.v" \
"../../../../testAll.gen/sources_1/ip/axis_broadcaster_0/hdl/tuser_axis_broadcaster_0.v" \

vlog -work axis_broadcaster_v1_1_21  -v2k5 "+incdir+../../../ipstatic/hdl" \
"../../../ipstatic/hdl/axis_broadcaster_v1_1_vl_rfs.v" \

vlog -work xil_defaultlib  -v2k5 "+incdir+../../../ipstatic/hdl" \
"../../../../testAll.gen/sources_1/ip/axis_broadcaster_0/hdl/top_axis_broadcaster_0.v" \
"../../../../testAll.gen/sources_1/ip/axis_broadcaster_0/sim/axis_broadcaster_0.v" \

vlog -work xil_defaultlib \
"glbl.v"

