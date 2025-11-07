vlib modelsim_lib/work
vlib modelsim_lib/msim

vlib modelsim_lib/msim/xilinx_vip
vlib modelsim_lib/msim/xpm
vlib modelsim_lib/msim/axis_infrastructure_v1_1_0
vlib modelsim_lib/msim/axis_combiner_v1_1_20
vlib modelsim_lib/msim/xil_defaultlib

vmap xilinx_vip modelsim_lib/msim/xilinx_vip
vmap xpm modelsim_lib/msim/xpm
vmap axis_infrastructure_v1_1_0 modelsim_lib/msim/axis_infrastructure_v1_1_0
vmap axis_combiner_v1_1_20 modelsim_lib/msim/axis_combiner_v1_1_20
vmap xil_defaultlib modelsim_lib/msim/xil_defaultlib

vlog -work xilinx_vip  -incr -sv -L axi_vip_v1_1_8 -L processing_system7_vip_v1_0_10 -L smartconnect_v1_0 -L xilinx_vip "+incdir+C:/Xilinx/Vivado/2020.2/data/xilinx_vip/include" \
"C:/Xilinx/Vivado/2020.2/data/xilinx_vip/hdl/axi4stream_vip_axi4streampc.sv" \
"C:/Xilinx/Vivado/2020.2/data/xilinx_vip/hdl/axi_vip_axi4pc.sv" \
"C:/Xilinx/Vivado/2020.2/data/xilinx_vip/hdl/xil_common_vip_pkg.sv" \
"C:/Xilinx/Vivado/2020.2/data/xilinx_vip/hdl/axi4stream_vip_pkg.sv" \
"C:/Xilinx/Vivado/2020.2/data/xilinx_vip/hdl/axi_vip_pkg.sv" \
"C:/Xilinx/Vivado/2020.2/data/xilinx_vip/hdl/axi4stream_vip_if.sv" \
"C:/Xilinx/Vivado/2020.2/data/xilinx_vip/hdl/axi_vip_if.sv" \
"C:/Xilinx/Vivado/2020.2/data/xilinx_vip/hdl/clk_vip_if.sv" \
"C:/Xilinx/Vivado/2020.2/data/xilinx_vip/hdl/rst_vip_if.sv" \

vlog -work xpm  -incr -sv -L axi_vip_v1_1_8 -L processing_system7_vip_v1_0_10 -L smartconnect_v1_0 -L xilinx_vip "+incdir+../../../ipstatic/hdl" "+incdir+C:/Xilinx/Vivado/2020.2/data/xilinx_vip/include" \
"C:/Xilinx/Vivado/2020.2/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \
"C:/Xilinx/Vivado/2020.2/data/ip/xpm/xpm_fifo/hdl/xpm_fifo.sv" \
"C:/Xilinx/Vivado/2020.2/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" \

vcom -work xpm  -93 \
"C:/Xilinx/Vivado/2020.2/data/ip/xpm/xpm_VCOMP.vhd" \

vlog -work axis_infrastructure_v1_1_0  -incr "+incdir+../../../ipstatic/hdl" "+incdir+C:/Xilinx/Vivado/2020.2/data/xilinx_vip/include" \
"../../../ipstatic/hdl/axis_infrastructure_v1_1_vl_rfs.v" \

vlog -work axis_combiner_v1_1_20  -incr "+incdir+../../../ipstatic/hdl" "+incdir+C:/Xilinx/Vivado/2020.2/data/xilinx_vip/include" \
"../../../ipstatic/hdl/axis_combiner_v1_1_vl_rfs.v" \

vlog -work xil_defaultlib  -incr "+incdir+../../../ipstatic/hdl" "+incdir+C:/Xilinx/Vivado/2020.2/data/xilinx_vip/include" \
"../../../../testAll.gen/sources_1/ip/axis_combiner_1/sim/axis_combiner_1.v" \

vlog -work xil_defaultlib \
"glbl.v"

