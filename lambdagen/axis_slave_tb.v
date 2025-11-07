// `timescale 1ns/1ps

// module tb_axis_deser32to128;

//     parameter DATA_W = 32;

//     reg                 aclk;
//     reg                 aresetn;

//     // AXIS IN
//     reg  [DATA_W-1:0]   s_tdata;
//     reg                 s_tvalid;
//     wire                s_tready;
//     reg                 s_tlast;

//     // OUTPUT
//     wire [4*DATA_W-1:0] m_data128;
//     wire                m_valid;
//     reg                 m_ready;

//     // Instantiate DUT
//     axis_deser32to128 dut(
//         .aclk(aclk),
//         .aresetn(aresetn),
//         .s_tdata(s_tdata),
//         .s_tvalid(s_tvalid),
//         .s_tready(s_tready),
//         .s_tlast(s_tlast),
//         .m_data128(m_data128),
//         .m_valid(m_valid),
//         .m_ready(m_ready)
//     );

//     // Clock
//     initial aclk = 0;
//     always #5 aclk = ~aclk; // 100 MHz

//     integer i;
//     reg [127:0] expected;

//     initial begin
//         $display("Starting test...");
//         $dumpfile("axi_stream_slave.vcd");
//         $dumpvars(0, tb_axis_deser32to128);
//         // Init
//         aresetn   = 0;
//         s_tdata   = 0;
//         s_tvalid  = 0;
//         s_tlast   = 0;
//         m_ready   = 1;

//         #100;
//         aresetn = 1;
//         #20;

//         // Send 4 words
//         send_word(32'h11111111);
//         send_word(32'h22222222);
//         send_word(32'h33333333);
//         send_word(32'h44444444);

//         // Wait for DUT output
//         wait(m_valid);
//         expected = {32'h11111111, 32'h22222222, 32'h33333333, 32'h44444444};

//         if (m_data128 !== expected) begin
//             $display("FAIL: expected %h, got %h", expected, m_data128);
//             $stop;
//         end else begin
//             $display("PASS burst 1");
//         end

//         // Apply backpressure and send again
//         m_ready = 0;
//         repeat(5) @(posedge aclk);
//         m_ready = 1;

//         send_word(32'hAAAA0001);
//         send_word(32'hAAAA0002);
//         send_word(32'hAAAA0003);
//         send_word(32'hAAAA0004);

//         wait(m_valid);
//         expected = {32'hAAAA0001, 32'hAAAA0002, 32'hAAAA0003, 32'hAAAA0004};

//         if (m_data128 !== expected) begin
//             $display("FAIL under backpressure: %h vs %h", expected, m_data128);
//             $stop;
//         end else begin
//             $display("PASS burst 2 with backpressure");
//         end

//         $display("All tests passed");
//         $finish;
//     end

//     task send_word(input [31:0] data);
//         begin
//             @(posedge aclk);
//             s_tvalid <= 1;
//             s_tdata  <= data;
//             s_tlast  <= 0;
//             wait(s_tready);
//             @(posedge aclk);
//             s_tvalid <= 0;
//         end
//     endtask

// endmodule
