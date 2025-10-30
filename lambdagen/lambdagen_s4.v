module lambdagen_s4 #(
    parameter ZWIDTH = 16,
    parameter XWIDTH = 9,
    parameter YWIDTH = 8,
    parameter IDWIDTH = 16,
    parameter LWIDTH = 32
)
(
    input clk, rst,
    input signed [31:0] E1_s3, E2_s3, area_s3,
    input signed [ZWIDTH-1:0] z1_s3, z2_s3, z3_s3,
    input [IDWIDTH-1:0] tID_s3,
    input signed [XWIDTH:0] dl1x_s3, dl2x_s3,
    input signed [YWIDTH:0] dl1y_s3, dl2y_s3,
    input valid,
    input stall,

    output reg signed [31:0] l1_s4, l2_s4, dl1x_s4, dl2x_s4, dl1y_s4, dl2y_s4,
    output reg signed [ZWIDTH-1:0] z1_s4, z2_s4, z3_s4,
    output reg [IDWIDTH-1:0] tID_s4,
    output reg ovalid
);
    parameter FRAC = 8;
    integer i;

    reg valid_d [0:6];
    reg [IDWIDTH-1:0] tID_s4_latch [0:6];
    reg signed [ZWIDTH-1:0] z1_s4_latch [0:6];
    reg signed [ZWIDTH-1:0] z2_s4_latch [0:6];
    reg signed [ZWIDTH-1:0] z3_s4_latch [0:6];
    
    wire signed [39:0] quo1, quo2, quo3, quo4, quo5, quo6;

    wire signed [31:0] dl1x_ext;
    wire signed [31:0] dl2x_ext;
    wire signed [31:0] dl1y_ext;
    wire signed [31:0] dl2y_ext;

    assign dl1x_ext = $signed(dl1x_s3);
    assign dl2x_ext = $signed(dl2x_s3);
    assign dl1y_ext = $signed(dl1y_s3);
    assign dl2y_ext = $signed(dl2y_s3);

    wire divValid1, divValid2, divValid3, divValid4, divValid5, divValid6;
    
    wire divValid = divValid1;

    division div1 (
        .clk          (clk),
        .reset        (~rst),
        .input_valid  (valid),
        .divisor_data (area_s3),
        .dividend_data(E1_s3),
        .quo_valid    (divValid1),
        .quo_data     (quo1)
    );

    division div2 (
        .clk          (clk),
        .reset        (~rst),
        .input_valid  (valid),
        .divisor_data (area_s3),
        .dividend_data(E2_s3),
        .quo_valid    (divValid2),
        .quo_data     (quo2)
    );

    division div3 (
        .clk          (clk),
        .reset        (~rst),
        .input_valid  (valid),
        .divisor_data (area_s3),
        .dividend_data(dl2x_ext),
        .quo_valid    (divValid3),
        .quo_data     (quo3)
    );

    division div4 (
        .clk          (clk),
        .reset        (~rst),
        .input_valid  (valid),
        .divisor_data (area_s3),
        .dividend_data(dl1x_ext),
        .quo_valid    (divValid4),
        .quo_data     (quo4)
    );

    division div5 (
        .clk          (clk),
        .reset        (~rst),
        .input_valid  (valid),
        .divisor_data (area_s3),
        .dividend_data(dl2y_ext),
        .quo_valid    (divValid5),
        .quo_data     (quo5)
    );

    division div6 (
        .clk          (clk),
        .reset        (~rst),
        .input_valid  (valid),
        .divisor_data (area_s3),
        .dividend_data(dl1y_ext),
        .quo_valid    (divValid6),
        .quo_data     (quo6)
    );

    function any_valid_d;
        integer j;
        begin
            any_valid_d = 1'b0;
            for (j = 0; j < 7; j = j + 1) begin
                any_valid_d = any_valid_d | valid_d[j];
            end
        end
    endfunction

    always @ (posedge clk) begin
        if (rst) begin
            l1_s4   <= 0;
            l2_s4   <= 0;
            dl1x_s4 <= 0;
            dl2x_s4 <= 0;
            dl1y_s4 <= 0;
            dl2y_s4 <= 0;
            ovalid  <= 0;
            tID_s4  <= 0;
            z1_s4   <= 0;
            z2_s4   <= 0;
            z3_s4   <= 0;
            
            for (i = 0; i < 7; i = i + 1) begin
                valid_d[i] <= 0;
                tID_s4_latch[i] <= 0;
                z1_s4_latch[i] <= 0;
                z2_s4_latch[i] <= 0;
                z3_s4_latch[i] <= 0;
            end
        end
        else if (!stall) begin
            if (valid || any_valid_d()) begin
                tID_s4_latch[0] <= tID_s3;
                z1_s4_latch[0] <= z1_s3;
                z2_s4_latch[0] <= z2_s3;
                z3_s4_latch[0] <= z3_s3;
                valid_d[0] <= valid;

                for (i = 1; i < 7; i = i + 1) begin
                    valid_d[i] <= valid_d[i-1];
                    tID_s4_latch[i] <= tID_s4_latch[i-1];
                    z1_s4_latch[i] <= z1_s4_latch[i-1];
                    z2_s4_latch[i] <= z2_s4_latch[i-1];
                    z3_s4_latch[i] <= z3_s4_latch[i-1];
                end
            end
            ovalid <= divValid;
            l1_s4   <= quo1[39:8];
            l2_s4   <= quo2[39:8];
            dl1x_s4 <= quo4[39:8];
            dl2x_s4 <= quo3[39:8];
            dl1y_s4 <= quo6[39:8];
            dl2y_s4 <= quo5[39:8];
            
            tID_s4 <= tID_s4_latch[6];
            z1_s4 <= z1_s4_latch[6];
            z2_s4 <= z2_s4_latch[6];
            z3_s4 <= z3_s4_latch[6];
        end
        else if (stall) begin
            ovalid <= 1'b1;
        end
    end

endmodule