`timescale 1ns / 100ps

module raster_core_impl #(
    parameter integer core_id = 56,
    parameter integer LWIDTH = 32,
    parameter integer BRAM_LATENCY = 2
) (
    input wire clk,
    input wire nreset,

    input wire              is_handshake,
    input wire [LWIDTH-1:0] data,

    // are we ready to receive a new triangle?
    output wire             ready,

    // SDP mode bram interface (32 bit wide x 512 deep)
    output wire       rch_en,
    output wire[31:0] rch_addr,
    input  wire[31:0] rch_data,

    output wire       wch_en,
    output wire[31:0] wch_addr,
    output wire[31:0] wch_data

    // writeback out
    //input  wire writeback_handshake,
    //output wire valid,
    //output wire[15:0] tid_data
);
    localparam IDLE = 0;
    localparam PREPROCESSING = 1;
    localparam RASTERIZING = 2;
    localparam WRITEBACK = 3;
    reg[1:0] rasterizer_state;

    wire[6:0] y_start = {data[5:0] , 1'b0};
    wire[6:0] y_end   = {data[11:6], 1'b1};

    wire comb_skip_triangle = (core_id > y_end) || (core_id < y_start);

    // data
    reg[31:0] header;
    reg[31:0] lambda_zero[1:0];
    // lambda_zero[0] dx, lambda_zero[0] dy, lambda_zero[1] dx, lambda_zero[1] dy
    reg[31:0] lambda_diff[3:0];
    reg[15:0] z_zero;
    reg[15:0] z_diff[1:0];

    // should we skip this triangle?
    reg skip_triangle;
    // should we skip this triangle?
    // end triangles have y_start >= 62, y_end >= 62 - they will be skipped
    // this means the core should more to the last stage -> writeback
    reg is_end_triangle;

    // data iterator
    reg[3:0] data_it;
    // are we ready to receive a new triangle?
    assign ready = (rasterizer_state == IDLE);

    // ---------- rasterizer code ----------

    // x position iterator
    reg[32:0] x_it;

    wire [31:0] lambda_sum;
    assign lambda_sum = lambda_zero[0] + lambda_zero[1];

    // should we write this pixel?
    wire should_write_pixel;
    assign should_write_pixel = 
        (lambda_zero[0][31] == 0) && 
        (lambda_zero[1][31] == 0) && 
        (lambda_sum[31]     == 0) && 
        (z_zero > rch_data[15:0]) && 
        (x_it >= BRAM_LATENCY) && 
        (rasterizer_state == RASTERIZING);

    // connect to bram interface
    assign rch_en = (rasterizer_state == RASTERIZING);
    assign rch_addr = x_it;
    
    assign wch_en = should_write_pixel;
    // match the latency of the bram
    assign wch_addr = (x_it >= BRAM_LATENCY) ? (x_it - BRAM_LATENCY) : 0;
    assign wch_data = {4'b0000, header[31:20], z_zero[15:0]};

    //reg [31:0] fma_op_diff;
    //reg [31:0] fma_op_zero;
    //wire [31:0] fma_op_updated_zero = fma_op_zero + fma_op_diff * core_id;
    
    wire valid;
    assign valid = (x_it >= BRAM_LATENCY) && (rasterizer_state == WRITEBACK);

    wire[7:0] x_len = header[19:12];

    always @(posedge clk) begin
        if(!nreset) begin
            // initialize all registers
            header <= 0;
            lambda_zero[0] <= 0;
            lambda_zero[1] <= 0;
            lambda_diff[0] <= 0;
            lambda_diff[1] <= 0;
            lambda_diff[2] <= 0;
            lambda_diff[3] <= 0;
            z_zero <= 0;
            z_diff[0] <= 0;
            z_diff[1] <= 0;
            x_it <= 0;

            // data collection registers
            data_it <= 0;
            skip_triangle <= 0;
            is_end_triangle <= 0;
            rasterizer_state <= IDLE;

            // multiply unit
            //fma_op_zero <= 0;
            //fma_op_diff <= 0;

            // axis
            //valid <= 0;
        end
        // handshake handler
        else if (is_handshake) begin
            // iterator increment logic
            if(data_it >= 9) begin
                data_it <= 0;
                x_it <= 0;

                // if not skipping & it's not the last triangle, 
                // go to preprocessing stage, and deassert ready
                if(!skip_triangle && !is_end_triangle) rasterizer_state <= PREPROCESSING;
                // if last triangle goto writeback stage - and wait
                else if(is_end_triangle) rasterizer_state <= WRITEBACK;
            end
            else begin
                data_it <= data_it + 1;
            end

            // load all the data
            if(data_it == 0) begin
                skip_triangle <= comb_skip_triangle;
                if(!comb_skip_triangle) begin
                    header <= data[31:0];
                end
            end
            // 0, 1
            else if(data_it >= 1 && data_it <= 2 && !skip_triangle) begin
                lambda_zero[~data_it[0]] <= data[31:0];
            end
            // 11, 00, 01, 10
            else if(data_it >= 3 && data_it <= 6 && !skip_triangle) begin
                lambda_diff[data_it[1:0]] <= data[31:0];
            end
            else if(data_it == 7 && !skip_triangle) begin
                z_zero <= data[31:0];
            end
            else if(data_it >= 8 && data_it <= 9 && !skip_triangle) begin
                z_diff[data_it[0]] <= data[31:0];
            end
        end
        // preprocessing, setup initial values and 
        // move triangle parameters to the start of the current scanline
        else if(rasterizer_state == PREPROCESSING) begin
            //z_zero <= fma_op_updated_zero;
            lambda_zero[0] <= lambda_zero[0] + lambda_diff[1] * core_id;
            lambda_zero[1] <= lambda_zero[1] + lambda_diff[3] * core_id;
            z_zero <= z_zero + z_diff[0] * core_id;

            // position zero
            x_it <= 0;
            rasterizer_state <= RASTERIZING;
        end
        // rasterizer
        else if(rasterizer_state == RASTERIZING) begin

            if(x_it >= BRAM_LATENCY) begin
                // lambda update
                lambda_zero[0] <= lambda_zero[0] + lambda_diff[0];
                lambda_zero[1] <= lambda_zero[1] + lambda_diff[2];

                // z update
                z_zero <= z_zero + z_diff[0];
            end

            // if more than x_len + BRAM_LATENCY all pixels have been processed, go back to idle
            if(x_it >= x_len + BRAM_LATENCY) begin
                rasterizer_state <= IDLE;
                x_it <= 0;
            end
            else begin
                x_it <= x_it + 1;
            end
        end
        // write back - convert to axis
        else if(rasterizer_state == WRITEBACK) begin

//            if(x_it >= BRAM_LATENCY) begin
//                // lambda update
//                lambda_zero[0] <= lambda_zero[0] + lambda_diff[0];
//                lambda_zero[1] <= lambda_zero[1] + lambda_diff[2];
//                
//                // z update
//                z_zero <= z_zero + z_diff[0];
//            end

            // if more than x_len + BRAM_LATENCY all pixels have been processed, go back to idle
            if(x_it >= header[19:12] + BRAM_LATENCY) begin
                //rasterizer_state <= IDLE;
                x_it <= 0;
            end
            else begin
                x_it <= x_it + 1;
            end
        end
    end

endmodule