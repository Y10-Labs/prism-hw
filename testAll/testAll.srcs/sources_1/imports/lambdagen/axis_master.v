`timescale 1ns / 100ps
module AXI_STREAM_MASTER # (
	parameter integer C_S_AXIS_TDATA_WIDTH	= 32
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
    output wire [3: 0] 	src_addr,
    output wire 			      	src_enable,
    input  wire [C_S_AXIS_TDATA_WIDTH - 1: 0] 	src_data,
    input wire lg_valid,
    output reg lg_stall
);
    wire aclk;
    wire aresetn;
    reg[C_S_AXIS_TDATA_WIDTH-1 : 0] o_data;
    reg[(C_S_AXIS_TDATA_WIDTH/8)-1 : 0] o_strb;
    wire i_ready;
    reg o_last;
    reg o_valid;
    wire axis_handshake = o_valid && i_ready;
    
    parameter AXIS_STREAMING = 1'b0;
    parameter AXIS_BUSY = 1'b1;
    
    reg axis_state;
    reg[3:0] counter;
    reg[3:0] transfer_count; // Track which of the 10 transfers we're on
    
    assign src_addr = counter;
    assign src_enable = (axis_state == AXIS_STREAMING);
    
    always @(posedge aclk) begin
        if (!aresetn) begin
            axis_state <= AXIS_BUSY;
            o_data <= 0;
            o_strb <= {(C_S_AXIS_TDATA_WIDTH/8){1'b1}};
            o_last <= 0;
            o_valid <= 0;
            lg_stall <= 0;
            counter <= 0;
            transfer_count <= 0;
        end
        else begin
            case (axis_state)
                AXIS_BUSY: begin
                    o_valid <= 0;
                    o_last <= 0;
                    lg_stall <= 0;
                    counter <= 0;
                    transfer_count <= 0;
                    
                    if (lg_valid) begin
                        axis_state <= AXIS_STREAMING;
                        lg_stall <= 1;
                        counter <= 0;
                        transfer_count <= 0;
                        o_valid <= 1; // Start presenting data
                    end
                end
                
                AXIS_STREAMING: begin
                    lg_stall <= 1;
                    
                    // Present data from mux
                    o_data <= src_data;
                    o_strb <= {(C_S_AXIS_TDATA_WIDTH/8){1'b1}};
                    o_valid <= 1;
                    
                    // Assert TLAST on the 10th transfer (transfer_count == 9)
                    if (transfer_count == 4'd9) begin
                        o_last <= 1;
                    end else begin
                        o_last <= 0;
                    end
                    
                    // Only advance on successful handshake
                    if (axis_handshake) begin
                        if (transfer_count == 4'd9) begin
                            // Completed all 10 transfers
                            axis_state <= AXIS_BUSY;
                            counter <= 0;
                            transfer_count <= 0;
                            lg_stall <= 0;
                            o_valid <= 0;
                            o_last <= 0;
                        end else begin
                            // Move to next mux input
                            counter <= counter + 1;
                            transfer_count <= transfer_count + 1;
                        end
                    end
                end
            endcase
        end
    end
    
    assign aclk = S_AXIS_ACLK;
    assign aresetn = S_AXIS_ARESETN;
    assign i_ready = S_AXIS_TREADY;
    assign S_AXIS_TDATA = o_data;
    assign S_AXIS_TSTRB = o_strb;
    assign S_AXIS_TLAST = o_last;
    assign S_AXIS_TVALID = o_valid;
endmodule