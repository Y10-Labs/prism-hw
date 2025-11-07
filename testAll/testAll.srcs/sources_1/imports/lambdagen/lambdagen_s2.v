module lambdagen_s2 #(
    parameter ZWIDTH = 16,
    parameter XWIDTH = 9,
    parameter YWIDTH = 8,
    parameter IDWIDTH = 16,
    parameter LWIDTH = 32
)(
    input clk,
    input rst,
    input signed [XWIDTH:0] dl1x_s1, dl2x_s1,
    input signed [YWIDTH:0] dl1y_s1, dl2y_s1,
    input [XWIDTH-1:0] x1_s1, x2_s1, 
    input [YWIDTH-1:0] y1_s1, y2_s1,
    input signed [ZWIDTH-1:0] z1_s1, z2_s1, z3_s1,
    input valid,
    input stall,


    input [IDWIDTH-1:0] tID_s1,
    output reg signed [XWIDTH + YWIDTH + 1:0] x12y1_s2, x23y2_s2, y12x1_s2, y23x2_s2,
    output reg signed [XWIDTH + YWIDTH + 2:0] a0_s2, a1_s2,
    output reg signed [XWIDTH:0] dl1x_s2, dl2x_s2, 
    output reg signed [YWIDTH:0] dl1y_s2, dl2y_s2,
    output reg signed [ZWIDTH-1:0] z1_s2, z2_s2, z3_s2,
    output reg [IDWIDTH-1:0] tID_s2,
    output reg ovalid
  );
    always @(posedge clk ) begin
        if (rst) begin
            x12y1_s2 <= 0;
            x23y2_s2 <= 0;
            y12x1_s2 <= 0;
            y23x2_s2 <= 0;
            a0_s2    <= 0;
            a1_s2    <= 0;
            tID_s2   <= 0;
            dl1x_s2  <= 0;
            dl2x_s2  <= 0;
            dl1y_s2  <= 0;
            dl2y_s2  <= 0;
            z1_s2    <= 0;
            z2_s2    <= 0;
            z3_s2    <= 0;  
            ovalid   <= 0; 
        end
        else if (valid) begin
            // x12y1_s2 <= - ( $signed(dl1x_s1) * $signed({1'b0, y1_s1}) );
            // x23y2_s2 <= - ( $signed(dl2x_s1) * $signed({1'b0, y2_s1}) );
            // y12x1_s2 <= - ( $signed(dl1y_s1) * $signed({1'b0, x1_s1}) );
            // y23x2_s2 <= - ( $signed(dl2y_s1) * $signed({1'b0, x2_s1}) );
            x12y1_s2 <= - ( $signed(dl1y_s1) * $signed({1'b0, y1_s1}) ); // signed integer output
            x23y2_s2 <= - ( $signed(dl2y_s1) * $signed({1'b0, y2_s1}) );
            y12x1_s2 <= - ( $signed(dl1x_s1) * $signed({1'b0, x1_s1}) );
            y23x2_s2 <= - ( $signed(dl2x_s1) * $signed({1'b0, x2_s1}) );            
            a0_s2 <= ( $signed(dl1y_s1) * $signed(dl2x_s1) ); // fixed (removed negation)
            a1_s2 <= - ( $signed(dl1x_s1) * $signed(dl2y_s1) );
            tID_s2   <= tID_s1;
            dl1x_s2  <= dl1x_s1;
            dl2x_s2  <= dl2x_s1;
            dl1y_s2  <= dl1y_s1;
            dl2y_s2  <= dl2y_s1;
            z1_s2    <= z1_s1;
            z2_s2    <= z2_s1;
            z3_s2    <= z3_s1; 
            ovalid   <= 1;
        end
        else if (stall) begin
            x12y1_s2 <= x12y1_s2; 
            x23y2_s2 <= x23y2_s2;
            y12x1_s2 <= y12x1_s2;
            y23x2_s2 <= y23x2_s2;
            a0_s2    <= a0_s2   ;
            a1_s2    <= a1_s2   ;
            tID_s2   <= tID_s2  ;
            dl1x_s2  <= dl1x_s2 ;
            dl2x_s2  <= dl2x_s2 ;
            dl1y_s2  <= dl1y_s2 ;
            dl2y_s2  <= dl2y_s2 ;
            z1_s2    <= z1_s2   ;
            z2_s2    <= z2_s2   ;
            z3_s2    <= z3_s2   ;
            ovalid   <= 0       ;
        end
        else begin
            ovalid <= 0;
        end
    end
endmodule
