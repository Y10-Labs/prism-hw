`timescale 1ns / 100ps

// tID_z1 + ctrl_yyy + ctrl_xxx + z2z3 = 128
// lambdas(32-bit)x9 + tID

module AXI_LITE_SLAVE # (
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_DATA_WIDTH = 32,

    parameter FREQ_HZ = 100000000
)(
    input  wire                       aclk,
    input  wire                       aresetn,

    // AXI Slave Bus Interface S0_AXI
    // Write Address channel
    input  wire [AXI_ADDR_WIDTH-1:0]  s0_axi_awaddr,
    input  wire [2:0]                 s0_axi_awprot,
    input  wire                       s0_axi_awvalid,
    output wire                       s0_axi_awready,

    // Write Data channel
    input  wire [AXI_DATA_WIDTH-1:0]     s0_axi_wdata,
    input  wire [(AXI_DATA_WIDTH/8)-1:0] s0_axi_wstrb,
    input  wire                          s0_axi_wvalid,
    output wire                          s0_axi_wready,

    // Write response channel
    output wire [1:0]                 s0_axi_bresp,
    output wire                       s0_axi_bvalid,
    input  wire                       s0_axi_bready,

    // Read Address Channel
    input  wire [AXI_ADDR_WIDTH-1:0]  s0_axi_araddr,
    input  wire [2:0]                 s0_axi_arprot,
    input  wire                       s0_axi_arvalid,
    output wire                       s0_axi_arready,

    // Read Data channel
    output wire [AXI_DATA_WIDTH-1:0]  s0_axi_rdata,
    output wire [1:0]                 s0_axi_rresp,
    output wire                       s0_axi_rvalid,
    input  wire                       s0_axi_rready,

    output reg rch_wtf,
    output reg wch_wtf
);
    // rename signals for clarity

    // AXI Slave Bus Interface S0_AXI
    // Write Address channel
    wire [AXI_ADDR_WIDTH-1:0]  i_awaddr;
    wire [2:0]                 i_awprot;
    wire                       i_awvalid;
    reg                        o_awready;
    // Write Data channel
    wire [AXI_DATA_WIDTH-1:0]     i_wdata;
    wire [(AXI_DATA_WIDTH/8)-1:0] i_wstrb;
    wire                          i_wvalid;
    reg                           o_wready;
    // Write response channel
    reg [1:0]                  o_bresp;
    reg                        o_bvalid;
    wire                       i_bready;
    // Read Address Channel
    wire [AXI_ADDR_WIDTH-1:0]  i_araddr;
    wire [2:0]                 i_arprot;
    wire                       i_arvalid;
    reg                        o_arready;
    // Read Data channel
    wire[AXI_DATA_WIDTH-1:0]   o_rdata;
    reg [1:0]                  o_rresp;
    reg                        o_rvalid;
    wire                       i_rready;

    // actual start:
    // read channel
    // State machine
    localparam RCH_RST  = 2'b00;
    localparam RCH_IDLE = 2'b01;
    localparam RCH_DATA = 2'b10;

    reg[1:0] rch_state;

    // data
    reg[AXI_ADDR_WIDTH-1:0] rch_addr;
    reg[AXI_DATA_WIDTH-1:0] rch_data;

    // map the read_data register to output register
    reg[AXI_DATA_WIDTH-1:0] mod_data;

    reg[4*AXI_DATA_WIDTH-1:0] slv_reg;

    //assign o_rdata = rch_addr[2] ? 32'hDEADBEEF : 32'hBEEFDEAD;
    assign o_rdata = slv_reg[AXI_DATA_WIDTH * i_araddr[3:2] +: AXI_DATA_WIDTH];

    // handshakes
    wire ar_handshake = o_arready && i_arvalid;
    wire r_handshake = i_rready && o_rvalid;

    // Read channel handler
    always @(posedge aclk) begin
        if (!aresetn) begin
            // clear valid flags
            o_rvalid <= 0;
            // set data to zero
            rch_addr <= 0;
            rch_data <= 0;
            // set state to RST
            rch_state <= RCH_RST;
            o_arready <= 0;
            // nothing wrong
            rch_wtf <= 0;
            o_rresp <= 0;
        end
        // there is no reset signal
        // goto IDLE state
        else if (rch_state == RCH_RST) begin
            rch_state <= RCH_IDLE;
            o_arready <= 1;
        end
        else begin
            // a address channel handshake!
            if (ar_handshake) begin
                // handle based on state
                if (rch_state == RCH_IDLE) begin
                    // in IDLE, latch the address
                    // set the read channel valid bit (data is combinational on rch_addr)
                    // then goto data state
                    o_arready <= 0;
                    o_rvalid <= 1;
                    rch_addr <= i_araddr;
                    rch_state <= RCH_DATA;
                    // response is OKAY
                    o_rresp <= 0;
                end
                else if (rch_state == RCH_DATA) begin
                    // weird...
                    rch_wtf <= 1;
                    // parse as normal
                    o_arready <= 0;
                    o_rvalid <= 1;
                    rch_addr <= i_araddr;
                    rch_state <= RCH_DATA;
                    // response is OKAY
                    o_rresp <= 0;
                end
            end

            // a read channel handshake!
            if (r_handshake) begin
                // handle based on state
                if (rch_state == RCH_IDLE) begin
                    // weird...
                    rch_wtf <= 1;
                    // but complete the handshake
                    o_rvalid <= 0;
                    // back to IDLE!
                    rch_state <= RCH_IDLE;
                    // ar channel is ready
                    o_arready <= 1;
                end
                else if (rch_state == RCH_DATA) begin
                    // just complete the handshake
                    o_rvalid <= 0;
                    // back to IDLE!
                    rch_state <= RCH_IDLE;
                    // ar channel is ready
                    o_arready <= 1;
                end
            end
        end
    end

    // write channel
    // State machine
    localparam WCH_RST  = 2'b00;
    localparam WCH_IDLE = 2'b01;
    localparam WCH_DATA = 2'b10;
    localparam WCH_RESP = 2'b11;

    reg[1:0] wch_state;

    // data
    reg[AXI_ADDR_WIDTH-1:0] wch_addr;
    reg[AXI_DATA_WIDTH-1:0] wch_data;

    // map the read_data register to output register
    //assign o_rdata = rch_addr[2] ? 32'hDEADBEEF : 32'hBEEFDEAD;

    // handshakes
    wire aw_handshake = o_awready && i_awvalid;
    wire w_handshake = o_wready && i_wvalid;
    wire b_handshake = i_bready && o_bvalid;

    // Write channel handler
    always @(posedge aclk) begin
        if (!aresetn) begin
            // clear valid flags
            o_bvalid <= 0;
            // set data to zero
            wch_addr <= 0;
            wch_data <= 0;
            // set state to idle
            wch_state <= WCH_RST;
            o_awready <= 0;
            o_wready <= 0;
            // nothing wrong
            o_bresp <= 0;
            wch_wtf <= 0;
            // no data
            mod_data <= 0;
            slv_reg <= 0;
        end
        // there is no reset signal
        // goto IDLE state
        else if (wch_state == WCH_RST) begin
            wch_state <= WCH_IDLE;
            o_awready <= 1;
            o_wready <= 1;
        end
        else if (wch_state == WCH_IDLE) begin
            if (aw_handshake) begin
                // latch the address
                wch_addr <= i_awaddr;

                // there are 2 options:
                // either the data is available
                // so only the aw channel handshake is good enough...
                if (i_wvalid) begin
                    // stay in the same state
                    wch_state <= WCH_IDLE;
                    // set the data
                    // use i_awaddr, as wch_addr is not set yet
                    slv_reg[AXI_DATA_WIDTH * i_awaddr[3:2] +: AXI_DATA_WIDTH] <= i_wdata;

                    //mod_data <= i_wdata;
                    // set adderess channel and write channel ready...
                    o_wready <= 1;
                    o_awready <= 1;
                    // send the valid response
                    o_bresp <= 0;
                    o_bvalid <= 1;
                end
                // otherwise a seperate write channel handshake
                // should be done
                else begin
                    // keep aw channel busy
                    o_awready <= 0;
                    // set this ready...
                    o_wready <= 1;
                    // goto data state
                    wch_state <= WCH_DATA;

                    // current transaction is not finished,
                    // so invalidate the response channel
                    if (b_handshake) o_bvalid <= 0;
                end
            end
            else begin
                // handle response channel handshake
                // because there is no ongoing transaction
                // reponse channel must not be valid
                if (b_handshake) o_bvalid <= 0;
            end
        end
        else if (wch_state == WCH_DATA) begin
            if (w_handshake) begin
                // goto IDLE state
                wch_state <= WCH_IDLE;
                // set the data
                slv_reg[AXI_DATA_WIDTH * wch_addr[3:2] +: AXI_DATA_WIDTH] <= i_wdata;
                //mod_data <= i_wdata;
                // set adderess channel and write channel ready...
                o_wready <= 1;
                o_awready <= 1;
                // send the valid response
                o_bresp <= 0;
                o_bvalid <= 1;
            end
            else begin
                // current transaction is not finished,
                // so invalidate the response channel
                if (b_handshake) o_bvalid <= 0;
            end
        end
        else begin
            // bad state
            // reset the slave
            wch_state <= WCH_IDLE;
            o_awready <= 1;
            // set this ready...
            o_wready <= 1;
        end
    end

    // all renamed assignments
    assign i_awaddr         = s0_axi_awaddr;
    assign i_awprot         = s0_axi_awprot;
    assign i_awvalid        = s0_axi_awvalid;
    assign s0_axi_awready   = o_awready;

    assign i_wdata          = s0_axi_wdata;
    assign i_wstrb          = s0_axi_wstrb;
    assign i_wvalid         = s0_axi_wvalid;
    assign s0_axi_wready    = o_wready;
    
    assign s0_axi_bresp     = o_bresp;
    assign s0_axi_bvalid    = o_bvalid;
    assign i_bready         = s0_axi_bready;
    
    assign i_araddr         = s0_axi_araddr;
    assign i_arprot         = s0_axi_arprot;
    assign i_arvalid        = s0_axi_arvalid;
    assign s0_axi_arready   = o_arready;
    
    assign s0_axi_rdata     = o_rdata;
    assign s0_axi_rresp     = o_rresp;
    assign s0_axi_rvalid    = o_rvalid;
    assign i_rready         = s0_axi_rready;

endmodule

