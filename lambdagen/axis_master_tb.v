// `timescale 1ns/1ps

// module tb_axi_stream_master;

// localparam DATA_W = 32;
// localparam ADDR_W = 12;

// // DUT Inputs
// reg clk = 0;
// reg resetn = 0;
// reg tready = 0;
// reg lg_valid = 0;
// reg [DATA_W-1:0] src_data = 0;

// // DUT Outputs
// wire [DATA_W-1:0] tdata;
// wire [(DATA_W/8)-1:0] tstrb;
// wire tlast;
// wire tvalid;
// wire [ADDR_W-1:0] src_addr;
// wire src_enable;
// wire lg_stall;

// // Instantiate DUT
// AXI_STREAM_MASTER #(
//     .C_S_AXIS_TDATA_WIDTH(DATA_W),
//     .SRC_ADDR_WIDTH(ADDR_W)
// ) dut (
//     .S_AXIS_ACLK(clk),
//     .S_AXIS_ARESETN(resetn),
//     .S_AXIS_TREADY(tready),
//     .S_AXIS_TDATA(tdata),
//     .S_AXIS_TSTRB(tstrb),
//     .S_AXIS_TLAST(tlast),
//     .S_AXIS_TVALID(tvalid),
//     .src_addr(src_addr),
//     .src_enable(src_enable),
//     .src_data(src_data),
//     .lg_valid(lg_valid),
//     .lg_stall(lg_stall)
// );

// // Clock
// always #5 clk = ~clk;

// // Upstream source model
// // Generates 9 words each time lg_stall deasserts and lg_valid goes high
// integer burst_cnt = 0;
// reg [31:0] burst_base = 32'hA0000000;

// always @(posedge clk) begin
//     if (!resetn) begin
//         src_data <= 0;
//         burst_cnt <= 0;
//         lg_valid <= 0;
//     end else begin
//         if (!lg_stall && burst_cnt == 0) begin
//             // Upstream announces new burst ready
//             burst_cnt <= 9;
//             burst_base <= burst_base + 32'h100; // unique base for each burst
//             lg_valid <= 1;
//         end

//         if (burst_cnt > 0) begin
//             // Data for current address
//             src_data <= burst_base + src_addr;
//         end

//         // drop lg_valid after 1 cycle pulse
//         if (lg_valid)
//             lg_valid <= 0;

//         // count down once streaming starts
//         if (tvalid && tready && burst_cnt > 0)
//             burst_cnt <= burst_cnt - 1;
//     end
// end

// // Downstream sink: random READY behavior
// always @(posedge clk) begin
//     if (!resetn)
//         tready <= 0;
//     else
//         tready <= ($random % 3) != 0; // 2/3 chance ready
// end

// // Monitor output
// always @(posedge clk) begin
//     if (tvalid && tready) begin
//         $display("[%0t] DATA %h LAST=%b ADDR=%0d",
//                  $time, tdata, tlast, src_addr);

//         if (tlast && src_addr != 8)
//             $display("** ERROR TLAST not on 8! addr=%0d", src_addr);
//     end
// end

// initial begin
//     $dumpfile("wave.vcd");
//     $dumpvars(0, tb_axi_stream_master);

//     // Reset
//     resetn <= 0;
//     repeat (10) @(posedge clk);
//     resetn <= 1;

//     // Run simulation
//     repeat (200) @(posedge clk);

//     $display("Simulation complete");
//     $finish;
// end

// endmodule
