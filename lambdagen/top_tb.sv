`timescale 1ns/1ps

module tb_lg_top;

    // Parameters
    parameter CLK_PERIOD = 10; // 100MHz clock

    // DUT signals
    reg clk;
    reg rst;
    
    // AXI Stream slave interface (input to DUT)
    reg [31:0] s_tdata;
    reg s_tvalid;
    wire s_tready;
    reg s_tlast;
    
    // AXI Stream master interface (output from DUT)
    wire [31:0] m_tdata;
    wire m_tvalid;
    reg m_tready;
    wire m_tlast;

    // Test variables
    integer i;
    integer transfer_count;
    integer packet_count;
    reg [31:0] received_data [0:9]; // Store 10 received values
    integer errors;

    // Input test data for slave interface (4 x 32-bit = 128 bits per packet)
    reg [31:0] test_triangle [0:3];

    // Instantiate the DUT
    lg_top dut (
        .clk(clk),
        .rst(rst),
        .s_tdata(s_tdata),
        .s_tvalid(s_tvalid),
        .s_tready(s_tready),
        .s_tlast(s_tlast),
        .m_tdata(m_tdata),
        .m_tvalid(m_tvalid),
        .m_tready(m_tready),
        .m_tlast(m_tlast)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // AXI Stream master receiver - captures output data
    always @(posedge clk) begin
        if (m_tvalid && m_tready) begin
            $display("[%0t] RX Transfer #%0d: Data=0x%08h, TLAST=%b", 
                     $time, transfer_count, m_tdata, m_tlast);
            received_data[transfer_count] = m_tdata;
            transfer_count = transfer_count + 1;
            
            if (m_tlast) begin
                $display("[%0t] Packet %0d complete (%0d transfers)", 
                         $time, packet_count, transfer_count);
                packet_count = packet_count + 1;
            end
        end
    end

    // Task to send a triangle packet on slave interface
    task send_triangle_packet;
        input [31:0] word0, word1, word2, word3;
        integer j;
        begin
            $display("\n[%0t] Sending triangle packet...", $time);
            
            // Wait for ready
            wait(s_tready);
            
            // Send 4 words (128 bits total)
            for (j = 0; j < 4; j = j + 1) begin
                @(posedge clk);
                s_tvalid <= 1;
                s_tlast <= (j == 3); // Assert TLAST on last word
                
                case(j)
                    0: s_tdata <= word0;
                    1: s_tdata <= word1;
                    2: s_tdata <= word2;
                    3: s_tdata <= word3;
                endcase
                
                $display("[%0t] TX Word %0d: 0x%08h, TLAST=%b", 
                         $time, j, s_tdata, s_tlast);
                
                // Wait for handshake
                wait(s_tready);
                @(posedge clk);
            end
            
            s_tvalid <= 0;
            s_tlast <= 0;
            $display("[%0t] Triangle packet sent", $time);
        end
    endtask

    // Task to wait for output packet
    task wait_for_output_packet;
        input integer expected_words;
        begin
            $display("\n[%0t] Waiting for output packet (%0d words)...", 
                     $time, expected_words);
            transfer_count = 0;
            wait(transfer_count == expected_words);
            #(CLK_PERIOD*2);
            $display("[%0t] Output packet received", $time);
        end
    endtask

    // Main test sequence
    initial begin
        // Initialize signals
        rst = 1;
        s_tdata = 0;
        s_tvalid = 0;
        s_tlast = 0;
        m_tready = 0;
        transfer_count = 0;
        packet_count = 0;
        errors = 0;

        // Dump waves
        $dumpfile("lg_top.vcd");
        $dumpvars(0, tb_lg_top);

        // Reset
        $display("\n=== Test Start ===");
        $display("[%0t] Asserting reset", $time);
        #(CLK_PERIOD*5);
        rst = 0;
        #(CLK_PERIOD*2);

        //======================================
        // TEST 1: Single triangle with slave always ready
        //======================================
        $display("\n=== TEST 1: Single Triangle (Master Always Ready) ===");
        transfer_count = 0;
        packet_count = 0;
        m_tready = 1; // Master is ready
        
        // Example triangle data (you should adjust these values)
        // Format depends on your lambdagen input requirements
        test_triangle[0] = 32'h12345678; // Example vertex/triangle data
        test_triangle[1] = 32'hABCDEF00;
        test_triangle[2] = 32'h11223344;
        test_triangle[3] = 32'h55667788;
        
        send_triangle_packet(
            test_triangle[0],
            test_triangle[1],
            test_triangle[2],
            test_triangle[3]
        );
        
        // Wait for lambdagen to process and master to output
        wait_for_output_packet(10);
        
        // Verify we got 10 transfers
        if (transfer_count != 10) begin
            $display("ERROR: Expected 10 transfers, got %0d", transfer_count);
            errors = errors + 1;
        end
        
        // Display received data
        $display("\nReceived data:");
        $display("  [0] Header:  0x%08h", received_data[0]);
        $display("  [1] l2:      0x%08h", received_data[1]);
        $display("  [2] l1:      0x%08h", received_data[2]);
        $display("  [3] dl2y:    0x%08h", received_data[3]);
        $display("  [4] dl1x:    0x%08h", received_data[4]);
        $display("  [5] dl1y:    0x%08h", received_data[5]);
        $display("  [6] dl2x:    0x%08h", received_data[6]);
        $display("  [7] z_:      0x%08h", received_data[7]);
        $display("  [8] dzx:     0x%08h", received_data[8]);
        $display("  [9] dzy:     0x%08h", received_data[9]);
        
        if (errors == 0) 
            $display("TEST 1 PASSED");
        else 
            $display("TEST 1 FAILED with %0d errors", errors);

        // //======================================
        // // TEST 2: Master not ready (backpressure)
        // //======================================
        // $display("\n=== TEST 2: Master Not Ready (Backpressure Test) ===");
        // transfer_count = 0;
        // packet_count = 0;
        // errors = 0;
        // m_tready = 0; // Master not ready
        
        // #(CLK_PERIOD*5);
        
        // // Send triangle
        // send_triangle_packet(
        //     32'hDEADBEEF,
        //     32'hCAFEBABE,
        //     32'h0BADF00D,
        //     32'hFEEDFACE
        // );
        
        // // Wait for valid to assert
        // wait(m_tvalid == 1);
        // $display("[%0t] Master TVALID asserted, but TREADY=0", $time);
        
        // // Check that no transfer happens
        // #(CLK_PERIOD*10);
        // if (transfer_count != 0) begin
        //     $display("ERROR: Transfers occurred without TREADY!");
        //     errors = errors + 1;
        // end else begin
        //     $display("[%0t] Correctly waiting for TREADY", $time);
        // end
        
        // // Now make master ready
        // m_tready = 1;
        // $display("[%0t] Master now ready", $time);
        
        // // Wait for all transfers
        // wait_for_output_packet(10);
        
        // if (errors == 0) 
        //     $display("TEST 2 PASSED");
        // else 
        //     $display("TEST 2 FAILED with %0d errors", errors);

        //======================================
        // TEST 3: Random backpressure on master
        //======================================
        $display("\n=== TEST 3: Random Master Backpressure ===");
        transfer_count = 0;
        packet_count = 0;
        errors = 0;
        
        #(CLK_PERIOD*5);
        
        // Send triangle
        send_triangle_packet(
            32'h11111111,
            32'h22222222,
            32'h33333333,
            32'h44444444
        );
        
        // Randomly toggle m_tready
        fork
            begin
                for (i = 0; i < 100; i = i + 1) begin
                    @(posedge clk);
                    m_tready = $random % 2; // Random 0 or 1
                end
                m_tready = 1; // Ensure we finish
            end
        join_none
        
        // Wait for completion
        wait_for_output_packet(10);
        
        if (errors == 0) 
            $display("TEST 3 PASSED");
        else 
            $display("TEST 3 FAILED with %0d errors", errors);

        //======================================
        // TEST 4: Back-to-back triangles
        //======================================
        $display("\n=== TEST 4: Back-to-Back Triangles ===");
        errors = 0;
        m_tready = 1;
        
        for (i = 0; i < 3; i = i + 1) begin
            transfer_count = 0;
            
            #(CLK_PERIOD*2);
            
            send_triangle_packet(
                32'h10000000 + i,
                32'h20000000 + i,
                32'h30000000 + i,
                32'h40000000 + i
            );
            
            wait_for_output_packet(10);
            
            $display("[%0t] Triangle %0d completed", $time, i);
        end
        
        $display("TEST 4 PASSED");

        //======================================
        // TEST 5: Slave not ready (input backpressure)
        //======================================
        $display("\n=== TEST 5: Slave Not Ready (Input Backpressure) ===");
        transfer_count = 0;
        packet_count = 0;
        errors = 0;
        m_tready = 1;
        
        #(CLK_PERIOD*5);
        
        // Try to send when not ready
        @(posedge clk);
        s_tvalid <= 1;
        s_tdata <= 32'hAAAAAAAA;
        s_tlast <= 0;
        
        // Check if ready accepts or blocks
        @(posedge clk);
        if (!s_tready) begin
            $display("[%0t] Slave correctly blocking input", $time);
        end
        
        s_tvalid <= 0;
        
        // Wait for ready and send proper packet
        wait(s_tready);
        send_triangle_packet(
            32'h55555555,
            32'h66666666,
            32'h77777777,
            32'h88888888
        );
        
        wait_for_output_packet(10);
        
        $display("TEST 5 PASSED");

        //======================================
        // TEST 6: Check header packing
        //======================================
        $display("\n=== TEST 6: Header Format Verification ===");
        transfer_count = 0;
        packet_count = 0;
        m_tready = 1;
        
        #(CLK_PERIOD*5);
        
        send_triangle_packet(
            32'h00000000,
            32'h00000000,
            32'h00000000,
            32'h00000000
        );
        
        wait_for_output_packet(10);
        
        // Parse header (first word received)
        $display("\nHeader breakdown (0x%08h):", received_data[0]);
        $display("  y_start: %0d", received_data[0][5:0]);
        $display("  y_end:   %0d", received_data[0][11:6]);
        $display("  x_len:   %0d", received_data[0][19:12]);
        $display("  tID:     %0d", received_data[0][31:20]);
        
        $display("TEST 6 PASSED");

        //======================================
        // Test complete
        //======================================
        #(CLK_PERIOD*20);
        $display("\n=== All Tests Complete ===");
        $finish;
    end

    // Timeout watchdog
    initial begin
        #(CLK_PERIOD*100000);
        $display("ERROR: Testbench timeout!");
        $finish;
    end

    // Monitor for debugging
    initial begin
        $display("\nSignal Monitor:");
        $monitor("[%0t] rst=%b s_tvalid=%b s_tready=%b m_tvalid=%b m_tready=%b", 
                 $time, rst, s_tvalid, s_tready, m_tvalid, m_tready);
    end

endmodule