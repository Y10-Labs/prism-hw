`timescale 1ns/1ps

module tb_lambdagen;
    parameter VEC_COUNT = 5;
    reg clk, rst, valid, stall;
    reg [2:0] quad;
    reg [127:0] input_bus;
    wire [31:0] l1, l2, z_;
    wire [31:0] dl1x, dl2x, dl1y, dl2y, dzx, dzy;
    wire signed [15:0] _z1, _z2, _z3;
    wire [15:0] tID;
    wire dovalid, ovalid_s1, ovalid_s2, ovalid_s3, ovalid_s4, ovalid_s5;
    
    reg [127:0] vectors [0:VEC_COUNT-1];
    reg [31:0] exp_l1 [0:VEC_COUNT-1];
    reg [31:0] exp_l2 [0:VEC_COUNT-1];
    reg [31:0] exp_l3 [0:VEC_COUNT-1];
    reg [31:0] exp_z  [0:VEC_COUNT-1];
    reg [31:0] exp_dl1x [0:VEC_COUNT-1];
    reg [31:0] exp_dl2x [0:VEC_COUNT-1];
    reg [31:0] exp_dl1y [0:VEC_COUNT-1];
    reg [31:0] exp_dl2y [0:VEC_COUNT-1];
    reg [31:0] exp_dzx  [0:VEC_COUNT-1];
    reg [31:0] exp_dzy  [0:VEC_COUNT-1];

    lambdagen #(
        .ZWIDTH(16),
        .XWIDTH(9),
        .YWIDTH(8),
        .IDWIDTH(16),
        .LWIDTH(32)
    ) dut (
        .clk(clk),
        .rst(rst),
        .valid(valid),
        .input_bus(input_bus),
        .stall(stall),
        .quad(quad),
        .l1(l1),
        .l2(l2),
        .dl1x(dl1x),
        .dl2x(dl2x),
        .dl1y(dl1y),
        .dl2y(dl2y),
        .z_(z_),
        .dzx(dzx),
        .dzy(dzy),
        ._z1(_z1),
        ._z2(_z2),
        ._z3(_z3),
        .tID(tID),
        .dovalid(dovalid),
        .ovalid_s1(ovalid_s1),
        .ovalid_s2(ovalid_s2),
        .ovalid_s3(ovalid_s3),
        .ovalid_s4(ovalid_s4),
        .ovalid_s5(ovalid_s5)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    integer test_num = 0;
    
    always @(posedge clk) begin
        if (dovalid && test_num < VEC_COUNT) begin
            $display("\n=== Test %0d (tID=%0d) ===", test_num, tID);
            $display("  l1:   Expected=%h Got=%h", exp_l1[test_num], l1);
            $display("  l2:   Expected=%h Got=%h", exp_l2[test_num], l2);
            $display("  z:    Expected=%h Got=%h", exp_z[test_num], z_);
            $display("  dl1x: Expected=%h Got=%h", exp_dl1x[test_num], dl1x);
            $display("  dl2x: Expected=%h Got=%h", exp_dl2x[test_num], dl2x);
            $display("  dl1y: Expected=%h Got=%h", exp_dl1y[test_num], dl1y);
            $display("  dl2y: Expected=%h Got=%h", exp_dl2y[test_num], dl2y);
            $display("  dzx:  Expected=%h Got=%h", exp_dzx[test_num], dzx);
            $display("  dzy:  Expected=%h Got=%h", exp_dzy[test_num], dzy);
            test_num++;
        end
    end

    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_lambdagen);

        $readmemh("vectors.mem", vectors);
        $readmemh("expected_l1.mem", exp_l1);
        $readmemh("expected_l2.mem", exp_l2);
        $readmemh("expected_l3.mem", exp_l3);
        $readmemh("expected_z.mem", exp_z);
        $readmemh("expected_dl1x.mem", exp_dl1x);
        $readmemh("expected_dl2x.mem", exp_dl2x);
        $readmemh("expected_dl1y.mem", exp_dl1y);
        $readmemh("expected_dl2y.mem", exp_dl2y);
        $readmemh("expected_dzx.mem", exp_dzx);
        $readmemh("expected_dzy.mem", exp_dzy);
        
        rst = 1; valid = 0; stall = 0; input_bus = 0; quad = 0;
        repeat(3) @(posedge clk);
        rst = 0;
        @(posedge clk);

        for (int i = 0; i < VEC_COUNT; i++) begin
            #1 input_bus = vectors[i]; 
            quad = 0;
            valid = 1;
            @(posedge clk);
        end
        valid = 0; input_bus = 0;
        
        repeat(20) @(posedge clk);
        
        $finish;
    end

    initial begin
        #10000;
        $display("TIMEOUT");
        $finish;
    end
endmodule