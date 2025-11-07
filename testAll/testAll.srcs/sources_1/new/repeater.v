`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07.11.2025 22:56:46
// Design Name: 
// Module Name: repeater
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


module repeater (
    input  wire        aclk,
    input  wire        aresetn,
    // AXI Stream input to lg_top
    input  wire [31:0] s_tdata,
    input  wire        s_tvalid,
    output wire        s_tready,
    input  wire        s_tlast,
    // AXI Stream output from final combiner
    output wire [15:0] m_tdata,
    output wire        m_tvalid,
    input  wire        m_tready,
    output wire        m_tlast
);

    // -----------------------------------------------
    // Wires for lg_top output
    // -----------------------------------------------
    wire [31:0] lg_m_tdata;
    wire        lg_m_tvalid;
    wire        lg_m_tready;
    wire        lg_m_tlast;

    // Instantiate lg_top
    lg_top lg_inst (
        .clk(aclk),
        .rst(~aresetn),
        .s_tdata(s_tdata),
        .s_tvalid(s_tvalid),
        .s_tready(s_tready),
        .s_tlast(s_tlast),
        .m_tdata(lg_m_tdata),
        .m_tvalid(lg_m_tvalid),
        .m_tready(lg_m_tready),
        .m_tlast(lg_m_tlast)
    );
/*
    // -----------------------------------------------
    // First-level broadcaster (1 ? 4)
    // -----------------------------------------------
    wire [3:0] b1_m_tvalid;
    wire [3:0] b1_m_tready;
    wire [127:0] b1_m_tdata;

    axis_broadcaster_0 b1 (
        .aclk(aclk),
        .aresetn(aresetn),
        .s_axis_tvalid(lg_m_tvalid),
        .s_axis_tready(lg_m_tready),
        .s_axis_tdata({lg_m_tdata, lg_m_tdata, lg_m_tdata, lg_m_tdata}), // replicate 32?128 bits
        .m_axis_tvalid(b1_m_tvalid),
        .m_axis_tready(b1_m_tready),
        .m_axis_tdata(b1_m_tdata)
    );

    // -----------------------------------------------
    // Second-level broadcasters (4 ? 4 each) -> 16 raster cores
    // -----------------------------------------------
    wire [31:0] raster_tdata [0:15];
    wire        raster_tvalid [0:15];
    wire        raster_tready [0:15];
    wire        raster_tlast [0:15];

    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : second_level
            wire [3:0] b2_m_tvalid;
            wire [3:0] b2_m_tready;
            wire [127:0] b2_m_tdata;

            // Second-level broadcaster
            axis_broadcaster_0 b2 (
                .aclk(aclk),
                .aresetn(aresetn),
                .s_axis_tvalid(b1_m_tvalid[i]),
                .s_axis_tready(b1_m_tready[i]),
                .s_axis_tdata(b1_m_tdata[32*i +: 32]), // split 128-bit to 4×32-bit
                .m_axis_tvalid(b2_m_tvalid),
                .m_axis_tready(b2_m_tready),
                .m_axis_tdata(b2_m_tdata)
            );

            // Instantiate 4 raster cores for this branch
            genvar j;
            for (j = 0; j < 4; j = j + 1) begin : raster_cores
                raster_core_wrapper #(
                    .C_S_AXIS_TDATA_WIDTH(32),
                    .C_M_AXIS_TDATA_WIDTH(32)
                ) raster_inst (
                    .clk(aclk),
                    .nreset(~aresetn),
                    .S_AXIS_ACLK(aclk),
                    .S_AXIS_ARESETN(aresetn),
                    .S_AXIS_TDATA(b2_m_tdata[127-32*j -:32]),
                    .S_AXIS_TVALID(b2_m_tvalid[j]),
                    .S_AXIS_TREADY(b2_m_tready[j]),
                    .S_AXIS_TLAST(1'b1),
                    .S_AXIS_TSTRB(4'b1111),
                    .M_AXIS_ACLK(aclk),
                    .M_AXIS_ARESETN(aresetn),
                    .M_AXIS_TDATA(raster_tdata[i*4+j]),
                    .M_AXIS_TVALID(raster_tvalid[i*4+j]),
                    .M_AXIS_TREADY(raster_tready[i*4+j]),
                    .M_AXIS_TLAST(raster_tlast[i*4+j]),
                    .M_AXIS_TSTRB()
                );
            end
        end
    endgenerate

    // -----------------------------------------------
    // First-level combiners (combine 4 raster cores each ? 4 combiners)
    // -----------------------------------------------
    wire [3:0] comb1_tvalid;
    wire [3:0] comb1_tready;
    wire [511:0] comb1_tdata; // 4×128-bit each

    generate
        for (i = 0; i < 4; i = i + 1) begin : comb1_level
            axis_combiner_0 comb (
                .aclk(aclk),
                .aresetn(aresetn),
                .s_axis_tvalid({raster_tvalid[i*4], raster_tvalid[i*4+1], raster_tvalid[i*4+2], raster_tvalid[i*4+3]}),
                .s_axis_tready({raster_tready[i*4], raster_tready[i*4+1], raster_tready[i*4+2], raster_tready[i*4+3]}),
                .s_axis_tdata({raster_tdata[i*4], raster_tdata[i*4+1], raster_tdata[i*4+2], raster_tdata[i*4+3]}),
                .m_axis_tvalid(comb1_tvalid[i]),
                .m_axis_tready(comb1_tready[i]),
                .m_axis_tdata(comb1_tdata[i*128 +: 128])
            );
        end
    endgenerate

    // -----------------------------------------------
    // Final combiner (combine 4 outputs ? 1 final output)
    // -----------------------------------------------
    axis_combiner_0 final_comb (
        .aclk(aclk),
        .aresetn(aresetn),
        .s_axis_tvalid(comb1_tvalid),
        .s_axis_tready(comb1_tready),
        .s_axis_tdata(comb1_tdata),
        .m_axis_tvalid(m_tvalid),
        .m_axis_tready(m_tready),
        .m_axis_tdata(m_tdata)
    );
    assign m_tlast = 1'b1; // Tie high for simplicity
*/

    // -----------------------------------------------
    // First-level broadcaster (1 to 8)
    // -----------------------------------------------
    wire [7:0] b1_m_tvalid;
    wire [7:0] b1_m_tready;
    wire [255:0] b1_m_tdata;

    axis_broadcaster_1 b1 (
        .aclk(aclk),
        .aresetn(aresetn),
        .s_axis_tvalid(lg_m_tvalid),
        .s_axis_tready(lg_m_tready),
        .s_axis_tdata({lg_m_tdata, lg_m_tdata, lg_m_tdata, lg_m_tdata, lg_m_tdata, lg_m_tdata, lg_m_tdata, lg_m_tdata}),
        .m_axis_tvalid(b1_m_tvalid),
        .m_axis_tready(b1_m_tready),
        .m_axis_tdata(b1_m_tdata)
    );

    // -----------------------------------------------
    // Second-level broadcasters (8 to 4 each) -> 32 raster cores but only 30 we use
    // In last broadcaster only 2 cores connected
    // -----------------------------------------------
    wire [31:0] raster_tdata [0:29];
    wire        raster_tvalid [0:29];
    wire        raster_tready [0:29];
    wire        raster_tlast [0:29];

    genvar i, j;
    generate
        for (i = 0; i < 8; i = i + 1) begin : second_level
            wire [3:0] b2_m_tvalid;
            wire [3:0] b2_m_tready;
            wire [127:0] b2_m_tdata;

            // Second-level broadcaster
            axis_broadcaster_0 b2 (
                .aclk(aclk),
                .aresetn(aresetn),
                .s_axis_tvalid(b1_m_tvalid[i]),
                .s_axis_tready(b1_m_tready[i]),
                .s_axis_tdata({b1_m_tdata[32*i +: 32], b1_m_tdata[32*i +: 32], b1_m_tdata[32*i +: 32], b1_m_tdata[32*i +: 32]}),
                .m_axis_tvalid(b2_m_tvalid),
                .m_axis_tready(b2_m_tready),
                .m_axis_tdata(b2_m_tdata)
            );

            // Instantiate 4 raster cores for this branch
            for (j = 0; j < 4; j = j + 1) begin : raster_cores
                // skip cores beyond 30
                if (i * 4 + j < 30) begin
                raster_core_wrapper #(
                    .C_S_AXIS_TDATA_WIDTH(32),
                    .C_M_AXIS_TDATA_WIDTH(32)
                ) raster_inst (
                    .clk(aclk),
                    .nreset(~aresetn),
                    .S_AXIS_ACLK(aclk),
                    .S_AXIS_ARESETN(aresetn),
                    .S_AXIS_TDATA(b2_m_tdata[127-32*j -:32]),
                    .S_AXIS_TVALID(b2_m_tvalid[j]),
                    .S_AXIS_TREADY(b2_m_tready[j]),
                    .S_AXIS_TLAST(1'b1),
                    .S_AXIS_TSTRB(4'b1111),
                    .M_AXIS_ACLK(aclk),
                    .M_AXIS_ARESETN(aresetn),
                    .M_AXIS_TDATA(raster_tdata[i*4+j]),
                    .M_AXIS_TVALID(raster_tvalid[i*4+j]),
                    .M_AXIS_TREADY(raster_tready[i*4+j]),
                    .M_AXIS_TLAST(raster_tlast[i*4+j]),
                    .M_AXIS_TSTRB()
                );
                end
            end
        end
    endgenerate

/*
    // -----------------------------------------------
    // First-level combiners (combine 4 raster cores each ? 8 combiners)
    // -----------------------------------------------
    wire [7:0] comb1_tvalid;
    wire [7:0] comb1_tready;
    wire [1023:0] comb1_tdata; // 8×128-bit each

    generate
        for (i = 0; i < 8; i = i + 1) begin : comb1_level
            wire [127:0] sdata[3:0];
            wire [3:0] svalid;
            wire [3:0] sready;
            
            for (j = 0; j < 4; j = j + 1) begin
                localparam idx = i * 4 + j;
                // skip cores beyond 30
                if (idx < 30) begin
                    assign sdata[j] = raster_tdata[idx];
                    assign svalid[j] = raster_tvalid[idx];
                    assign raster_tready[idx] = sready[j];
                end else begin
                    assign sdata[j] = 32'b0;
                    assign svalid[j] = 1'b0;
                    assign sready[j] = 1'b0;
                end
            end
            
            axis_combiner_0 comb (
                .aclk(aclk),
                .aresetn(aresetn),
                .s_axis_tvalid(svalid),
                .s_axis_tready(sready),
                .s_axis_tdata({sdata[0], sdata[1], sdata[2], sdata[3]}),
                .m_axis_tvalid(comb1_tvalid[i]),
                .m_axis_tready(comb1_tready[i]),
                .m_axis_tdata(comb1_tdata[i*128 +: 128])
            );
        end
    endgenerate

    // -----------------------------------------------
    // Final combiner (combine 8 outputs to 1 final output)
    // -----------------------------------------------
    axis_combiner_1 final_comb (
        .aclk(aclk),
        .aresetn(aresetn),
        .s_axis_tvalid(comb1_tvalid),
        .s_axis_tready(comb1_tready),
        .s_axis_tdata(comb1_tdata),
        .m_axis_tvalid(m_tvalid),
        .m_axis_tready(m_tready),
        .m_axis_tdata(m_tdata)
    );
    assign m_tlast = 1'b1; // Tie high for simplicity
    */
    
    // -----------------------------------------------
    // First-level switches (combine 4 raster cores ? 1 stream)
    // -----------------------------------------------
    wire [7:0]  switch1_tvalid;
    wire [7:0]  switch1_tready;
    wire [15:0] switch1_tdata [0:7];
    wire [7:0]  switch1_tlast;
    wire [3:0]  s_decode_err_1 [0:7];
    wire [3:0]  s_req_suppress_1 [0:7];

    generate
        for (i = 0; i < 8; i = i + 1) begin : switch_1st
            axis_switch_1 sw1 (
                .aclk(aclk),
                .aresetn(aresetn),
                .s_axis_tvalid({raster_tvalid[i*4+3], raster_tvalid[i*4+2], raster_tvalid[i*4+1], raster_tvalid[i*4]}),
                .s_axis_tready({raster_tready[i*4+3], raster_tready[i*4+2], raster_tready[i*4+1], raster_tready[i*4]}),
                .s_axis_tdata({raster_tdata[i*4+3][15:0],
                               raster_tdata[i*4+2][15:0],
                               raster_tdata[i*4+1][15:0],
                               raster_tdata[i*4+0][15:0]}),
                .s_axis_tlast({raster_tlast[i*4+3],
                               raster_tlast[i*4+2],
                               raster_tlast[i*4+1],
                               raster_tlast[i*4+0]}),
                .m_axis_tvalid(switch1_tvalid[i]),
                .m_axis_tready(switch1_tready[i]),
                .m_axis_tdata(switch1_tdata[i]),
                .m_axis_tlast(switch1_tlast[i]),
                .s_req_suppress(s_req_suppress_1[i]),
                .s_decode_err(s_decode_err_1[i])
            );
        end
    endgenerate

    // -----------------------------------------------
    // Final switch (combine 8 first-level outputs ? 1 stream)
    // -----------------------------------------------
    wire [7:0] s_decode_err_0;
    wire [7:0] s_req_suppress_0;

    axis_switch_0 final_switch (
        .aclk(aclk),
        .aresetn(aresetn),
        .s_axis_tvalid(switch1_tvalid),
        .s_axis_tready(switch1_tready),
        .s_axis_tdata({switch1_tdata[7],
                       switch1_tdata[6],
                       switch1_tdata[5],
                       switch1_tdata[4],
                       switch1_tdata[3],
                       switch1_tdata[2],
                       switch1_tdata[1],
                       switch1_tdata[0]}),
        .s_axis_tlast(switch1_tlast),
        .m_axis_tvalid(m_tvalid),
        .m_axis_tready(m_tready),
        .m_axis_tdata(m_tdata),
        .m_axis_tlast(m_tlast),
        .s_req_suppress(s_req_suppress_0),
        .s_decode_err(s_decode_err_0)
    );
endmodule
