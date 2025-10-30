module lambdagen_s6 #(
    parameter ZWIDTH = 16,
    parameter XWIDTH = 9,
    parameter YWIDTH = 8,
    parameter IDWIDTH = 16,
    parameter LWIDTH = 32
)(
    input clk, rst,
    input signed [31:0] l1z1_s5, l2z2_s5, l3z3_s5,
    input signed [31:0] dlx1z1_s5, dlx2z2_s5, dlx3z3_s5,
    input signed [31:0] dly1z1_s5, dly2z2_s5, dly3z3_s5,
    input signed [31:0] l1_s5, l2_s5, dl1x_s5, dl2x_s5, dl1y_s5, dl2y_s5,
    input signed [ZWIDTH-1:0] z1_s5, z2_s5, z3_s5, 
    input [IDWIDTH-1:0] tID_s5,
    input valid,
    input stall,

    output reg [31:0] z_, dzx, dzy,
    output reg signed [31:0] l1_s6, l2_s6, dl1x_s6, dl2x_s6, dl1y_s6, dl2y_s6,
    output reg signed [ZWIDTH-1:0] z1_s6, z2_s6, z3_s6, 
    output reg [IDWIDTH-1:0] tID_s6,
    output reg ovalid
);

always @(posedge clk ) begin
    if (rst) begin
        l1_s6 <= 0; l2_s6 <= 0; dl1x_s6 <= 0; dl2x_s6 <= 0; dl1y_s6 <= 0; dl2y_s6 <= 0;
        z_ <= 0; dzx <= 0; dzy <= 0;
        z1_s6 <= 0; z2_s6 <= 0; z3_s6 <= 0;
        tID_s6 <= 0; ovalid <= 0;
    end
    else if (valid) begin
        z_     <= l1z1_s5 + l2z2_s5 + l3z3_s5;
        dzx    <= dlx1z1_s5 + dlx2z2_s5 + dlx3z3_s5;
        dzy    <= dly1z1_s5 + dly2z2_s5 + dly3z3_s5;

        l1_s6  <= l1_s5;
        l2_s6  <= l2_s5;
        dl1x_s6<= dl1x_s5;
        dl2x_s6<= dl2x_s5;
        dl1y_s6<= dl1y_s5;
        dl2y_s6<= dl2y_s5;

        z1_s6  <= z1_s5;
        z2_s6  <= z2_s5;
        z3_s6  <= z3_s5;

        tID_s6 <= tID_s5;
        ovalid <= 1;

    end
    else if (stall) begin
        l1_s6   <= l1_s6;
        l2_s6   <= l2_s6;
        dl1x_s6 <= dl1x_s6;
        dl2x_s6 <= dl2x_s6;
        dl1y_s6 <= dl1y_s6;
        dl2y_s6 <= dl2y_s6;

        z_      <= z_;
        dzx     <= dzx;
        dzy     <= dzy;

        z1_s6   <= z1_s6;
        z2_s6   <= z2_s6;
        z3_s6   <= z3_s6;
        tID_s6  <= tID_s6;
        ovalid  <= 0;
    end
    else begin
        ovalid <= 0;
    end
end
endmodule