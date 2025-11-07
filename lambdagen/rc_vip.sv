import axi4stream_vip_pkg::*;
import design_3_axi4stream_vip_0_0_pkg::*;
import design_3_axi4stream_vip_1_0_pkg::*;

module rc_tb;

    bit aclk = 0, aresetn = 0;
    xil_axi4stream_data_byte data_array[4][4];
    axi4stream_ready_gen ready_gen;

    always #10ns aclk = ~aclk;

    design_3_wrapper UUT(.aclk(aclk), .aresetn(aresetn));

    design_3_axi4stream_vip_1_0_slv_t slave_agent;
    design_3_axi4stream_vip_0_0_mst_t master_agent;

    axi4stream_transaction wr_transaction;

    initial begin
        aresetn = 0;
        #340ns;
        aresetn = 1;
    end

    task send_vector_128(input [127:0] vec128); 
        begin
            {data_array[0][3], data_array[0][2], data_array[0][1], data_array[0][0]} = vec128[127:96];
            {data_array[1][3], data_array[1][2], data_array[1][1], data_array[1][0]} = vec128[95:64];
            {data_array[2][3], data_array[2][2], data_array[2][1], data_array[2][0]} = vec128[63:32];
            {data_array[3][3], data_array[3][2], data_array[3][1], data_array[3][0]} = vec128[31:0];

            $display("Time %0t: Sending 128-bit vector = %h", $time, vec128);

            for (int i = 0; i < 4; i++) begin
                wr_transaction = master_agent.driver.create_transaction("write transaction");
                wr_transaction.set_data(data_array[i]);
                if(i == 3) begin
                    wr_transaction.set_last(1'b1);
                end
                wr_transaction.set_delay(0);
                master_agent.driver.send(wr_transaction);
                
            end

            $display("Time %0t: Vector transmission complete.", $time);
        end
    endtask

    initial begin
        master_agent = new("master vip agent", UUT.design_3_i.axi4stream_vip_0.inst.IF);
        master_agent.start_master();

        slave_agent = new("slave vip agent", UUT.design_3_i.axi4stream_vip_1.inst.IF);
        slave_agent.start_slave();

        wait (aresetn == 1'b1);

        send_vector_128(128'h0004000200561526005c760f0000ffff);

        #1000ns;

        ready_gen = slave_agent.driver.create_ready("ready_gen");
        ready_gen.set_ready_policy(XIL_AXI4STREAM_READY_GEN_OSC);
        ready_gen.set_low_time(1);
        ready_gen.set_high_time(2);
        slave_agent.driver.send_tready(ready_gen);
        
        #1000ns;
        
        $display("\n=== Test Case 1 Complete ===\n");
        $display("=== All Tests Complete ===");
        $finish;
    end

endmodule