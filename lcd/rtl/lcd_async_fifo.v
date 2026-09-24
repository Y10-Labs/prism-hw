// ---------------------------------------------------------------------------
// lcd_async_fifo - dual-clock, first-word-fall-through FIFO
//
// Gray-coded pointers, two-flop synchronisers, and an asynchronously read
// memory (LUTRAM on 7-series), so the head word is visible on o_rd_data as
// soon as o_empty is low: pop it with i_rd_en in the same cycle it is used.
//
// Depth is 2**AW words.  o_full / o_empty are conservative (the other side's
// pointer arrives two flops late), never optimistic.
// ---------------------------------------------------------------------------

`default_nettype none

module lcd_async_fifo #(
    parameter integer DW = 25,
    parameter integer AW = 9
)(
    input  wire          wr_clk,
    input  wire          wr_rst_n,
    input  wire          i_wr_en,
    input  wire [DW-1:0] i_wr_data,
    output wire          o_full,

    input  wire          rd_clk,
    input  wire          rd_rst_n,
    input  wire          i_rd_en,
    output wire [DW-1:0] o_rd_data,
    output wire          o_empty
);

    (* ram_style = "distributed" *) reg [DW-1:0] mem [0:(1<<AW)-1];

    reg [AW:0] wr_bin, wr_gray, rd_bin, rd_gray;
    (* ASYNC_REG = "TRUE" *) reg [AW:0] rd_gray_w1, rd_gray_w2;   // rd ptr in wr domain
    (* ASYNC_REG = "TRUE" *) reg [AW:0] wr_gray_r1, wr_gray_r2;   // wr ptr in rd domain

    wire [AW:0] wr_bin_nx  = wr_bin + 1'b1;
    wire [AW:0] wr_gray_nx = wr_bin_nx ^ (wr_bin_nx >> 1);
    wire [AW:0] rd_bin_nx  = rd_bin + 1'b1;
    wire [AW:0] rd_gray_nx = rd_bin_nx ^ (rd_bin_nx >> 1);

    // full: write pointer one lap ahead of the synchronised read pointer
    assign o_full  = (wr_gray == {~rd_gray_w2[AW:AW-1], rd_gray_w2[AW-2:0]});
    assign o_empty = (rd_gray == wr_gray_r2);

    always @(posedge wr_clk) begin
        if (!wr_rst_n) begin
            wr_bin  <= 0;
            wr_gray <= 0;
        end
        else if (i_wr_en && !o_full) begin
            mem[wr_bin[AW-1:0]] <= i_wr_data;
            wr_bin  <= wr_bin_nx;
            wr_gray <= wr_gray_nx;
        end
    end

    always @(posedge wr_clk) begin
        if (!wr_rst_n) begin
            rd_gray_w1 <= 0;
            rd_gray_w2 <= 0;
        end
        else begin
            rd_gray_w1 <= rd_gray;
            rd_gray_w2 <= rd_gray_w1;
        end
    end

    always @(posedge rd_clk) begin
        if (!rd_rst_n) begin
            rd_bin  <= 0;
            rd_gray <= 0;
        end
        else if (i_rd_en && !o_empty) begin
            rd_bin  <= rd_bin_nx;
            rd_gray <= rd_gray_nx;
        end
    end

    always @(posedge rd_clk) begin
        if (!rd_rst_n) begin
            wr_gray_r1 <= 0;
            wr_gray_r2 <= 0;
        end
        else begin
            wr_gray_r1 <= wr_gray;
            wr_gray_r2 <= wr_gray_r1;
        end
    end

    assign o_rd_data = mem[rd_bin[AW-1:0]];

endmodule

`default_nettype wire
