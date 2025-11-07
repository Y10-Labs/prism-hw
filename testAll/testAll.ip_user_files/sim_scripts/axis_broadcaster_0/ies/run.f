-makelib ies_lib/axis_infrastructure_v1_1_0 \
  "../../../ipstatic/hdl/axis_infrastructure_v1_1_vl_rfs.v" \
-endlib
-makelib ies_lib/xil_defaultlib \
  "../../../../testAll.gen/sources_1/ip/axis_broadcaster_0/hdl/tdata_axis_broadcaster_0.v" \
  "../../../../testAll.gen/sources_1/ip/axis_broadcaster_0/hdl/tuser_axis_broadcaster_0.v" \
-endlib
-makelib ies_lib/axis_broadcaster_v1_1_21 \
  "../../../ipstatic/hdl/axis_broadcaster_v1_1_vl_rfs.v" \
-endlib
-makelib ies_lib/xil_defaultlib \
  "../../../../testAll.gen/sources_1/ip/axis_broadcaster_0/hdl/top_axis_broadcaster_0.v" \
  "../../../../testAll.gen/sources_1/ip/axis_broadcaster_0/sim/axis_broadcaster_0.v" \
-endlib
-makelib ies_lib/xil_defaultlib \
  glbl.v
-endlib

