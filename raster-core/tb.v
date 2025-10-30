`timescale 1ns / 100ps

module tb_raster_core;

    // Parameters - make BRAM latency configurable
    parameter integer CORE_ID = 1;
    parameter integer LWIDTH = 32;
    parameter integer BRAM_LATENCY = 1; // Variable latency - can be changed for testing
    parameter integer BRAM_DEPTH = 512;
    parameter integer BRAM_ADDR_WIDTH = 9; // log2(512)
    parameter integer CLK_PERIOD = 10; // 100MHz clock

    // Test signals
    reg clk;
    reg nreset;
    reg is_handshake;
    reg [LWIDTH-1:0] data;
    wire ready;
    
    // BRAM interface signals
    wire rch_en;
    wire [31:0] rch_addr;
    reg [31:0] rch_data;
    wire wch_en;
    wire [31:0] wch_addr;
    wire [31:0] wch_data;

    // BRAM memory model with configurable latency
    reg [31:0] bram_memory [0:BRAM_DEPTH-1];
    reg [31:0] read_pipeline [0:BRAM_LATENCY-1];
    reg [BRAM_LATENCY-1:0] read_valid_pipeline;
    
    // Variables for test control
    integer i;
    integer test_case;
    integer cycle_count;
    integer timeout_counter;
    
    // DUT instantiation
    raster_core_impl #(
        .core_id(CORE_ID),
        .LWIDTH(LWIDTH),
        .BRAM_LATENCY(BRAM_LATENCY+1)
    ) dut (
        .clk(clk),
        .nreset(nreset),
        .is_handshake(is_handshake),
        .data(data),
        .ready(ready),
        .rch_en(rch_en),
        .rch_addr(rch_addr),
        .rch_data(rch_data),
        .wch_en(wch_en),
        .wch_addr(wch_addr),
        .wch_data(wch_data)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // BRAM memory model with variable latency
    always @(posedge clk) begin
        if (!nreset) begin
            // Reset pipeline
            for (i = 0; i < BRAM_LATENCY; i = i + 1) begin
                read_pipeline[i] <= 32'h0;
            end
            read_valid_pipeline <= {BRAM_LATENCY{1'b0}};
            rch_data <= 32'h0;
        end else begin
            // Always shift pipeline for read latency (regardless of new reads)
            if (BRAM_LATENCY > 1) begin
                for (i = BRAM_LATENCY-1; i > 0; i = i - 1) begin
                    read_pipeline[i] <= read_pipeline[i-1];
                    read_valid_pipeline[i] <= read_valid_pipeline[i-1];
                end
            end
            
            // Handle new read request - load into pipeline stage 0
            if (rch_en && rch_addr < BRAM_DEPTH) begin
                read_pipeline[0] <= bram_memory[rch_addr];
                read_valid_pipeline[0] <= 1'b1;
                $display("Time %0t: BRAM Read Request - Addr: 0x%08h, Data: 0x%08h", 
                         $time, rch_addr, bram_memory[rch_addr]);
            end else begin
                // No new read, but don't clear valid bit - just load zeros into stage 0
                read_pipeline[0] <= 32'h0;
                read_valid_pipeline[0] <= 1'b0;
            end
            
            // Always update output based on latency
            if (BRAM_LATENCY == 1) begin
                // For latency 1, output directly from pipeline stage 0
                rch_data <= read_pipeline[0];
                if (read_valid_pipeline[0]) begin
                    $display("Time %0t: BRAM Read Output - Data: 0x%08h (latency %0d)", 
                             $time, read_pipeline[0], BRAM_LATENCY);
                end
            end else begin
                // For multi-cycle latency, always update output from final pipeline stage
                rch_data <= read_pipeline[BRAM_LATENCY-1];
                if (read_valid_pipeline[BRAM_LATENCY-1]) begin
                    $display("Time %0t: BRAM Read Output - Data: 0x%08h (latency %0d)", 
                             $time, read_pipeline[BRAM_LATENCY-1], BRAM_LATENCY);
                end
            end
            
            // Handle write request
            if (wch_en && wch_addr < BRAM_DEPTH) begin
                bram_memory[wch_addr] <= wch_data;
                $display("Time %0t: BRAM Write - Addr: 0x%08h, Data: 0x%08h", 
                         $time, wch_addr, wch_data);
            end
        end
    end

    // Initialize BRAM from file
    initial begin
        // Initialize memory to zero first
        for (i = 0; i < BRAM_DEPTH; i = i + 1) begin
            bram_memory[i] = 32'h0;
        end
        
        // Load memory from file using $readmemh which is safer
        $display("Loading BRAM memory from memory_init.hex...");
        $readmemh("/mnt/data/Prism-FPGA/raster-core/memory_init.hex", bram_memory);
        $display("Memory initialization completed");
    end

    // Task to send triangle data via handshake
    task send_triangle_data;
        input [31:0] header_data;
        input [31:0] lambda_zero_0, lambda_zero_1;
        input [31:0] lambda_diff_0, lambda_diff_1, lambda_diff_2, lambda_diff_3;
        input [15:0] z_zero_data;
        input [15:0] z_diff_0, z_diff_1;
        
        begin
            $display("Time %0t: Sending triangle data...", $time);
            
            // Send header (contains y_start, y_end, x_len)
            @(negedge clk);
            data = header_data;
            is_handshake = 1'b1;
            @(posedge clk);
            @(negedge clk);
            is_handshake = 1'b0;
            
            // Send lambda_zero[0]
            @(negedge clk);
            data = lambda_zero_0;
            is_handshake = 1'b1;
            @(posedge clk);
            @(negedge clk);
            is_handshake = 1'b0;
            
            // Send lambda_zero[1]
            @(negedge clk);
            data = lambda_zero_1;
            is_handshake = 1'b1;
            @(posedge clk);
            @(negedge clk);
            is_handshake = 1'b0;
            
            // Send lambda_diff[0]
            @(negedge clk);
            data = lambda_diff_0;
            is_handshake = 1'b1;
            @(posedge clk);
            @(negedge clk);
            is_handshake = 1'b0;
            
            // Send lambda_diff[1]
            @(negedge clk);
            data = lambda_diff_1;
            is_handshake = 1'b1;
            @(posedge clk);
            @(negedge clk);
            is_handshake = 1'b0;
            
            // Send lambda_diff[2]
            @(negedge clk);
            data = lambda_diff_2;
            is_handshake = 1'b1;
            @(posedge clk);
            @(negedge clk);
            is_handshake = 1'b0;
            
            // Send lambda_diff[3]
            @(negedge clk);
            data = lambda_diff_3;
            is_handshake = 1'b1;
            @(posedge clk);
            @(negedge clk);
            is_handshake = 1'b0;
            
            // Send z_zero
            @(negedge clk);
            data = {16'h0, z_zero_data};
            is_handshake = 1'b1;
            @(posedge clk);
            @(negedge clk);
            is_handshake = 1'b0;
            
            // Send z_diff[0]
            @(negedge clk);
            data = {16'h0, z_diff_0};
            is_handshake = 1'b1;
            @(posedge clk);
            @(negedge clk);
            is_handshake = 1'b0;
            
            // Send z_diff[1]
            @(negedge clk);
            data = {16'h0, z_diff_1};
            is_handshake = 1'b1;
            @(posedge clk);
            @(negedge clk);
            is_handshake = 1'b0;
            
            $display("Time %0t: Triangle data sent completely", $time);
        end
    endtask

    // Task to wait for rasterization to complete
    task wait_for_completion;
        begin
            $display("Time %0t: Waiting for rasterization to complete...", $time);
            cycle_count = 0;
            while (!ready && cycle_count < 1000) begin
                @(negedge clk);
                cycle_count = cycle_count + 1;
            end
            if (cycle_count >= 1000) begin
                $display("ERROR: Rasterization did not complete within 1000 cycles");
            end else begin
                $display("Time %0t: Rasterization completed in %0d cycles", $time, cycle_count);
            end
        end
    endtask

    // Main test sequence
    initial begin
        $display("=== Raster Core Testbench ===");
        $display("BRAM Latency: %0d cycles", BRAM_LATENCY);
        $display("Core ID: %0d", CORE_ID);
        
        // Initialize signals
        nreset = 1'b0;
        is_handshake = 1'b0;
        data = 32'h0;
        rch_data = 32'h0;
        test_case = 0;
        cycle_count = 0;
        
        // Reset sequence
        repeat(5) @(negedge clk);
        nreset = 1'b1;
        repeat(5) @(negedge clk);
        
        $display("Time %0t: Reset completed", $time);
        
        // Test Case 1: Simple triangle that should be processed
        test_case = 1;
        $display("\n=== Test Case %0d: Simple Triangle ===", test_case);
        
        send_triangle_data(
            32'h00110080,    // header: y_start=0, y_end=20, x_len=128
            32'h10000000,    // lambda_zero[0]
            32'h20000000,    // lambda_zero[1]
            32'h00100000,    // lambda_diff[0] - dx increment
            32'h00200000,    // lambda_diff[1] - dy increment
            32'h00150000,    // lambda_diff[2] - dx increment
            32'h00250000,    // lambda_diff[3] - dy increment
            16'h1000,        // z_zero
            16'h0010,        // z_diff[0]
            16'h0020         // z_diff[1]
        );
        
        wait_for_completion();
        
        // Test Case 2: Triangle that should be skipped (core_id outside range)
        test_case = 2;
        $display("\n=== Test Case %0d: Skipped Triangle ===", test_case);
        
        send_triangle_data(
            32'h00050040,    // header: y_start=5, y_end=5, x_len=64 (should skip if core_id=0)
            32'h30000000,    // lambda_zero[0]
            32'h40000000,    // lambda_zero[1]
            32'h00300000,    // lambda_diff[0]
            32'h00400000,    // lambda_diff[1]
            32'h00350000,    // lambda_diff[2]
            32'h00450000,    // lambda_diff[3]
            16'h2000,        // z_zero
            16'h0030,        // z_diff[0]
            16'h0040         // z_diff[1]
        );
        
        wait_for_completion();
        
        // Test Case 3: Different BRAM latency test (if parameterized)
        test_case = 3;
        $display("\n=== Test Case %0d: Medium Triangle ===", test_case);
        
        send_triangle_data(
            32'h000A0060,    // header: y_start=0, y_end=10, x_len=96
            32'h08000000,    // lambda_zero[0]
            32'h18000000,    // lambda_zero[1]
            32'h00080000,    // lambda_diff[0]
            32'h00180000,    // lambda_diff[1]
            32'h00120000,    // lambda_diff[2]
            32'h00220000,    // lambda_diff[3]
            16'h0800,        // z_zero
            16'h0008,        // z_diff[0]
            16'h0018         // z_diff[1]
        );
        
        wait_for_completion();
        
        // Display some memory contents to verify writes
        $display("\n=== Memory Verification ===");
        for (i = 0; i < 16; i = i + 1) begin
            $display("BRAM[%3d] = 0x%08h", i, bram_memory[i]);
        end
        
        $display("\n=== Testbench Completed ===");
        repeat(10) @(negedge clk);
        //$finish;
    end

    // Monitor important signals
    always @(posedge clk) begin
        if (rch_en) begin
            $display("Time %0t: BRAM Read - Addr: 0x%08h", $time, rch_addr);
        end
    end

    // tick counter - end after timeout
    initial begin
        timeout_counter = 0;
        forever begin
            @(posedge clk);
            if (nreset) begin
                timeout_counter = timeout_counter + 1;
                if (timeout_counter > 10000) begin
                    $display("ERROR: Testbench timeout after %0d cycles", timeout_counter);
                    $finish;
                end
            end else begin
                timeout_counter = 0;
            end
        end
    end
    
    // Dump waveforms
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_raster_core);
    end

endmodule