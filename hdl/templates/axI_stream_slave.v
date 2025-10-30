// An implementation of AXI Stream
// Assuming no null bytes are present
// in the stream(I know)

`timescale 1ns / 100ps

module AXI_STREAM_SLAVE # (
	parameter integer C_S_AXIS_TDATA_WIDTH	= 32
)(
    // AXI4Stream sink: Clock
    input wire  S_AXIS_ACLK,
    // AXI4Stream sink: Reset
    input wire  S_AXIS_ARESETN,
    // Ready to accept data in
    output wire  S_AXIS_TREADY,
    // Data in
    input wire [C_S_AXIS_TDATA_WIDTH-1 : 0] S_AXIS_TDATA,
    // Byte qualifier
    input wire [(C_S_AXIS_TDATA_WIDTH/8)-1 : 0] S_AXIS_TSTRB,
    // Indicates boundary of last packet
    input wire  S_AXIS_TLAST,
    // Data is in valid
    input wire  S_AXIS_TVALID,

    output wire [C_S_AXIS_TDATA_WIDTH-1 : 0] accumlate_reg
);

    wire aclk;
    wire aresetn;

    wire[C_S_AXIS_TDATA_WIDTH-1 : 0] i_data;
    wire[(C_S_AXIS_TDATA_WIDTH/8)-1 : 0] i_strb;

    reg o_ready;
    wire i_last;
    wire i_valid;

    wire axis_handshake = i_valid && o_ready;

    parameter AXIS_IDLE      = 0;
    parameter AXIS_STREAMING = 1;
    reg axis_state = 0;

    reg[C_S_AXIS_TDATA_WIDTH-1 : 0] accumulate;

    always @(posedge aclk) begin
        if (!aresetn) begin
            axis_state <= AXIS_IDLE;
            // data is not valid
            o_ready <= 0;
            o_valid <= 0;
            counter <= 1;
        end
        else if (axis_state == AXIS_IDLE) begin
            o_valid <= 1;
            o_data <= counter;
            axis_state <= AXIS_STREAMING;
        end
        else if (axis_state == AXIS_STREAMING) begin
            // HANDSHAKE!!
            if (axis_handshake) begin
                o_data <= counter;
            end
            else begin
                ;
            end
        end

        // increment counter
        counter <= counter + 1;
    end

    assign aclk = S_AXIS_ACLK;
    assign aresetn = S_AXIS_ARESETN;
    assign i_data = S_AXIS_TDATA;
    assign i_strb = S_AXIS_TSTRB;
    assign i_last = S_AXIS_TLAST;
    assign i_valid = S_AXIS_TVALID;

    assign S_AXIS_TREADY = o_ready;
    assign accumlate_reg = accumulate;

endmodule

