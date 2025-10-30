// An implementation of AXI Stream Master
// 

`timescale 1ns / 100ps

module AXI_STREAM_MASTER # (
	parameter integer C_S_AXIS_TDATA_WIDTH	= 32,
	parameter integer SRC_ADDR_WIDTH = 12,
	parameter integer SRC_LATENCY = 1
)(
    // AXI4Stream sink: Clock
    input wire  S_AXIS_ACLK,
    // AXI4Stream sink: Reset
    input wire  S_AXIS_ARESETN,
    // Ready to accept data in
    input wire  S_AXIS_TREADY,
    // Data out
    output wire [C_S_AXIS_TDATA_WIDTH-1 : 0] S_AXIS_TDATA,
    // Byte qualifier (ignore maybe?)
    output wire [(C_S_AXIS_TDATA_WIDTH/8)-1 : 0] S_AXIS_TSTRB,
    // Indicates boundary of last packet
    output wire  S_AXIS_TLAST,
    // Data is valid
    output wire  S_AXIS_TVALID,
    
    // data source
    output wire [SRC_ADDR_WIDTH - 1: 0] 	src_addr,
    output wire 			      	src_enable,
    input  wire [C_S_AXIS_TDATA_WIDTH - 1: 0] 	src_data
);

    wire aclk;
    wire aresetn;

    reg[C_S_AXIS_TDATA_WIDTH-1 : 0] o_data;
    reg[(C_S_AXIS_TDATA_WIDTH/8)-1 : 0] o_strb;

    wire i_ready;
    reg o_last;
    reg o_valid;

    wire axis_handshake = o_valid && i_ready;

    parameter AXIS_IDLE = 0;
    parameter AXIS_BUSY = 1;
    reg axis_state = 0;

    reg[SRC_ADDR_WIDTH-1 : 0] counter;
    assign src_addr = counter;
    assign src_enable = 1'b1;
    
    reg[clog2(SRC_LATENCTY) - 1: 0] latency_counter;

    always @(posedge aclk) begin
        if (!aresetn) begin
            axis_state <= AXIS_BUSY;
            o_data <= 0;
            o_last <= 0;
            o_valid <= 0;
            
            latency_counter <= 0;
            counter <= 0;
        end
        else if (axis_state == AXIS_IDLE) begin
            if (axis_handshake) begin
            	// if source has latency, then be busy until the output is ready
            	// alternative: keep "burst" registers
            	if(SRC_LATENCY > 0) begin
            	    latency_counter <= 0;
            	    axis_state <= AXIS_BUSY;
            	end
                counter <= counter + 1;
            end
        end
        else if (axis_state == AXIS_BUSY) begin
            latency_counter <= latency_counter + 1;
            if(latency_counter >= SRC_LATENCY - 1) begin
            	axis_state <= AXIS_IDLE;
            end
        end
    end

    assign aclk = S_AXIS_ACLK;
    assign aresetn = S_AXIS_ARESETN;

    assign i_ready = S_AXIS_TREADY;
    assign S_AXIS_TDATA = o_data;
    assign S_AXIS_TSTRB = o_strb;
    assign S_AXIS_TLAST = o_last;
    assign S_AXIS_TVALID = (axis_state == AXIS_IDLE);

endmodule

