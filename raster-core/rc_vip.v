import axi4stream_vip_pkg::*;
import bus_test_axi4stream_vip_0_0_pkg::*;
import bus_test_axi4stream_vip_1_0_pkg::*;

module rc_tb;

    bit aclk = 0, aresetn = 0;
    xil_axi4stream_data_byte data_array[10][4]; // 10 beats x 4 bytes (32-bit per beat)
    axi4stream_ready_gen ready_gen;

    xil_axi4stream_data_beat data_beats[10];

    // 50 MHz
    always #10ns aclk = ~aclk;

    bus_test_wrapper UUT(.aclk(aclk), .aresetn(aresetn));

    // Correct connection of agents to VIPs based on block diagram:
    bus_test_axi4stream_vip_0_0_slv_t slave_agent;
    bus_test_axi4stream_vip_1_0_mst_t master_agent;

    axi4stream_transaction wr_transaction;

    initial begin
        aresetn = 0;
        #340ns;
        aresetn = 1;
    end

    // Task creating the triangle data packet
    task send_triangle_data(
        input [31:0] header_data,
        input [31:0] lambda_zero_0, lambda_zero_1,
        input [31:0] lambda_diff_0, lambda_diff_1, lambda_diff_2, lambda_diff_3,
        input [15:0] z_zero_data, z_diff_0, z_diff_1
    );
        begin
            // Break 32-bit words into bytes (little-endian)
            {data_array[0][3], data_array[0][2], data_array[0][1], data_array[0][0]} = header_data;
            {data_array[1][3], data_array[1][2], data_array[1][1], data_array[1][0]} = lambda_zero_0;
            {data_array[2][3], data_array[2][2], data_array[2][1], data_array[2][0]} = lambda_zero_1;
            {data_array[3][3], data_array[3][2], data_array[3][1], data_array[3][0]} = lambda_diff_0;
            {data_array[4][3], data_array[4][2], data_array[4][1], data_array[4][0]} = lambda_diff_1;
            {data_array[5][3], data_array[5][2], data_array[5][1], data_array[5][0]} = lambda_diff_2;
            {data_array[6][3], data_array[6][2], data_array[6][1], data_array[6][0]} = lambda_diff_3;
            {data_array[7][3], data_array[7][2], data_array[7][1], data_array[7][0]} = {16'b0, z_zero_data};
            {data_array[8][3], data_array[8][2], data_array[8][1], data_array[8][0]} = {16'b0, z_diff_0};
            {data_array[9][3], data_array[9][2], data_array[9][1], data_array[9][0]} = {16'b0, z_diff_1};

            // and the data beats
            for (int i = 0; i < 10; i++) begin
                data_beats[i] = {data_array[i][3], data_array[i][2], data_array[i][1], data_array[i][0]};
            end

            $display("Time %0t: Sending triangle data packet...", $time);

            // Set each 32-bit beat individually - pack bytes into 32-bit word
            for (int i = 0; i < 10; i++) begin
                wr_transaction = master_agent.driver.create_transaction("write transaction");
                wr_transaction.set_data(data_array[i]);
                if(i == 9) begin
                    wr_transaction.set_last(1'b1); // Mark last transfer
                end
                wr_transaction.set_delay(0);
                master_agent.driver.send(wr_transaction);
            end

            $display("Time %0t: Second triangle data sent successfully", $time);
        end
    endtask

    initial begin
        // Connect master agent to VIP_1 (input)
        master_agent = new("master vip agent", UUT.bus_test_i.axi4stream_vip_1.inst.IF);
        master_agent.start_master();

        // Connect slave agent to VIP_0 (output)
        slave_agent = new("slave vip agent", UUT.bus_test_i.axi4stream_vip_0.inst.IF);
        slave_agent.start_slave();

        wait (aresetn == 1'b1);

        send_triangle_data(
            32'h00110080,    // header
            32'h10000000,    // lambda_zero[0]
            32'h20000000,    // lambda_zero[1]
            32'h00100000,    // lambda_diff[0]
            32'h00200000,    // lambda_diff[1]
            32'h00150000,    // lambda_diff[2]
            32'h00250000,    // lambda_diff[3]
            16'h1000,        // z_zero
            16'h0010,        // z_diff[0]
            16'h0020         // z_diff[1]
        );

        #240ns;

        // Wait for processing to complete
        #50us;
        
        $display("\n=== Test Case 1 Complete ===\n");
        
        // Additional test case with different triangle
        send_triangle_data(
            32'h000A007F,    // header: y_start=31, y_end=10, x_len=96
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
        
        #100ns;

        ready_gen = slave_agent.driver.create_ready("ready_gen");
        ready_gen.set_ready_policy(XIL_AXI4STREAM_READY_GEN_OSC);
        ready_gen.set_low_time(1);
        ready_gen.set_high_time(2);
        slave_agent.driver.send_tready(ready_gen);
        
        // Wait for second test to complete
        #50us;
        
        $display("\n=== Test Case 2 Complete ===\n");
        $display("=== All Tests Complete ===");
        $finish;
    end

endmodule
