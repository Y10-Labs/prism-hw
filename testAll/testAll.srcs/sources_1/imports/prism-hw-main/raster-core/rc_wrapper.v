module raster_core_wrapper #(
    parameter integer core_id = 29,
    parameter integer LWIDTH = 32,
    parameter integer C_S_AXIS_TDATA_WIDTH = 32,
    parameter integer C_M_AXIS_TDATA_WIDTH = 16,
    parameter integer RAM_WIDTH = 32,
    parameter integer RAM_DEPTH = 512,
    parameter integer FREQ_HZ = 100_000_000
) (
    input wire clk,
    input wire nreset,

    // AXI4Stream sink: Clock
    input wire  S_AXIS_ACLK,
    // AXI4Stream sink: Reset
    input wire  S_AXIS_ARESETN,
    // Ready to accept data in
    output wire  S_AXIS_TREADY,
    // Data in
    input wire [C_S_AXIS_TDATA_WIDTH-1 : 0] S_AXIS_TDATA,
    // Byte qualifier (ignore maybe?)
    input wire [(C_S_AXIS_TDATA_WIDTH/8)-1 : 0] S_AXIS_TSTRB,
    // Indicates boundary of last packet
    input wire  S_AXIS_TLAST,
    // Data is valid
    input wire  S_AXIS_TVALID,

    // AXI4Stream master: Clock
    input wire  M_AXIS_ACLK,
    // AXI4Stream master: Reset
    input wire  M_AXIS_ARESETN,
    // Ready to accept data in
    input wire  M_AXIS_TREADY,
    // Data out
    output wire [C_M_AXIS_TDATA_WIDTH-1 : 0] M_AXIS_TDATA,
    // Byte qualifier (ignore maybe?)
    output wire [(C_M_AXIS_TDATA_WIDTH/8)-1 : 0] M_AXIS_TSTRB,
    // Indicates boundary of last packet
    output wire  M_AXIS_TLAST,
    // Data is valid
    output wire  M_AXIS_TVALID
);

    // Internal signals for raster core
    wire is_handshake;
    wire [LWIDTH-1:0] data;
    wire ready;
    wire output_handshake;
    wire output_valid;
    wire [15:0] output_data;
    
    // BRAM interface signals
    wire rch_en;
    wire [8:0] rch_addr;
    wire [31:0] rch_data;
    wire wch_en;
    wire [8:0] wch_addr;
    wire [31:0] wch_data;
    
    // AXI Stream Slave adapter signals
    assign S_AXIS_TREADY = ready;
    assign is_handshake = S_AXIS_TVALID && S_AXIS_TREADY;
    assign data = S_AXIS_TDATA;
    
    // AXI Stream Master adapter signals
    assign M_AXIS_TVALID = output_valid;
    assign M_AXIS_TDATA = output_data;
    assign M_AXIS_TSTRB = {(C_M_AXIS_TDATA_WIDTH/8){1'b1}};
    assign output_handshake = M_AXIS_TVALID && M_AXIS_TREADY;
    
    // Raster Core instantiation
    raster_core_impl #(
        .core_id(core_id),
        .LWIDTH(LWIDTH),
        .BRAM_LATENCY(2)
    ) raster_core_inst (
        .clk(clk),
        .nreset(nreset),
        .is_handshake(is_handshake),
        .data(data),
        .ready(ready),
        .output_handshake(output_handshake),
        .output_valid(output_valid),
        .output_data(output_data),
        .output_last(M_AXIS_TLAST),
        .rch_en(rch_en),
        .rch_addr(rch_addr),
        .rch_data(rch_data),
        .wch_en(wch_en),
        .wch_addr(wch_addr),
        .wch_data(wch_data)
    );
    
    // RAM_SDP instantiation (Z-buffer)
    RAM_SDP #(
        .RAM_WIDTH(RAM_WIDTH),
        .RAM_DEPTH(RAM_DEPTH),
        .RAM_TYPE("HIGH_PERFORMANCE")
    ) zbuffer_ram (
        .addra(wch_addr),
        .addrb(rch_addr),
        .dina(wch_data),
        .clk(clk),
        .wea(wch_en),
        .enb(rch_en),
        .rst(~nreset),
        .regceb(1'b1),
        .doutb(rch_data)
    );

endmodule
