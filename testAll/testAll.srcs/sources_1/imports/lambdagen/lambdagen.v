`timescale 1ns/1ps

module lambdagen#(
    parameter ZWIDTH = 16, // signed 16 
    parameter XWIDTH = 9, // unsigned 9
    parameter YWIDTH = 8, // unsigned 8
    parameter IDWIDTH = 16, // unsigned 16
    parameter LWIDTH = 32 // 24.8 signed fixed point
)
(
    input clk,
    input rst,
    input valid,
    input [127:0] input_bus,
    input stall,
    input [1:0] quad,  

    output [LWIDTH-1:0] l1,
    output [LWIDTH-1:0] l2,
    output [LWIDTH-1:0] dl1x,
    output [LWIDTH-1:0] dl2x,
    output [LWIDTH-1:0] dl1y,
    output [LWIDTH-1:0] dl2y,
    output [LWIDTH-1:0] z_,
    output [LWIDTH-1:0] dzx,
    output [LWIDTH-1:0] dzy,
    output signed [ZWIDTH-1:0] _z1,
    output signed [ZWIDTH-1:0] _z2,
    output signed [ZWIDTH-1:0] _z3,
    output [IDWIDTH-1:0] tID,
    output dovalid,
    output ovalid_s1,
    output ovalid_s2,
    output ovalid_s3,
    output ovalid_s4,
    output ovalid_s5
);

    // Stage 0: Decode input
    reg [IDWIDTH-1:0] tID_s0; //16
    reg signed [XWIDTH-1:0] x1_s0, x2_s0, x3_s0; //9
    reg signed [YWIDTH-1:0] y1_s0, y2_s0, y3_s0; //8
    reg signed [ZWIDTH-1:0] z1_s0, z2_s0, z3_s0; //16

    reg [1:0] quad_reg;

    reg [4:0] __;
    reg [7:0] _;
    
    reg valid_s0; 

    // always @(posedge clk) begin
    //     if (rst) begin
    //         tID_s0 <= 0;
    //         x1_s0 <= 0; x2_s0 <= 0; x3_s0 <= 0;
    //         y1_s0 <= 0; y2_s0 <= 0; y3_s0 <= 0;
    //         z1_s0 <= 0; z2_s0 <= 0; z3_s0 <= 0;
    //         valid_s0 <= 0;
    //     end
    //     else if (valid) begin
    //         {tID_s0, z1_s0, _, y1_s0, y2_s0, y3_s0, __, x1_s0, x2_s0, x3_s0, z2_s0, z3_s0} <= input_bus;
    //         valid_s0 <= 1;
    //     end
    //     else if (stall) begin
    //         valid_s0 <= 0;
    //     end
    // end

    always @(posedge clk) begin
        if (rst) begin
            tID_s0 <= 0; 
            x1_s0 <= 0; 
            x2_s0 <= 0; 
            x3_s0 <= 0;
            y1_s0 <= 0; 
            y2_s0 <= 0; 
            y3_s0 <= 0;
            z1_s0 <= 0; 
            z2_s0 <= 0; 
            z3_s0 <= 0;
            valid_s0 <= 1'b0;
        end else if (!stall) begin
            if (valid) begin
            {tID_s0, z1_s0, _, y1_s0, y2_s0, y3_s0, __, x1_s0, x2_s0, x3_s0, z2_s0, z3_s0} <= input_bus;
            quad_reg <= quad;
            end
            valid_s0 <= valid;
        end
        // else: hold all regs  
    end

    // signals for all the stages
    /*
    input clk,
    input rst,
    input valid,
    input stall,
    input [IDWIDTH-1:0] tID_s0,
    input signed [XWIDTH-1:0] x1_s0, x2_s0, x3_s0,
    input signed [YWIDTH-1:0] y1_s0, y2_s0, y3_s0,
    input signed [ZWIDTH-1:0] z1_s0, z2_s0, z3_s0,
    */
    wire signed [XWIDTH:0] dl1x_s1; 
    wire signed [XWIDTH:0] dl2x_s1; 
    wire signed [YWIDTH:0] dl1y_s1;
    wire signed [YWIDTH:0] dl2y_s1;
    wire signed [XWIDTH-1:0] x1_s1;
    wire signed [XWIDTH-1:0] x2_s1;
    wire signed [YWIDTH-1:0] y1_s1;
    wire signed [YWIDTH-1:0] y2_s1;
    wire signed [ZWIDTH-1:0] z1_s1;
    wire signed [ZWIDTH-1:0] z2_s1;
    wire signed [ZWIDTH-1:0] z3_s1;
    wire [IDWIDTH-1:0] tID_s1;    


    // connect the first stage
    lambdagen_s1 #(.ZWIDTH(ZWIDTH), .XWIDTH(XWIDTH), .YWIDTH(YWIDTH), .IDWIDTH(IDWIDTH)) 
    stage1 (
        .clk(clk),
        .rst(rst),
        .valid(valid_s0),
        .stall(stall), // stall is not used in stage 1
        .tID_s0(tID_s0),
        .quad(quad_reg),
        .x1_s0(x1_s0), .x2_s0(x2_s0), .x3_s0(x3_s0),
        .y1_s0(y1_s0), .y2_s0(y2_s0), .y3_s0(y3_s0),
        .z1_s0(z1_s0), .z2_s0(z2_s0), .z3_s0(z3_s0),
        .dl1x_s1(dl1x_s1), 
        .dl2x_s1(dl2x_s1), 
        .dl1y_s1(dl1y_s1),
        .dl2y_s1(dl2y_s1),
        .x1_s1(x1_s1),
        .x2_s1(x2_s1),
        .y1_s1(y1_s1),
        .y2_s1(y2_s1),
        .z1_s1(z1_s1),
        .z2_s1(z2_s1),
        .z3_s1(z3_s1),
        .tID_s1(tID_s1),
        .ovalid(ovalid_s1)
    );

    wire signed [XWIDTH + YWIDTH + 1:0] x12y1_s2, x23y2_s2, y12x1_s2, y23x2_s2;
    wire signed [XWIDTH + YWIDTH + 2:0] a0_s2, a1_s2;
    wire signed [XWIDTH:0] dl1x_s2, dl2x_s2;
    wire signed [YWIDTH:0] dl1y_s2, dl2y_s2;
    wire signed [ZWIDTH-1:0] z1_s2, z2_s2, z3_s2;
    wire [IDWIDTH-1:0] tID_s2;

    // connect the second stage
    lambdagen_s2 #(.ZWIDTH(ZWIDTH), .XWIDTH(XWIDTH), .YWIDTH(YWIDTH), .IDWIDTH(IDWIDTH)) 
    stage2 (
        .clk(clk),
        .rst(rst),
        .dl1x_s1(dl1x_s1), .dl2x_s1(dl2x_s1), 
        .dl1y_s1(dl1y_s1),
        .dl2y_s1(dl2y_s1),
        .x1_s1(x1_s1), .x2_s1(x2_s1),
        .y1_s1(y1_s1), .y2_s1(y2_s1),
        .z1_s1(z1_s1), .z2_s1(z2_s1), .z3_s1(z3_s1),
        .valid(ovalid_s1),
        .stall(stall),
        .tID_s1(tID_s1),
        .x12y1_s2(x12y1_s2), .x23y2_s2(x23y2_s2), 
        .y12x1_s2(y12x1_s2), .y23x2_s2(y23x2_s2),
        .a0_s2(a0_s2), .a1_s2(a1_s2),
        .dl1x_s2(dl1x_s2), .dl2x_s2(dl2x_s2), 
        .dl1y_s2(dl1y_s2),
        .dl2y_s2(dl2y_s2),
        .z1_s2(z1_s2), .z2_s2(z2_s2), .z3_s2(z3_s2),
        .tID_s2(tID_s2),
        .ovalid(ovalid_s2)
    );

    //declarations for stage 3
    wire signed [31:0] E1_s3, E2_s3, area_s3;
    wire [IDWIDTH-1:0] tID_s3;
    wire signed [XWIDTH:0] dl1x_s3, dl2x_s3;
    wire signed [YWIDTH:0] dl1y_s3, dl2y_s3;
    wire signed [ZWIDTH-1:0] z1_s3, z2_s3, z3_s3;
    
    // connect the third stage
    lambdagen_s3 #(.ZWIDTH(ZWIDTH), .XWIDTH(XWIDTH), .YWIDTH(YWIDTH), .IDWIDTH(IDWIDTH)) 
    stage3 (
        .clk(clk),
        .rst(rst),
        .x12y1_s2(x12y1_s2), .x23y2_s2(x23y2_s2), 
        .y12x1_s2(y12x1_s2), .y23x2_s2(y23x2_s2), 
        .a0_s2(a0_s2), .a1_s2(a1_s2),
        .dl1x_s2(dl1x_s2), .dl2x_s2(dl2x_s2), 
        .dl1y_s2(dl1y_s2),
        .dl2y_s2(dl2y_s2),
        .z1_s2(z1_s2), .z2_s2(z2_s2), .z3_s2(z3_s2),
        .tID_s2(tID_s2),
        .valid(ovalid_s2),
        .stall(stall),
        .E1_s3(E1_s3), .E2_s3(E2_s3), .area_s3(area_s3),
        .tID_s3(tID_s3),
        .dl1x_s3(dl1x_s3), .dl2x_s3(dl2x_s3),
        .dl1y_s3(dl1y_s3), .dl2y_s3(dl2y_s3),
        .z1_s3(z1_s3), .z2_s3(z2_s3), .z3_s3(z3_s3),
        .ovalid(ovalid_s3)
    );

    //declarations for stage 4
    wire signed [31:0] l1_s4, l2_s4, dl1x_s4, dl2x_s4, dl1y_s4, dl2y_s4;
    wire signed [ZWIDTH-1:0] z1_s4, z2_s4, z3_s4;
    wire [IDWIDTH-1:0] tID_s4;

    // connect the fourth stage
    lambdagen_s4 #(.ZWIDTH(ZWIDTH), .XWIDTH(XWIDTH), .YWIDTH(YWIDTH), .IDWIDTH(IDWIDTH)) 
    stage4 (
        .clk(clk),
        .rst(rst),
        .E1_s3(E1_s3), .E2_s3(E2_s3), .area_s3(area_s3),
        .z1_s3(z1_s3), .z2_s3(z2_s3), .z3_s3(z3_s3),
        .tID_s3(tID_s3),
        .dl1x_s3(dl1x_s3), .dl2x_s3(dl2x_s3),
        .dl1y_s3(dl1y_s3), .dl2y_s3(dl2y_s3),
        .valid(ovalid_s3),
        .stall(stall),
        .l1_s4(l1_s4), .l2_s4(l2_s4),
        .dl1x_s4(dl1x_s4), .dl2x_s4(dl2x_s4),
        .dl1y_s4(dl1y_s4),
        .dl2y_s4(dl2y_s4),
        .z1_s4(z1_s4),
        .z2_s4(z2_s4),
        .z3_s4(z3_s4),
        .tID_s4(tID_s4),
        .ovalid(ovalid_s4)
    );

    //declarations for stage 5
    wire signed [31:0] l1z1_s5, l2z2_s5, l3z3_s5;
    wire signed [31:0] dlx1z1_s5, dlx2z2_s5, dlx3z3_s5;
    wire signed [31:0] dly1z1_s5, dly2z2_s5, dly3z3_s5;
    wire signed [ZWIDTH-1:0] z1_s5, z2_s5, z3_s5;   
    wire signed [31:0] dl1x_s5, dl2x_s5;
    wire signed [31:0] dl1y_s5, dl2y_s5;
    wire [31:0] l1_s5, l2_s5; 
    wire [IDWIDTH-1:0] tID_s5;

    // connect the fifth stage
    lambdagen_s5 #(.ZWIDTH(ZWIDTH), .XWIDTH(XWIDTH), .YWIDTH(YWIDTH), .IDWIDTH(IDWIDTH)) 
    stage5 (
        .clk(clk),
        .rst(rst),
        .l1_s4(l1_s4), .l2_s4(l2_s4),
        .dl1x_s4(dl1x_s4), .dl2x_s4(dl2x_s4),
        .dl1y_s4(dl1y_s4),
        .dl2y_s4(dl2y_s4),
        .z1_s4(z1_s4), .z2_s4(z2_s4), .z3_s4(z3_s4),
        .tID_s4(tID_s4),
        .valid(ovalid_s4),
        .stall(stall),
        .l1z1_s5(l1z1_s5), .l2z2_s5(l2z2_s5), .l3z3_s5(l3z3_s5),
        .dlx1z1_s5(dlx1z1_s5), .dlx2z2_s5(dlx2z2_s5), .dlx3z3_s5(dlx3z3_s5),
        .dly1z1_s5(dly1z1_s5), .dly2z2_s5(dly2z2_s5), .dly3z3_s5(dly3z3_s5),
        .l1_s5(l1_s5), .l2_s5(l2_s5),
        .dl1x_s5(dl1x_s5), .dl2x_s5(dl2x_s5),
        .dl1y_s5(dl1y_s5), .dl2y_s5(dl2y_s5),
        .z1_s5(z1_s5), .z2_s5(z2_s5), .z3_s5(z3_s5),
        .tID_s5(tID_s5),
        .ovalid(ovalid_s5)
    );

    //declarations for output stage

    lambdagen_s6 #(.ZWIDTH(ZWIDTH), .XWIDTH(XWIDTH), .YWIDTH(YWIDTH), .IDWIDTH(IDWIDTH))
    stage6 (
        .clk(clk),
        .rst(rst),
        .l1z1_s5(l1z1_s5), .l2z2_s5(l2z2_s5), .l3z3_s5(l3z3_s5),
        .dlx1z1_s5(dlx1z1_s5), .dlx2z2_s5(dlx2z2_s5), .dlx3z3_s5(dlx3z3_s5),
        .dly1z1_s5(dly1z1_s5), .dly2z2_s5(dly2z2_s5), .dly3z3_s5(dly3z3_s5),
        .l1_s5(l1_s5), .l2_s5(l2_s5),
        .dl1x_s5(dl1x_s5), .dl2x_s5(dl2x_s5),
        .dl1y_s5(dl1y_s5), .dl2y_s5(dl2y_s5),
        .z1_s5(z1_s5), .z2_s5(z2_s5), .z3_s5(z3_s5),
        .tID_s5(tID_s5),
        .valid(ovalid_s5),
        .stall(stall),
        .z_(z_),
        .dzx(dzx),
        .dzy(dzy),
        .l1_s6(l1),
        .l2_s6(l2),
        .dl1x_s6(dl1x),
        .dl2x_s6(dl2x),
        .dl1y_s6(dl1y),
        .dl2y_s6(dl2y),
        .z1_s6(_z1),
        .z2_s6(_z2),
        .z3_s6(_z3),
        .tID_s6(tID),
        .ovalid(dovalid)
    );

endmodule
