vlib modelsim_lib/work
vlib modelsim_lib/msim

vlib modelsim_lib/msim/xilinx_vip
vlib modelsim_lib/msim/xpm
vlib modelsim_lib/msim/xil_defaultlib
vlib modelsim_lib/msim/lib_pkg_v1_0_2
vlib modelsim_lib/msim/fifo_generator_v13_2_5
vlib modelsim_lib/msim/lib_fifo_v1_0_14
vlib modelsim_lib/msim/lib_srl_fifo_v1_0_2
vlib modelsim_lib/msim/lib_cdc_v1_0_2
vlib modelsim_lib/msim/axi_datamover_v5_1_24
vlib modelsim_lib/msim/axi_sg_v4_1_13
vlib modelsim_lib/msim/axi_dma_v7_1_23
vlib modelsim_lib/msim/axi_infrastructure_v1_1_0
vlib modelsim_lib/msim/axi_vip_v1_1_8
vlib modelsim_lib/msim/processing_system7_vip_v1_0_10
vlib modelsim_lib/msim/proc_sys_reset_v5_0_13
vlib modelsim_lib/msim/xlconstant_v1_1_7
vlib modelsim_lib/msim/smartconnect_v1_0
vlib modelsim_lib/msim/axi_register_slice_v2_1_22

vmap xilinx_vip modelsim_lib/msim/xilinx_vip
vmap xpm modelsim_lib/msim/xpm
vmap xil_defaultlib modelsim_lib/msim/xil_defaultlib
vmap lib_pkg_v1_0_2 modelsim_lib/msim/lib_pkg_v1_0_2
vmap fifo_generator_v13_2_5 modelsim_lib/msim/fifo_generator_v13_2_5
vmap lib_fifo_v1_0_14 modelsim_lib/msim/lib_fifo_v1_0_14
vmap lib_srl_fifo_v1_0_2 modelsim_lib/msim/lib_srl_fifo_v1_0_2
vmap lib_cdc_v1_0_2 modelsim_lib/msim/lib_cdc_v1_0_2
vmap axi_datamover_v5_1_24 modelsim_lib/msim/axi_datamover_v5_1_24
vmap axi_sg_v4_1_13 modelsim_lib/msim/axi_sg_v4_1_13
vmap axi_dma_v7_1_23 modelsim_lib/msim/axi_dma_v7_1_23
vmap axi_infrastructure_v1_1_0 modelsim_lib/msim/axi_infrastructure_v1_1_0
vmap axi_vip_v1_1_8 modelsim_lib/msim/axi_vip_v1_1_8
vmap processing_system7_vip_v1_0_10 modelsim_lib/msim/processing_system7_vip_v1_0_10
vmap proc_sys_reset_v5_0_13 modelsim_lib/msim/proc_sys_reset_v5_0_13
vmap xlconstant_v1_1_7 modelsim_lib/msim/xlconstant_v1_1_7
vmap smartconnect_v1_0 modelsim_lib/msim/smartconnect_v1_0
vmap axi_register_slice_v2_1_22 modelsim_lib/msim/axi_register_slice_v2_1_22

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

vlog -work xpm  -incr -sv -L axi_vip_v1_1_8 -L processing_system7_vip_v1_0_10 -L smartconnect_v1_0 -L xilinx_vip "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/34f8/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/25b7/hdl/verilog" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/896c/hdl/verilog" "+incdir+C:/Xilinx/Vivado/2020.2/data/xilinx_vip/include" \
"C:/Xilinx/Vivado/2020.2/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \

vcom -work xpm  -93 \
"C:/Xilinx/Vivado/2020.2/data/ip/xpm/xpm_VCOMP.vhd" \

vlog -work xil_defaultlib  -incr "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/34f8/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/25b7/hdl/verilog" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/896c/hdl/verilog" "+incdir+C:/Xilinx/Vivado/2020.2/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_repeater_0_0/sim/design_1_repeater_0_0.v" \

vcom -work lib_pkg_v1_0_2  -93 \
"../../../../testAll.gen/sources_1/bd/design_1/ipshared/0513/hdl/lib_pkg_v1_0_rfs.vhd" \

vlog -work fifo_generator_v13_2_5  -incr "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/34f8/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/25b7/hdl/verilog" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/896c/hdl/verilog" "+incdir+C:/Xilinx/Vivado/2020.2/data/xilinx_vip/include" \
"../../../../testAll.gen/sources_1/bd/design_1/ipshared/276e/simulation/fifo_generator_vlog_beh.v" \

vcom -work fifo_generator_v13_2_5  -93 \
"../../../../testAll.gen/sources_1/bd/design_1/ipshared/276e/hdl/fifo_generator_v13_2_rfs.vhd" \

vlog -work fifo_generator_v13_2_5  -incr "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/34f8/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/25b7/hdl/verilog" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/896c/hdl/verilog" "+incdir+C:/Xilinx/Vivado/2020.2/data/xilinx_vip/include" \
"../../../../testAll.gen/sources_1/bd/design_1/ipshared/276e/hdl/fifo_generator_v13_2_rfs.v" \

vcom -work lib_fifo_v1_0_14  -93 \
"../../../../testAll.gen/sources_1/bd/design_1/ipshared/a5cb/hdl/lib_fifo_v1_0_rfs.vhd" \

vcom -work lib_srl_fifo_v1_0_2  -93 \
"../../../../testAll.gen/sources_1/bd/design_1/ipshared/51ce/hdl/lib_srl_fifo_v1_0_rfs.vhd" \

vcom -work lib_cdc_v1_0_2  -93 \
"../../../../testAll.gen/sources_1/bd/design_1/ipshared/ef1e/hdl/lib_cdc_v1_0_rfs.vhd" \

vcom -work axi_datamover_v5_1_24  -93 \
"../../../../testAll.gen/sources_1/bd/design_1/ipshared/4ab6/hdl/axi_datamover_v5_1_vh_rfs.vhd" \

vcom -work axi_sg_v4_1_13  -93 \
"../../../../testAll.gen/sources_1/bd/design_1/ipshared/4919/hdl/axi_sg_v4_1_rfs.vhd" \

vcom -work axi_dma_v7_1_23  -93 \
"../../../../testAll.gen/sources_1/bd/design_1/ipshared/89d8/hdl/axi_dma_v7_1_vh_rfs.vhd" \

vcom -work xil_defaultlib  -93 \
"../../../bd/design_1/ip/design_1_axi_dma_0_0/sim/design_1_axi_dma_0_0.vhd" \

vlog -work axi_infrastructure_v1_1_0  -incr "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/34f8/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/25b7/hdl/verilog" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/896c/hdl/verilog" "+incdir+C:/Xilinx/Vivado/2020.2/data/xilinx_vip/include" \
"../../../../testAll.gen/sources_1/bd/design_1/ipshared/ec67/hdl/axi_infrastructure_v1_1_vl_rfs.v" \

vlog -work axi_vip_v1_1_8  -incr -sv -L axi_vip_v1_1_8 -L processing_system7_vip_v1_0_10 -L smartconnect_v1_0 -L xilinx_vip "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/34f8/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/25b7/hdl/verilog" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/896c/hdl/verilog" "+incdir+C:/Xilinx/Vivado/2020.2/data/xilinx_vip/include" \
"../../../../testAll.gen/sources_1/bd/design_1/ipshared/94c3/hdl/axi_vip_v1_1_vl_rfs.sv" \

vlog -work processing_system7_vip_v1_0_10  -incr -sv -L axi_vip_v1_1_8 -L processing_system7_vip_v1_0_10 -L smartconnect_v1_0 -L xilinx_vip "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/34f8/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/25b7/hdl/verilog" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/896c/hdl/verilog" "+incdir+C:/Xilinx/Vivado/2020.2/data/xilinx_vip/include" \
"../../../../testAll.gen/sources_1/bd/design_1/ipshared/34f8/hdl/processing_system7_vip_v1_0_vl_rfs.sv" \

vlog -work xil_defaultlib  -incr "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/34f8/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/25b7/hdl/verilog" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/896c/hdl/verilog" "+incdir+C:/Xilinx/Vivado/2020.2/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_processing_system7_0_0/sim/design_1_processing_system7_0_0.v" \

vcom -work proc_sys_reset_v5_0_13  -93 \
"../../../../testAll.gen/sources_1/bd/design_1/ipshared/8842/hdl/proc_sys_reset_v5_0_vh_rfs.vhd" \

vcom -work xil_defaultlib  -93 \
"../../../bd/design_1/ip/design_1_rst_ps7_0_50M_0/sim/design_1_rst_ps7_0_50M_0.vhd" \

vlog -work xlconstant_v1_1_7  -incr "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/34f8/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/25b7/hdl/verilog" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/896c/hdl/verilog" "+incdir+C:/Xilinx/Vivado/2020.2/data/xilinx_vip/include" \
"../../../../testAll.gen/sources_1/bd/design_1/ipshared/fcfc/hdl/xlconstant_v1_1_vl_rfs.v" \

vlog -work xil_defaultlib  -incr "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/34f8/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/25b7/hdl/verilog" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/896c/hdl/verilog" "+incdir+C:/Xilinx/Vivado/2020.2/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_smartconnect_0_1/bd_0/ip/ip_0/sim/bd_886d_one_0.v" \

vcom -work xil_defaultlib  -93 \
"../../../bd/design_1/ip/design_1_smartconnect_0_1/bd_0/ip/ip_1/sim/bd_886d_psr_aclk_0.vhd" \

vlog -work smartconnect_v1_0  -incr -sv -L axi_vip_v1_1_8 -L processing_system7_vip_v1_0_10 -L smartconnect_v1_0 -L xilinx_vip "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/34f8/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/25b7/hdl/verilog" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/896c/hdl/verilog" "+incdir+C:/Xilinx/Vivado/2020.2/data/xilinx_vip/include" \
"../../../../testAll.gen/sources_1/bd/design_1/ipshared/25b7/hdl/sc_util_v1_0_vl_rfs.sv" \
"../../../../testAll.gen/sources_1/bd/design_1/ipshared/c012/hdl/sc_switchboard_v1_0_vl_rfs.sv" \

vlog -work xil_defaultlib  -incr -sv -L axi_vip_v1_1_8 -L processing_system7_vip_v1_0_10 -L smartconnect_v1_0 -L xilinx_vip "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/34f8/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/25b7/hdl/verilog" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/896c/hdl/verilog" "+incdir+C:/Xilinx/Vivado/2020.2/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_smartconnect_0_1/bd_0/ip/ip_2/sim/bd_886d_arsw_0.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_1/bd_0/ip/ip_3/sim/bd_886d_rsw_0.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_1/bd_0/ip/ip_4/sim/bd_886d_awsw_0.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_1/bd_0/ip/ip_5/sim/bd_886d_wsw_0.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_1/bd_0/ip/ip_6/sim/bd_886d_bsw_0.sv" \

vlog -work smartconnect_v1_0  -incr -sv -L axi_vip_v1_1_8 -L processing_system7_vip_v1_0_10 -L smartconnect_v1_0 -L xilinx_vip "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/34f8/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/25b7/hdl/verilog" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/896c/hdl/verilog" "+incdir+C:/Xilinx/Vivado/2020.2/data/xilinx_vip/include" \
"../../../../testAll.gen/sources_1/bd/design_1/ipshared/ea34/hdl/sc_mmu_v1_0_vl_rfs.sv" \

vlog -work xil_defaultlib  -incr -sv -L axi_vip_v1_1_8 -L processing_system7_vip_v1_0_10 -L smartconnect_v1_0 -L xilinx_vip "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/34f8/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/25b7/hdl/verilog" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/896c/hdl/verilog" "+incdir+C:/Xilinx/Vivado/2020.2/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_smartconnect_0_1/bd_0/ip/ip_7/sim/bd_886d_s00mmu_0.sv" \

vlog -work smartconnect_v1_0  -incr -sv -L axi_vip_v1_1_8 -L processing_system7_vip_v1_0_10 -L smartconnect_v1_0 -L xilinx_vip "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/34f8/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/25b7/hdl/verilog" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/896c/hdl/verilog" "+incdir+C:/Xilinx/Vivado/2020.2/data/xilinx_vip/include" \
"../../../../testAll.gen/sources_1/bd/design_1/ipshared/4fd2/hdl/sc_transaction_regulator_v1_0_vl_rfs.sv" \

vlog -work xil_defaultlib  -incr -sv -L axi_vip_v1_1_8 -L processing_system7_vip_v1_0_10 -L smartconnect_v1_0 -L xilinx_vip "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/34f8/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/25b7/hdl/verilog" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/896c/hdl/verilog" "+incdir+C:/Xilinx/Vivado/2020.2/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_smartconnect_0_1/bd_0/ip/ip_8/sim/bd_886d_s00tr_0.sv" \

vlog -work smartconnect_v1_0  -incr -sv -L axi_vip_v1_1_8 -L processing_system7_vip_v1_0_10 -L smartconnect_v1_0 -L xilinx_vip "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/34f8/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/25b7/hdl/verilog" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/896c/hdl/verilog" "+incdir+C:/Xilinx/Vivado/2020.2/data/xilinx_vip/include" \
"../../../../testAll.gen/sources_1/bd/design_1/ipshared/8047/hdl/sc_si_converter_v1_0_vl_rfs.sv" \

vlog -work xil_defaultlib  -incr -sv -L axi_vip_v1_1_8 -L processing_system7_vip_v1_0_10 -L smartconnect_v1_0 -L xilinx_vip "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/34f8/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/25b7/hdl/verilog" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/896c/hdl/verilog" "+incdir+C:/Xilinx/Vivado/2020.2/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_smartconnect_0_1/bd_0/ip/ip_9/sim/bd_886d_s00sic_0.sv" \

vlog -work smartconnect_v1_0  -incr -sv -L axi_vip_v1_1_8 -L processing_system7_vip_v1_0_10 -L smartconnect_v1_0 -L xilinx_vip "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/34f8/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/25b7/hdl/verilog" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/896c/hdl/verilog" "+incdir+C:/Xilinx/Vivado/2020.2/data/xilinx_vip/include" \
"../../../../testAll.gen/sources_1/bd/design_1/ipshared/b89e/hdl/sc_axi2sc_v1_0_vl_rfs.sv" \

vlog -work xil_defaultlib  -incr -sv -L axi_vip_v1_1_8 -L processing_system7_vip_v1_0_10 -L smartconnect_v1_0 -L xilinx_vip "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/34f8/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/25b7/hdl/verilog" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/896c/hdl/verilog" "+incdir+C:/Xilinx/Vivado/2020.2/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_smartconnect_0_1/bd_0/ip/ip_10/sim/bd_886d_s00a2s_0.sv" \

vlog -work smartconnect_v1_0  -incr -sv -L axi_vip_v1_1_8 -L processing_system7_vip_v1_0_10 -L smartconnect_v1_0 -L xilinx_vip "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/34f8/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/25b7/hdl/verilog" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/896c/hdl/verilog" "+incdir+C:/Xilinx/Vivado/2020.2/data/xilinx_vip/include" \
"../../../../testAll.gen/sources_1/bd/design_1/ipshared/896c/hdl/sc_node_v1_0_vl_rfs.sv" \

vlog -work xil_defaultlib  -incr -sv -L axi_vip_v1_1_8 -L processing_system7_vip_v1_0_10 -L smartconnect_v1_0 -L xilinx_vip "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/34f8/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/25b7/hdl/verilog" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/896c/hdl/verilog" "+incdir+C:/Xilinx/Vivado/2020.2/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_smartconnect_0_1/bd_0/ip/ip_11/sim/bd_886d_sarn_0.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_1/bd_0/ip/ip_12/sim/bd_886d_srn_0.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_1/bd_0/ip/ip_13/sim/bd_886d_s01mmu_0.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_1/bd_0/ip/ip_14/sim/bd_886d_s01tr_0.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_1/bd_0/ip/ip_15/sim/bd_886d_s01sic_0.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_1/bd_0/ip/ip_16/sim/bd_886d_s01a2s_0.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_1/bd_0/ip/ip_17/sim/bd_886d_sawn_0.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_1/bd_0/ip/ip_18/sim/bd_886d_swn_0.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_1/bd_0/ip/ip_19/sim/bd_886d_sbn_0.sv" \

vlog -work smartconnect_v1_0  -incr -sv -L axi_vip_v1_1_8 -L processing_system7_vip_v1_0_10 -L smartconnect_v1_0 -L xilinx_vip "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/34f8/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/25b7/hdl/verilog" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/896c/hdl/verilog" "+incdir+C:/Xilinx/Vivado/2020.2/data/xilinx_vip/include" \
"../../../../testAll.gen/sources_1/bd/design_1/ipshared/7005/hdl/sc_sc2axi_v1_0_vl_rfs.sv" \

vlog -work xil_defaultlib  -incr -sv -L axi_vip_v1_1_8 -L processing_system7_vip_v1_0_10 -L smartconnect_v1_0 -L xilinx_vip "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/34f8/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/25b7/hdl/verilog" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/896c/hdl/verilog" "+incdir+C:/Xilinx/Vivado/2020.2/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_smartconnect_0_1/bd_0/ip/ip_20/sim/bd_886d_m00s2a_0.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_1/bd_0/ip/ip_21/sim/bd_886d_m00arn_0.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_1/bd_0/ip/ip_22/sim/bd_886d_m00rn_0.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_1/bd_0/ip/ip_23/sim/bd_886d_m00awn_0.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_1/bd_0/ip/ip_24/sim/bd_886d_m00wn_0.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_1/bd_0/ip/ip_25/sim/bd_886d_m00bn_0.sv" \

vlog -work smartconnect_v1_0  -incr -sv -L axi_vip_v1_1_8 -L processing_system7_vip_v1_0_10 -L smartconnect_v1_0 -L xilinx_vip "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/34f8/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/25b7/hdl/verilog" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/896c/hdl/verilog" "+incdir+C:/Xilinx/Vivado/2020.2/data/xilinx_vip/include" \
"../../../../testAll.gen/sources_1/bd/design_1/ipshared/7bd7/hdl/sc_exit_v1_0_vl_rfs.sv" \

vlog -work xil_defaultlib  -incr -sv -L axi_vip_v1_1_8 -L processing_system7_vip_v1_0_10 -L smartconnect_v1_0 -L xilinx_vip "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/34f8/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/25b7/hdl/verilog" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/896c/hdl/verilog" "+incdir+C:/Xilinx/Vivado/2020.2/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_smartconnect_0_1/bd_0/ip/ip_26/sim/bd_886d_m00e_0.sv" \

vlog -work xil_defaultlib  -incr "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/34f8/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/25b7/hdl/verilog" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/896c/hdl/verilog" "+incdir+C:/Xilinx/Vivado/2020.2/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_smartconnect_0_1/bd_0/sim/bd_886d.v" \

vlog -work axi_register_slice_v2_1_22  -incr "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/34f8/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/25b7/hdl/verilog" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/896c/hdl/verilog" "+incdir+C:/Xilinx/Vivado/2020.2/data/xilinx_vip/include" \
"../../../../testAll.gen/sources_1/bd/design_1/ipshared/af2c/hdl/axi_register_slice_v2_1_vl_rfs.v" \

vlog -work xil_defaultlib  -incr "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/34f8/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/25b7/hdl/verilog" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/896c/hdl/verilog" "+incdir+C:/Xilinx/Vivado/2020.2/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_smartconnect_0_1/sim/design_1_smartconnect_0_1.v" \
"../../../bd/design_1/ip/design_1_smartconnect_0_2/bd_0/ip/ip_0/sim/bd_892d_one_0.v" \

vcom -work xil_defaultlib  -93 \
"../../../bd/design_1/ip/design_1_smartconnect_0_2/bd_0/ip/ip_1/sim/bd_892d_psr_aclk_0.vhd" \

vlog -work xil_defaultlib  -incr -sv -L axi_vip_v1_1_8 -L processing_system7_vip_v1_0_10 -L smartconnect_v1_0 -L xilinx_vip "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/34f8/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/25b7/hdl/verilog" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/896c/hdl/verilog" "+incdir+C:/Xilinx/Vivado/2020.2/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_smartconnect_0_2/bd_0/ip/ip_2/sim/bd_892d_s00mmu_0.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_2/bd_0/ip/ip_3/sim/bd_892d_s00tr_0.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_2/bd_0/ip/ip_4/sim/bd_892d_s00sic_0.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_2/bd_0/ip/ip_5/sim/bd_892d_s00a2s_0.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_2/bd_0/ip/ip_6/sim/bd_892d_sarn_0.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_2/bd_0/ip/ip_7/sim/bd_892d_srn_0.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_2/bd_0/ip/ip_8/sim/bd_892d_sawn_0.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_2/bd_0/ip/ip_9/sim/bd_892d_swn_0.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_2/bd_0/ip/ip_10/sim/bd_892d_sbn_0.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_2/bd_0/ip/ip_11/sim/bd_892d_m00s2a_0.sv" \
"../../../bd/design_1/ip/design_1_smartconnect_0_2/bd_0/ip/ip_12/sim/bd_892d_m00e_0.sv" \

vlog -work xil_defaultlib  -incr "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/34f8/hdl" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/25b7/hdl/verilog" "+incdir+../../../../testAll.gen/sources_1/bd/design_1/ipshared/896c/hdl/verilog" "+incdir+C:/Xilinx/Vivado/2020.2/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_smartconnect_0_2/bd_0/sim/bd_892d.v" \
"../../../bd/design_1/ip/design_1_smartconnect_0_2/sim/design_1_smartconnect_0_2.v" \
"../../../bd/design_1/sim/design_1.v" \

vlog -work xil_defaultlib \
"glbl.v"

