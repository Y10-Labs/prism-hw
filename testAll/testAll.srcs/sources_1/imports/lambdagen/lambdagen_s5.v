module lambdagen_s5 #(
    parameter ZWIDTH = 16,
    parameter XWIDTH = 9,
    parameter YWIDTH = 8,
    parameter IDWIDTH = 16,
    parameter LWIDTH = 32
)(
    input clk, rst,
    input signed [31:0] l1_s4, l2_s4, dl1x_s4, dl2x_s4, dl1y_s4, dl2y_s4,
    input [IDWIDTH-1:0] tID_s4,
    input signed [ZWIDTH-1:0] z1_s4, z2_s4, z3_s4,
    input valid,
    input stall,

    output reg signed [31:0] l1z1_s5, l2z2_s5, l3z3_s5,
    output reg signed [31:0] dlx1z1_s5, dlx2z2_s5, dlx3z3_s5,
    output reg signed [31:0] dly1z1_s5, dly2z2_s5, dly3z3_s5,
    output reg signed [31:0] l1_s5, l2_s5, dl1x_s5, dl2x_s5, dl1y_s5, dl2y_s5,
    output reg signed [ZWIDTH-1:0] z1_s5, z2_s5, z3_s5, 
    output reg [IDWIDTH-1:0] tID_s5,
    output reg ovalid
);

    always @(posedge clk ) begin
        if (rst) begin
            l1_s5 <= 0; l2_s5 <= 0; dl1x_s5 <= 0; dl2x_s5 <= 0; dl1y_s5 <= 0; dl2y_s5 <= 0;
            l1z1_s5 <= 0; l2z2_s5 <= 0; l3z3_s5 <= 0;
            dlx1z1_s5 <= 0; dlx2z2_s5 <= 0; dlx3z3_s5 <= 0;
            dly1z1_s5 <= 0; dly2z2_s5 <= 0; dly3z3_s5 <= 0;
            tID_s5 <= 0; ovalid <= 0;
            z1_s5 <= 0; z2_s5 <= 0; z3_s5 <= 0;
        end
        else if (valid) begin
            l1z1_s5   <= l1_s4 * z1_s4; 
            l2z2_s5   <= l2_s4 * z3_s4; // l3 * z3 // confusion because l2 is l3
            l3z3_s5   <= ((32'sd1 <<< 8) - l1_s4 - l2_s4) * z2_s4; // l2*z2
            dlx1z1_s5 <= dl1x_s4 * z1_s4;
            dlx2z2_s5 <= dl2x_s4 * z3_s4;
            dlx3z3_s5 <= ((32'sd1 <<< 8) - dl1x_s4 - dl2x_s4) * z2_s4;
            dly1z1_s5 <= dl1y_s4 * z1_s4;
            dly2z2_s5 <= dl2y_s4 * z3_s4;
            dly3z3_s5 <= ((32'sd1 <<< 8) - dl1y_s4 - dl2y_s4) * z2_s4;

            l1_s5    <= l1_s4;
            l2_s5    <= l2_s4;
            dl1x_s5  <= dl1x_s4;
            dl2x_s5  <= dl2x_s4;
            dl1y_s5  <= dl1y_s4;
            dl2y_s5  <= dl2y_s4;
            z1_s5    <= z1_s4;
            z2_s5    <= z2_s4;
            z3_s5    <= z3_s4;
            tID_s5   <= tID_s4;
            ovalid   <= 1;

        end
        else if (stall) begin
            l1z1_s5   <= l1z1_s5;
            l2z2_s5   <= l2z2_s5;
            l3z3_s5   <= l3z3_s5;
            dlx1z1_s5 <= dlx1z1_s5;
            dlx2z2_s5 <= dlx2z2_s5;
            dlx3z3_s5 <= dlx3z3_s5;
            dly1z1_s5 <= dly1z1_s5;
            dly2z2_s5 <= dly2z2_s5; 
            dly3z3_s5 <= dly3z3_s5;
            l1_s5    <= l1_s5;
            l2_s5    <= l2_s5;
            dl1x_s5  <= dl1x_s5;
            dl2x_s5  <= dl2x_s5;
            dl1y_s5  <= dl1y_s5;
            dl2y_s5  <= dl2y_s5;
            z1_s5    <= z1_s5;
            z2_s5    <= z2_s5;
            z3_s5    <= z3_s5;
            tID_s5   <= tID_s5;
            ovalid   <= 0;
        end
        else begin
            ovalid <= 0;
        end
    end
endmodule