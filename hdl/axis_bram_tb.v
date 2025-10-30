`timescale 1ns / 100ps

module axis_bram_tb;

    // Parameters
    parameter integer C_S_AXIS_TDATA_WIDTH = 32;
    parameter integer SRC_ADDR_WIDTH = 12;
    parameter integer SRC_ADDR_MAX = 1024;
    parameter integer CLK_PERIOD = 10; // 100MHz clock
    
    // Testbench signals
    reg tb_clk;
    reg tb_resetn;
    reg tb_tready;
    wire [C_S_AXIS_TDATA_WIDTH-1:0] tb_tdata;
    wire [(C_S_AXIS_TDATA_WIDTH/8)-1:0] tb_tstrb;
    wire tb_tlast;
    wire tb_tvalid;
    wire [SRC_ADDR_WIDTH-1:0] tb_src_addr;
    wire [C_S_AXIS_TDATA_WIDTH-1:0] tb_src_data;
    wire tb_src_ready;
    wire tb_src_enable;
    wire tb_done;
    
    // Memory model with 2-cycle latency
    reg [C_S_AXIS_TDATA_WIDTH-1:0] memory [0:SRC_ADDR_MAX-1];
    reg [C_S_AXIS_TDATA_WIDTH-1:0] mem_pipeline1;
    reg [C_S_AXIS_TDATA_WIDTH-1:0] mem_pipeline2;
    reg mem_valid_pipeline1;
    reg mem_valid_pipeline2;
    
    // Memory read with 2-cycle latency
    always @(posedge tb_clk) begin
        if (!tb_resetn) begin
            mem_pipeline1 <= 0;
            mem_pipeline2 <= 0;
            mem_valid_pipeline1 <= 0;
            mem_valid_pipeline2 <= 0;
        end else begin
            // Cycle 1: Register address and read
            if (tb_src_enable) begin
                mem_pipeline1 <= memory[tb_src_addr];
                mem_valid_pipeline1 <= 1'b1;
            end else begin
                mem_pipeline1 <= 0;
                mem_valid_pipeline1 <= 1'b0;
            end
            
            // Cycle 2: Pipeline stage
            mem_pipeline2 <= mem_pipeline1;
            mem_valid_pipeline2 <= mem_valid_pipeline1;
        end
    end
    
    assign tb_src_data = mem_pipeline2;
    assign tb_src_ready = 1'b1;
    
    // TREADY pattern configuration
    // Pattern types:
    // 0: Always ready
    // 1: Toggle every cycle
    // 2: Ready every 2 cycles
    // 3: Ready every 4 cycles
    // 4: Random pattern
    // 5: Custom pattern (modify pattern_custom array)
    
    parameter READY_PATTERN = 0; // Change this to select pattern
    integer ready_counter = 0;
    reg [31:0] pattern_custom [0:15]; // Custom pattern array
    integer custom_index = 0;
    
    // TREADY pattern generator
    always @(posedge tb_clk) begin
        if (!tb_resetn) begin
            tb_tready <= 1'b0;
            ready_counter <= 0;
            custom_index <= 0;
        end else begin
            case (READY_PATTERN)
                0: begin // Always ready
                    tb_tready <= 1'b1;
                end
                
                1: begin // Toggle every cycle
                    tb_tready <= ~tb_tready;
                end
                
                2: begin // Ready every 2 cycles
                    ready_counter <= ready_counter + 1;
                    if (ready_counter == 0)
                        tb_tready <= 1'b1;
                    else if (ready_counter == 1) begin
                        tb_tready <= 1'b0;
                        ready_counter <= 0;
                    end
                end
                
                3: begin // Ready every 4 cycles
                    ready_counter <= ready_counter + 1;
                    if (ready_counter == 0)
                        tb_tready <= 1'b1;
                    else if (ready_counter >= 3) begin
                        tb_tready <= 1'b0;
                        ready_counter <= 0;
                    end else
                        tb_tready <= 1'b0;
                end
                
                4: begin // Random pattern (pseudo-random)
                    tb_tready <= $random % 2;
                end
                
                5: begin // Custom pattern
                    tb_tready <= pattern_custom[custom_index][0];
                    custom_index <= (custom_index + 1) % 16;
                end
                
                default: tb_tready <= 1'b1;
            endcase
        end
    end
    
    // Clock generation
    initial begin
        tb_clk = 0;
        forever #(CLK_PERIOD/2) tb_clk = ~tb_clk;
    end
    
    // Transaction counter
    integer transaction_count = 0;
    
    // Monitor AXI Stream transactions
    always @(posedge tb_clk) begin
        if (tb_tvalid && tb_tready) begin
            transaction_count = transaction_count + 1;
            $display("[%0t] Transaction #%0d: TDATA=0x%08h, TLAST=%b", 
                     $time, transaction_count, tb_tdata, tb_tlast);
        end
    end
    
    // DUT instantiation
    AXI_BRAM2STREAM_MASTER #(
        .C_S_AXIS_TDATA_WIDTH(C_S_AXIS_TDATA_WIDTH),
        .SRC_ADDR_WIDTH(SRC_ADDR_WIDTH),
        .SRC_ADDR_MAX(SRC_ADDR_MAX)
    ) dut (
        .S_AXIS_ACLK(tb_clk),
        .S_AXIS_ARESETN(tb_resetn),
        .S_AXIS_TREADY(tb_tready),
        .S_AXIS_TDATA(tb_tdata),
        .S_AXIS_TSTRB(tb_tstrb),
        .S_AXIS_TLAST(tb_tlast),
        .S_AXIS_TVALID(tb_tvalid),
        .src_addr(tb_src_addr),
        .src_data(tb_src_data),
        .src_ready(tb_src_ready),
        .src_enable(tb_src_enable),
        .done(tb_done)
    );
    
    // Test stimulus
    integer i;
    initial begin
        // Initialize waveform dump
        $dumpfile("axis_bram_tb.vcd");
        $dumpvars(0, axis_bram_tb);
        
        // Initialize memory with test pattern
        for (i = 0; i < SRC_ADDR_MAX; i = i + 1) begin
            memory[i] = 32'hA0000000 + i; // Pattern: 0xA0000000, 0xA0000001, ...
        end
        
        // Initialize custom ready pattern (example)
        pattern_custom[0] = 1;
        pattern_custom[1] = 1;
        pattern_custom[2] = 0;
        pattern_custom[3] = 1;
        pattern_custom[4] = 0;
        pattern_custom[5] = 0;
        pattern_custom[6] = 1;
        pattern_custom[7] = 1;
        for (i = 8; i < 16; i = i + 1) begin
            pattern_custom[i] = 1;
        end
        
        // Initialize signals
        tb_resetn = 0;
        transaction_count = 0;
        
        $display("=== AXI BRAM Serializer Testbench ===");
        $display("TREADY Pattern: %0d", READY_PATTERN);
        $display("Memory Latency: 2 cycles");
        $display("=====================================");
        
        // Reset sequence
        #(CLK_PERIOD * 5);
        tb_resetn = 1;
        $display("[%0t] Reset released", $time);
        
        // Wait for transactions to complete
        wait(tb_done);
        $display("[%0t] Transfer complete! Total transactions: %0d", $time, transaction_count);
        
        // Additional cycles for observation
        #(CLK_PERIOD * 10);
        
        // Finish simulation
        $display("=== Simulation Complete ===");
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #(CLK_PERIOD * 10000);
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule
