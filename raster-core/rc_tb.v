import axi4stream_vip_pkg::*;
import bus_test_axi4stream_vip_0_0_pkg::*;
import bus_test_axi4stream_vip_1_0_pkg::*;

module rc_tb;

    bit aclk = 0, aresetn = 0;
    xil_axi4stream_data_byte data_bytes[4]; // 10 beats x 4 bytes (32-bit per beat)
    axi4stream_ready_gen ready_gen;

    // triangle FIFO
    reg[31:0] triangle_fifo[9:0];

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

    initial begin
        // Connect master agent to VIP_1 (input)
        master_agent = new("master vip agent", UUT.bus_test_i.axi4stream_vip_1.inst.IF);
        master_agent.start_master();

        // Connect slave agent to VIP_0 (output)
        slave_agent = new("slave vip agent", UUT.bus_test_i.axi4stream_vip_0.inst.IF);
        slave_agent.start_slave();

        wait (aresetn == 1'b1);

        // Set each 32-bit beat individually - pack bytes into 32-bit word
        for (int i = 0; i < 10; i++) begin
            {data_bytes[0][3], data_bytes[0][2], data_bytes[0][1], data_bytes[0][0]} = header_data;

            wr_transaction = master_agent.driver.create_transaction("write transaction");
            wr_transaction.set_data(data_bytes);
            if(i == 9) begin
                wr_transaction.set_last(1'b1); // Mark last transfer
            end
            wr_transaction.set_delay(0);
            master_agent.driver.send(wr_transaction);
        end
        
        #100ns;

        ready_gen = slave_agent.driver.create_ready("ready_gen");
        ready_gen.set_ready_policy(XIL_AXI4STREAM_READY_GEN_OSC);
        ready_gen.set_low_time(0);
        ready_gen.set_high_time(1);
        slave_agent.driver.send_tready(ready_gen);
        
        // Wait for second test to complete
        #100us;
        
        $display("\n=== Test Case 2 Complete ===\n");
        $display("=== All Tests Complete ===");
        $finish;
    end

endmodule
