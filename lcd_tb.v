`timescale 1ns/1ps

module tb_lcd_controller;

    // Clock and reset
    reg clk;
    reg aresetn;
    reg i_start;

    // Outputs from DUT
    wire o_data_en;
    wire [7:0] o_red;
    wire [7:0] o_green;
    wire [7:0] o_blue;

    // Clock generation: 10ns period => 100 MHz
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0);
    end

    // Instantiate the DUT
    lcd_controller #(
        .HORIZONTAL_BACK_PORCH(10), // px
        .HORIZONTAL_FRONT_PORCH(20), // px
        
        .VERTICAL_BACK_PORCH(10), // lines
        .VERTICAL_FRONT_PORCH(20), // lines

        .HORIZONTAL_DATA_WIDTH(20), // px
        .VERTICAL_DATA_WIDTH(20) // px
    ) dut (
        .clk(clk),
        .aresetn(aresetn),
        .i_start(i_start),
        .o_data_en(o_data_en),
        .o_red(o_red),
        .o_green(o_green),
        .o_blue(o_blue)
    );

    // Test procedure
    initial begin
        $display("Starting LCD controller testbench...");

        // Initial conditions
        aresetn = 0;
        i_start = 0;

        // Wait a few cycles and deassert reset
        #20;
        aresetn = 1;

        // Wait a few cycles before starting
        #20;
        i_start = 1;

        #10;
        i_start = 0;

        // Run simulation long enough to complete a frame
        #100000;

        $display("Finished simulation.");
        $finish;
    end

    // Monitor important outputs
    always @(posedge clk) begin
        if (o_data_en)
            $display("Time: %0t | DATA ENABLED | Blue: %02X", $time, o_blue);
    end

endmodule
