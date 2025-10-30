module division(
    input  wire         clk,
    input  wire         reset,                  // active low reset
    input  wire         input_valid,
    input  wire [31:0]  divisor_data,
    input  wire [39:0]  dividend_data,
    output wire         quo_valid,
    output wire [39:0]  quo_data
);

// in gpu it is 40 bits signed integer (for 24.8 format output and truncating last 8 LSBs from division output) by 32 bits signed integer division
// input valid is a pulse
// output is valid until is input is valid again
// takes 8 cycles to get output - pipelined to 1 throughput per cycle after initial latency

// Pipeline valids 
reg v0, v1, v2, v3, v4, v5, v6, v7;

wire accept = input_valid;

always @(posedge clk) begin
    if (!reset) begin
        v0 <= 1'b0; v1 <= 1'b0; v2 <= 1'b0; v3 <= 1'b0; 
        v4 <= 1'b0; v5 <= 1'b0; v6 <= 1'b0; v7 <= 1'b0; 
    end else begin
        v0 <= accept;
        v1 <= v0; v2 <= v1; v3 <= v2; v4 <= v3;
        v5 <= v4; v6 <= v5; v7 <= v6; 
    end
end

assign quo_valid = v7;

// Stage S0: latch inputs, compute abs, sign, div_by_zero
reg signed [39:0] s1_dividend;
reg signed [31:0] s1_divisor;
reg [31:0] s1_divisor_abs;
reg s1_div_zero;
reg s1_sign;

always @(posedge clk) begin
    if (!reset) begin
        s1_dividend <= 40'sd0;
        s1_divisor <= 32'sd0;
        s1_divisor_abs <= 32'd0;
        s1_div_zero <= 1'b0;
        s1_sign <= 1'b0;
    end else if(accept) begin
        s1_dividend <= (dividend_data[39])? (~dividend_data + 1'b1) : dividend_data;
        s1_divisor <= divisor_data;
        s1_sign <= dividend_data[39] ^ divisor_data[31];
        s1_div_zero <= (divisor_data == 32'b0);
        s1_divisor_abs <= (divisor_data[31]) ? ((~divisor_data) + 1'b1) : divisor_data;
    end
end

// Stage S1: scale D to (0.5,1)
reg [31:0] s2_divisor;
reg [39:0] s2_dividend;
reg s2_sign;
wire [4:0] lz;

lzc32 lzc_inst(.x(s1_divisor_abs), .lzc(lz));

always@ (posedge clk) begin
    if (!reset) begin
        s2_divisor <= 32'b0;
        s2_dividend <= 0;
        s2_sign <= 1'b0;
    end else begin
        if (lz > 15) begin
            s2_divisor <= s1_divisor_abs << (lz - 15);
            s2_dividend <= s1_dividend <<< (lz - 15);
        end else begin
            s2_divisor <= s1_divisor_abs >> (15 - lz);
            s2_dividend <= s1_dividend >>> (15 - lz);
        end
        s2_sign <= s1_sign;
    end
end

// Stage S2: Get initial guess
wire [31:0] X_0;
wire [2:0] lut_index = (s2_divisor >> 13) & 3'b111;

recip_lut lut_inst (.index(lut_index), .value(X_0));

reg [31:0] s3_divisor;
reg [39:0] s3_dividend;
reg s3_sign;
reg [31:0] s3_X;  // Added to store X value

always @(posedge clk) begin
    if(!reset) begin
        s3_sign <= 1'b0;
        s3_dividend <= 0;
        s3_divisor <= 0;
        s3_X <= 0;
    end else begin
        s3_sign <= s2_sign;
        s3_dividend <= s2_dividend;
        s3_divisor <= s2_divisor;
        s3_X <= X_0;  // Store initial X
    end
end

// Stage S3: NR iteration 1 Part 1
reg [63:0] s4_DX1;
reg [31:0] s4_divisor;
reg [39:0] s4_dividend;
reg s4_sign;
reg [31:0] s4_X;

always @(posedge clk) begin
    if (!reset) begin
        s4_DX1 <= 0;
        s4_sign <= 1'b0;
        s4_dividend <= 0;
        s4_divisor <= 0;  
        s4_X <= 0;
    end else begin
        s4_DX1 <= s3_divisor * s3_X;  // Compute D * X0
        s4_sign <= s3_sign;
        s4_dividend <= s3_dividend;
        s4_divisor <= s3_divisor;
        s4_X <= s3_X;
    end
end

// Stage S4: NR iteration 1 Part 2
reg [63:0] s5_X1;
reg [31:0] s5_divisor;
reg [39:0] s5_dividend;
reg s5_sign;

always @(posedge clk) begin
    if (!reset) begin
        s5_X1 <= 0;
        s5_sign <= 0;
        s5_dividend <= 0;
        s5_divisor <= 0; 
    end else begin
        // Now s4_DX1 is available from previous cycle
        s5_X1 <= (s4_X * ((2 << 16) - s4_DX1[47:16]));  // X1 = X0 * (2 - D*X0)
        s5_sign <= s4_sign;
        s5_dividend <= s4_dividend;
        s5_divisor <= s4_divisor;
    end
end

// Stage S5: NR iteration 2 Part 1
reg [63:0] s6_DX2;
reg [31:0] s6_X1;
reg final_sign;
reg [39:0] final_dividend;

always @(posedge clk) begin
    if (!reset) begin
        s6_DX2 <= 0;
        s6_X1 <= 0;
        final_sign <= 0;
        final_dividend <= 0;
    end else begin
        s6_DX2 <= s5_divisor * s5_X1[47:16];  // Compute D * X1
        s6_X1 <= s5_X1[47:16];
        final_sign <= s5_sign;
        final_dividend <= s5_dividend;
    end
end

// Stage S6: NR iteration 2 Part 2
reg [63:0] final_X;
reg [39:0] final_dividend_reg;
reg final_sign_reg;
always @(posedge clk) begin
    if (!reset) begin
        final_X <= 0;
        final_dividend_reg <= 0;
        final_sign_reg <= 0;
    end else begin
        // Now s6_DX2 is available from previous cycle
        final_X <= (s6_X1 * ((2 << 16) - s6_DX2[47:16]));  // X2 = X1 * (2 - D*X1)
        final_dividend_reg <= final_dividend;
        final_sign_reg <= final_sign;
    end
end

reg final_sign_reg2;
// Stage S7: Output Q = N * X_final_iter
reg [71:0] Q;
always @(posedge clk) begin
    if (!reset) begin
        Q <= 0;
        final_sign_reg2 <= 0;
    end else begin
        Q <= final_dividend_reg * final_X[47:16];
        final_sign_reg2 <= final_sign_reg;
    end
end

wire [39:0] abs_q = Q[55:16]; 
assign quo_data = final_sign_reg2 ? -abs_q : abs_q;

endmodule

// leading zero count 32bit
module lzc32 (
    input [31:0] x,       
    output reg [4:0] lzc  
);
    always @(*) begin
        casez(x[30:0])
            31'b1?????????????????????????????? : lzc = 5'd0;
            31'b01????????????????????????????? : lzc = 5'd1;
            31'b001???????????????????????????? : lzc = 5'd2;
            31'b0001??????????????????????????? : lzc = 5'd3;
            31'b00001?????????????????????????? : lzc = 5'd4;
            31'b000001????????????????????????? : lzc = 5'd5;
            31'b0000001???????????????????????? : lzc = 5'd6;
            31'b00000001??????????????????????? : lzc = 5'd7;
            31'b000000001?????????????????????? : lzc = 5'd8;
            31'b0000000001????????????????????? : lzc = 5'd9;
            31'b00000000001???????????????????? : lzc = 5'd10;
            31'b000000000001??????????????????? : lzc = 5'd11;
            31'b0000000000001?????????????????? : lzc = 5'd12;
            31'b00000000000001????????????????? : lzc = 5'd13;
            31'b000000000000001???????????????? : lzc = 5'd14;
            31'b0000000000000001??????????????? : lzc = 5'd15;
            31'b00000000000000001?????????????? : lzc = 5'd16;
            31'b000000000000000001????????????? : lzc = 5'd17;
            31'b0000000000000000001???????????? : lzc = 5'd18;
            31'b00000000000000000001??????????? : lzc = 5'd19;
            31'b000000000000000000001?????????? : lzc = 5'd20;
            31'b0000000000000000000001????????? : lzc = 5'd21;
            31'b00000000000000000000001???????? : lzc = 5'd22;
            31'b000000000000000000000001??????? : lzc = 5'd23;
            31'b0000000000000000000000001?????? : lzc = 5'd24;
            31'b00000000000000000000000001????? : lzc = 5'd25;
            31'b000000000000000000000000001???? : lzc = 5'd26;
            31'b0000000000000000000000000001??? : lzc = 5'd27;
            31'b00000000000000000000000000001?? : lzc = 5'd28;
            31'b000000000000000000000000000001? : lzc = 5'd29;
            31'b0000000000000000000000000000001 : lzc = 5'd30;
            default: lzc = 5'd31;
        endcase
    end
endmodule

// Look up table for Initial guess
module recip_lut (
    input  wire [2:0] index,
    output reg  [31:0] value
);
    always @(*) begin
        case (index)
            3'd0: value = 32'sd131072; 
            3'd1: value = 32'sd109227; 
            3'd2: value = 32'sd93622;  
            3'd3: value = 32'sd81920;  
            3'd4: value = 32'sd72818;  
            3'd5: value = 32'sd65536;  
            3'd6: value = 32'sd59578;  
            3'd7: value = 32'sd54613;  
            default: value = 32'sd65536; 
        endcase
    end
endmodule
