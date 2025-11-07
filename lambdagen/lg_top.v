`timescale 1ns/1ps

module lg_top #(parameter PIPE_LATENCY = 18)(
	input wire clk,
	input wire rst,
	// AXI Stream slave interface
	input wire [31:0] s_tdata,
	input wire s_tvalid,
	output wire s_tready,
	input wire s_tlast,
	// AXI Stream master interface
	output wire [31:0] m_tdata,
	output wire m_tvalid,
	input wire m_tready,
	output wire m_tlast
);

	// Internal signals for axis_deser (slave)
	wire [127:0] deser_data;
	wire deser_valid;

	// Internal signals for lambdagen
	wire lambdagen_stall;
	wire [2:0] lambdagen_quad = 2'b00; // Example, can be parameterized
	wire [31:0] l1, l2, dl1x, dl2x, dl1y, dl2y, z_, dzx, dzy;
	wire signed [15:0] _z1, _z2, _z3;
	wire [15:0] tID;
	wire dovalid, ovalid_s1, ovalid_s2, ovalid_s3, ovalid_s4, ovalid_s5;

	// Internal signals for AXI_STREAM_MASTER (master)
	wire [3:0] src_addr;
	wire src_enable;
	wire [31:0] src_data;

	// AXI Stream Slave (Deserializer)
	axis_deser #(
		.FREQ_HZ(100_000_000),
		.DATA_W(32)
	) axis_slave_inst (
		.aclk(clk),
		.aresetn(rst),
		.s_tdata(s_tdata),
		.s_tvalid(s_tvalid),
		.s_tready(s_tready),
		.s_tlast(s_tlast),
		.stall(lambdagen_stall),
		.m_data128(deser_data),
		.m_valid(deser_valid),
		.m_ready(~lambdagen_stall)
	);

	// Lambdagen core
	lambdagen lambdagen_inst (
		.clk(clk),
		.rst(~rst),
		.valid(deser_valid),
		.input_bus(deser_data),
		.stall(lambdagen_stall),
		.quad(lambdagen_quad),
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
	
	// Extract Y coordinates from lambdagen input bus for min/max computation
	// Based on lambdagen format: {tID, z1, _, y1, y2, y3, __, x1, x2, x3, z2, z3}
	wire [7:0] y1_input = deser_data[63:56];
	wire [7:0] y2_input = deser_data[55:48];
	wire [7:0] y3_input = deser_data[47:40];
	
	// Compute min and max of y values
	wire [7:0] y_min_12 = (y1_input < y2_input) ? y1_input : y2_input;
	wire [7:0] y_max_12 = (y1_input > y2_input) ? y1_input : y2_input;
	wire [7:0] y_min = (y_min_12 < y3_input) ? y_min_12 : y3_input;
	wire [7:0] y_max = (y_max_12 > y3_input) ? y_max_12 : y3_input;
	
	// Extract X coordinates to compute x_len (max_x - min_x)
	wire [8:0] x1_input = deser_data[26:18];
	wire [8:0] x2_input = deser_data[17:9];
	wire [8:0] x3_input = deser_data[8:0];
	
	wire [8:0] x_min_12 = (x1_input < x2_input) ? x1_input : x2_input;
	wire [8:0] x_max_12 = (x1_input > x2_input) ? x1_input : x2_input;
	wire [8:0] x_min = (x_min_12 < x3_input) ? x_min_12 : x3_input;
	wire [8:0] x_max = (x_max_12 > x3_input) ? x_max_12 : x3_input;
	wire [8:0] x_len_calc = x_max - x_min;
	    
    reg [5:0] y_start_pipe [0:PIPE_LATENCY-1];
    reg [5:0] y_end_pipe [0:PIPE_LATENCY-1];
    reg [7:0] x_len_pipe [0:PIPE_LATENCY-1];
    reg [5:0] y_start_reg;
    reg [5:0] y_end_reg;
    reg [7:0] x_len_reg;
    reg [31:0] header_reg;
    
    integer i;
    
    always @(posedge clk) begin
        if (~rst) begin
            for (i = 0; i < PIPE_LATENCY; i = i + 1) begin
                y_start_pipe[i] <= 6'd0;
                y_end_pipe[i] <= 6'd0;
                x_len_pipe[i] <= 8'd0;
            end
            y_start_reg <= 6'd0;
            y_end_reg <= 6'd0;
            x_len_reg <= 8'd0;
            header_reg <= 32'h0;
        end else if (!lambdagen_stall) begin
            if (deser_valid) begin
                y_start_pipe[0] <= y_min[5:0];
                y_end_pipe[0] <= y_max[5:0];
                x_len_pipe[0] <= x_len_calc[7:0];
            end else begin
                y_start_pipe[0] <= 6'd0;
                y_end_pipe[0] <= 6'd0;
                x_len_pipe[0] <= 8'd0;
            end
            for (i = 1; i < PIPE_LATENCY; i = i + 1) begin
                y_start_pipe[i] <= y_start_pipe[i-1];
                y_end_pipe[i] <= y_end_pipe[i-1];
                x_len_pipe[i] <= x_len_pipe[i-1];
            end
            y_start_reg <= y_start_pipe[PIPE_LATENCY-1];
            y_end_reg <= y_end_pipe[PIPE_LATENCY-1];
            x_len_reg <= x_len_pipe[PIPE_LATENCY-1];
            if (dovalid) begin
                header_reg <= {4'h0, tID[11:0], x_len_reg, y_end_reg, y_start_reg};
            end
        end
    end

	// Mux for selecting lambdagen outputs based on src_addr from master
	// Order matches raster_core_impl data_it sequence:
	// 0: header, 1: l2, 2: l1, 3: dl2y, 4: dl1x, 5: dl1y, 6: dl2x, 7: z_, 8: dzx, 9: dzy
	reg [31:0] src_data_mux;
	always @(*) begin
		case (src_addr[3:0])
			4'd0: src_data_mux = header_reg;  // header
			4'd1: src_data_mux = l2;          // lambda_zero[1]
			4'd2: src_data_mux = l1;          // lambda_zero[0]
			4'd3: src_data_mux = dl2y;        // lambda_diff[3]
			4'd4: src_data_mux = dl1x;        // lambda_diff[0]
			4'd5: src_data_mux = dl1y;        // lambda_diff[1]
			4'd6: src_data_mux = dl2x;        // lambda_diff[2]
			4'd7: src_data_mux = z_;          // z_zero
			4'd8: src_data_mux = dzx;         // z_diff[0]
			4'd9: src_data_mux = dzy;         // z_diff[1]
			default: src_data_mux = 32'h0;
		endcase
	end

	// Optional: Add pipeline register for timing if needed
	// This can help if lambdagen outputs have long combinational paths
	reg [31:0] src_data_reg;
	always @(posedge clk) begin
		if (~rst) begin
			src_data_reg <= 32'h0;
		end else if (src_enable) begin
			src_data_reg <= src_data_mux;
		end
	end

	// Connect to master
	assign src_data = src_data_reg;

	// AXI Stream Master 
	AXI_STREAM_MASTER #(
		.C_S_AXIS_TDATA_WIDTH(32)
	) axis_master_inst (
		.S_AXIS_ACLK(clk),
		.S_AXIS_ARESETN(rst),
		.S_AXIS_TREADY(m_tready),
		.S_AXIS_TDATA(m_tdata),
		.S_AXIS_TSTRB(), // Not connected
		.S_AXIS_TLAST(m_tlast),
		.S_AXIS_TVALID(m_tvalid),
		.src_addr(src_addr),
		.src_enable(src_enable),
		.src_data(src_data),
		.lg_valid(dovalid),        // Trigger from lambdagen
		.lg_stall(lambdagen_stall) // Backpressure to lambdagen
	);

endmodule