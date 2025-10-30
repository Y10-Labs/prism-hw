// An implementation of AXI Stream Master

`timescale 1ns / 100ps

module AXI_BRAM2STREAM_MASTER # (
	parameter integer C_S_AXIS_TDATA_WIDTH	= 32,
	parameter integer SRC_ADDR_WIDTH = 12,
    parameter integer SRC_ADDR_MAX   = 1024
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
    output wire [SRC_ADDR_WIDTH - 1: 0] 	    src_addr,
    input  wire [C_S_AXIS_TDATA_WIDTH - 1: 0] 	src_data,
    input  wire                                 src_ready,
    output wire                                 src_enable,

    output wire done
);

    localparam DATA_WIDTH = C_S_AXIS_TDATA_WIDTH;

    wire aclk;
    wire aresetn;

    reg[C_S_AXIS_TDATA_WIDTH-1 : 0] o_data;
    reg[(C_S_AXIS_TDATA_WIDTH/8)-1 : 0] o_strb;

    wire i_ready;
    reg o_last;
    reg o_valid;

    wire axis_handshake = o_valid && i_ready;

    parameter AXIS_IDLE = 2'b01;
    parameter AXIS_BUSY = 2'b00;
    parameter AXIS_DONE = 2'b10;
    parameter AXIS_WAIT = 2'b11;
    reg[1: 0] axis_state = 0;
    assign done = (axis_state == AXIS_DONE);

    reg[SRC_ADDR_WIDTH-1 : 0] counter;
    reg[SRC_ADDR_WIDTH-1 : 0] sent_data;
    assign src_addr = counter;
    assign src_enable = 1'b1;
    
    reg[2: 0] latency_counter;
    reg[DATA_WIDTH - 1: 0] data_queue[3];
    reg[1: 0] queue_head;

    always @(posedge aclk) begin
        if (!aresetn) begin
            axis_state <= AXIS_WAIT;
            o_last <= 0;
            o_valid <= 0;
            o_strb <= {(C_S_AXIS_TDATA_WIDTH/8){1'b1}};

            queue_head <= 0;
            
            latency_counter <= 0;
            counter <= 0;
            sent_data <= 0;
        end
        else if (axis_state == AXIS_WAIT) begin
            // Wait for src_ready to go high before starting
            if (src_ready) begin
                o_valid <= 0;
                axis_state <= AXIS_BUSY;
            end
        end
        else if (axis_state == AXIS_IDLE) begin
            if (axis_handshake) begin

                // increment the queue head
                if(queue_head != 2) begin
                    queue_head <= queue_head + 1;
                end

                // increment the address counter and sent data
                if (counter < SRC_ADDR_MAX - 1) begin
                    counter <= counter + 1;
                end
                sent_data <= sent_data + 1;
                
                // Set last signal when reaching the end
                if (sent_data == SRC_ADDR_MAX - 2) begin
                    o_last <= 1;
                end
                else if (sent_data >= SRC_ADDR_MAX - 1) begin
                    axis_state <= AXIS_DONE;
                    o_valid <= 0;
                end
            end
            // if no handshake decrement the queue head(the data is shifting in)
            else begin
                // increment the queue head
                if(queue_head != 2) begin
                    queue_head <= queue_head - 1;
                end
            end
        end
        else if (axis_state == AXIS_BUSY) begin

            // increment the address counter in busy state
            if (counter < SRC_ADDR_MAX - 1) begin
                counter <= counter + 1;
            end

            if(queue_head != 0) begin
                queue_head <= queue_head - 1;
            end

            latency_counter <= latency_counter + 1;
            if(latency_counter >= 2 + 3 - 1) begin
            	axis_state <= AXIS_IDLE;
            	o_valid <= 1;
            end
        end
        else if (axis_state == AXIS_DONE) begin
            // Stay in done state
            o_last <= 0;
            o_valid <= 0;
            sent_data <= 0;
            counter <= 0;
            latency_counter <= 0;
            queue_head <= 0;
            axis_state <= AXIS_WAIT;
        end
    end

    // shift register logic
    integer i;
    always @(posedge aclk) begin
        if (!aresetn) begin
            o_data <= 0;
            for(i = 0; i < 3; i += 1) begin
                data_queue[i] <= 0;
            end
        end
        else begin
            o_data <= data_queue[queue_head];
            // shift the data queue
            for(i = 0; i < 2; i += 1) begin
                data_queue[i] <= data_queue[i + 1];
            end
            data_queue[2] <= src_data;
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