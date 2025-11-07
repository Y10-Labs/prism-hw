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

    reg [IDWIDTH-1:0] tID_s4_latch [0:8];
    reg signed [ZWIDTH-1:0] z1_s4_latch [0:8];
    reg signed [ZWIDTH-1:0] z2_s4_latch [0:8];
    reg signed [ZWIDTH-1:0] z3_s4_latch [0:8];
    
    wire signed [39:0] quo1, quo2, quo3, quo4, quo5, quo6;

    wire signed [31:0] dl1x_ext;
    wire signed [31:0] dl2x_ext;
    wire signed [31:0] dl1y_ext;
    wire signed [31:0] dl2y_ext;

    assign dl1x_ext = -$signed(dl1x_s3);
    assign dl2x_ext = -$signed(dl2x_s3);
    assign dl1y_ext = -$signed(dl1y_s3);
    assign dl2y_ext = -$signed(dl2y_s3);

    wire divValid1, divValid2, divValid3, divValid4, divValid5, divValid6;
    
    wire divValid = divValid1;
    
    // Gate the input_valid with stall to prevent division units from accepting new data when stalled
    wire div_input_valid = valid & !stall;

    division div1 (
        .clk          (clk),
        .reset        (~rst),
        .input_valid  (div_input_valid),
        .stall        (stall),
        .divisor_data (area_s3),
        .dividend_data({{8{E1_s3[31]}}, E1_s3}),
        .quo_valid    (divValid1),
        .quo_data     (quo1)
    );

    division div2 (
        .clk          (clk),
        .reset        (~rst),
        .input_valid  (div_input_valid),
        .stall        (stall),
        .divisor_data (area_s3),
        .dividend_data({{8{E2_s3[31]}}, E2_s3}),
        .quo_valid    (divValid2),
        .quo_data     (quo2)
    );

    division div3 (
        .clk          (clk),
        .reset        (~rst),
        .input_valid  (div_input_valid),
        .stall        (stall),
        .divisor_data (area_s3),
        .dividend_data({{8{dl1x_ext[31]}}, dl1x_ext}),
        .quo_valid    (divValid3),
        .quo_data     (quo3)
    );

    division div4 (
        .clk          (clk),
        .reset        (~rst),
        .input_valid  (div_input_valid),
        .stall        (stall),
        .divisor_data (area_s3),
        .dividend_data({{8{dl2x_ext[31]}}, dl2x_ext}),
        .quo_valid    (divValid4),
        .quo_data     (quo4)
    );

    division div5 (
        .clk          (clk),
        .reset        (~rst),
        .input_valid  (div_input_valid),
        .stall        (stall),
        .divisor_data (area_s3),
        .dividend_data({{8{dl1y_ext[31]}}, dl1y_ext}),
        .quo_valid    (divValid5),
        .quo_data     (quo5)
    );

    division div6 (
        .clk          (clk),
        .reset        (~rst),
        .input_valid  (div_input_valid),
        .stall        (stall),
        .divisor_data (area_s3),
        .dividend_data({{8{dl2y_ext[31]}}, dl2y_ext}),
        .quo_valid    (divValid6),
        .quo_data     (quo6)
    );

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
            
            for (i = 0; i < 9; i = i + 1) begin
                tID_s4_latch[i] <= 0;
                z1_s4_latch[i] <= 0;
                z2_s4_latch[i] <= 0;
                z3_s4_latch[i] <= 0;
            end
        end
        else if (!stall) begin
            // Only update shift registers when not stalled
            if (valid) begin
                tID_s4_latch[0] <= tID_s3;
                z1_s4_latch[0] <= z1_s3;
                z2_s4_latch[0] <= z2_s3;
                z3_s4_latch[0] <= z3_s3;
            end

            for (i = 1; i < 9; i = i + 1) begin
                tID_s4_latch[i] <= tID_s4_latch[i-1];
                z1_s4_latch[i] <= z1_s4_latch[i-1];
                z2_s4_latch[i] <= z2_s4_latch[i-1];
                z3_s4_latch[i] <= z3_s4_latch[i-1];
            end
            
            // Update outputs
            ovalid <= divValid;
            l1_s4   <= -quo1[31:0];
            l2_s4   <= -quo2[31:0];
            dl1x_s4 <= quo4[31:0];
            dl2x_s4 <= quo3[31:0];
            dl1y_s4 <= quo6[31:0];
            dl2y_s4 <= quo5[31:0];
            
            tID_s4 <= tID_s4_latch[8];
            z1_s4 <= z1_s4_latch[8];
            z2_s4 <= z2_s4_latch[8];
            z3_s4 <= z3_s4_latch[8];
        end
        // When stalled, all registers hold their current values
    end

endmodule