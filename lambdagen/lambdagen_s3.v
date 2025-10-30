module lambdagen_s3 #(
    parameter ZWIDTH = 16,
    parameter XWIDTH = 9,
    parameter YWIDTH = 8,
    parameter IDWIDTH = 16,
    parameter LWIDTH = 32
)
(
    input clk, rst,
    input signed [XWIDTH + YWIDTH + 1:0] x12y1_s2, x23y2_s2, y12x1_s2, y23x2_s2,
    input signed [XWIDTH + YWIDTH + 2:0] a0_s2, a1_s2,
    input signed [XWIDTH:0] dl1x_s2, dl2x_s2,
    input signed [YWIDTH:0] dl1y_s2, dl2y_s2,
 
    input signed [ZWIDTH-1:0] z1_s2, z2_s2, z3_s2,
    input [IDWIDTH-1:0] tID_s2,
    input valid,
    input stall,

    output reg signed [31:0] E1_s3, E2_s3, area_s3,
    output reg [IDWIDTH-1:0] tID_s3,
    output reg signed [XWIDTH:0] dl1x_s3, dl2x_s3,
    output reg signed [YWIDTH:0] dl1y_s3, dl2y_s3,
    output reg signed [ZWIDTH-1:0] z1_s3, z2_s3, z3_s3,
    output reg ovalid
);
    always @(posedge clk ) begin
        if(rst) begin 
            E1_s3    <= 0;
            E2_s3    <= 0;
            area_s3  <= 0;
            tID_s3   <= 0;
            dl1x_s3  <= 0;
            dl2x_s3  <= 0;
            dl1y_s3  <= 0;
            dl2y_s3  <= 0;
            z1_s3    <= 0;
            z2_s3    <= 0;
            z3_s3    <= 0;  
            ovalid   <= 0;    
        end
        else if (valid) begin
            E1_s3    <= (x23y2_s2 + y23x2_s2);
            E2_s3    <= (x12y1_s2 + y12x1_s2);
            area_s3  <= a0_s2 + a1_s2 ; // signed integer (i dont know area is having sign)
            tID_s3   <= tID_s2;
            dl1x_s3  <= dl1x_s2;
            dl2x_s3  <= dl2x_s2;
            dl1y_s3  <= dl1y_s2;
            dl2y_s3  <= dl2y_s2;
            z1_s3    <= z1_s2;
            z2_s3    <= z2_s2;
            z3_s3    <= z3_s2;
            ovalid   <= 1;
        end
        else if (stall) begin
            E1_s3 <= E1_s3;
            E2_s3 <= E2_s3;
            area_s3 <= area_s3;
            tID_s3 <= tID_s3;
            dl1x_s3 <= dl1x_s3;
            dl2x_s3 <= dl2x_s3;
            dl1y_s3 <= dl1y_s3;
            dl2y_s3 <= dl2y_s3;
            z1_s3    <= z1_s3;
            z2_s3    <= z2_s3;
            z3_s3    <= z3_s3;
            ovalid <= 0;
        end
        else begin
            ovalid <= 0;
        end
    end

endmodule