`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/11/2016 11:31:12 PM
// Design Name: 
// Module Name: RAM_SDP
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module RAM_SDP #(
        parameter RAM_WIDTH = 18,                   // Specify RAM data width
        parameter RAM_DEPTH = 1024,                 // Specify RAM depth (number of entries)
        parameter RAM_TYPE = "HIGH_PERFORMANCE"     // Uses Output Register(s) if HIGH_PERFORMANCE; No output Register if LOW_LATENCY 
    ) (  
        input [clogb2(RAM_DEPTH-1)-1:0] addra,     // Write address bus, width determined from RAM_DEPTH
        input [clogb2(RAM_DEPTH-1)-1:0] addrb,     // Read address bus, width determined from RAM_DEPTH
        input [RAM_WIDTH-1:0] dina,                // RAM input data
        input clk,                                 // Clock
        input wea,                                 // Write enable
        input enb,                                 // Read Enable, for additional power savings, disable when not in use
        input rst,                              // Output reset (does not affect memory contents)
        input regceb,                              // Output register enable
        output [RAM_WIDTH-1:0] doutb               // RAM output data
    );

    //  Xilinx Simple Dual Port Single Clock RAM
    //  This code implements a parameterizable SDP single clock memory.
        
    reg [RAM_WIDTH-1:0] ram [RAM_DEPTH-1:0];
    reg [RAM_WIDTH-1:0] ram_data = {RAM_WIDTH{1'b0}};
    
    integer ram_index;      
    initial
        for (ram_index = 0; ram_index < RAM_DEPTH; ram_index = ram_index + 1)
            ram[ram_index] = {RAM_WIDTH{1'b0}};
      
    always @(posedge clk) begin
        if (wea)
            ram[addra] <= dina; 
        if (enb)
            ram_data <= ram[addrb];
    end        
    
    //  The following code generates HIGH_PERFORMANCE (use output register) 
    generate
        if (RAM_TYPE == "HIGH_PERFORMANCE") begin
            reg [RAM_WIDTH-1:0] doutb_reg = {RAM_WIDTH{1'b0}};
    
            always @(posedge clk) begin
                if (rst)
                    doutb_reg <= {RAM_WIDTH{1'b0}};
                else if (regceb)
                    doutb_reg <= ram_data;
            end
            
            assign doutb = doutb_reg;
        end
        
        else
            assign doutb = ram_data;
            
    endgenerate
    
    //  The following function calculates the address width based on specified RAM depth
    function integer clogb2;
        input integer depth;
            for (clogb2=0; depth>0; clogb2=clogb2+1)
                depth = depth >> 1;
    endfunction
                            
endmodule
