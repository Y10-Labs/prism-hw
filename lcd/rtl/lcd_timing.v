// ---------------------------------------------------------------------------
// lcd_timing - RGB display timing generator
//
// Target panel: ChengHao CH500WV05A-T (Adafruit 1596), 5.0" 800x480 24-bit
// parallel RGB, no controller / no RAM.  Datasheet facts this encodes:
//   * DCLK latches data on its RISING edge
//   * HSYNC and VSYNC are NEGATIVE polarity
//   * Fclk typ 40 MHz, max 50 MHz, Tclk min 20 ns
//   * In DE-only mode the panel derives its internal VSD from a DE-low gap
//     of >= 2048 DCLKs, and its internal HSD 2 DCLKs after each DE fall.
//
// Region order within a line/frame is ACTIVE, FRONT PORCH, SYNC, BACK PORCH.
//
// Every output is driven from a single register stage so DE, the syncs and
// the pixel data are aligned at the pins with no relative skew.
//
// o_x / o_y / o_active are the *pre-register* coordinates: a pixel source
// must register its data off them with exactly one cycle of latency for
// i_pixel to land in the same stage as o_de.
// ---------------------------------------------------------------------------

`default_nettype none

module lcd_timing #(
    // Defaults give 1056 x 525 @ 33.264 MHz = 60.0 Hz, the standard mode for
    // this panel family.  Vertical blank is 45 lines = 47,520 DCLKs, well past
    // the 2048 the panel needs to see end-of-frame; the inter-line DE-low gap
    // is 256 DCLKs, safely under it.
    parameter integer H_ACTIVE = 800,
    parameter integer H_FRONT  = 40,
    parameter integer H_SYNC   = 48,
    parameter integer H_BACK   = 168,

    parameter integer V_ACTIVE = 480,
    parameter integer V_FRONT  = 13,
    parameter integer V_SYNC   = 3,
    parameter integer V_BACK   = 29,

    // 1 = emit active-low syncs (what this panel wants).
    parameter         SYNC_ACTIVE_LOW = 1'b1
)(
    input  wire clk,
    input  wire rst_n,
    input  wire i_enable,      // hold high to run continuously

    // pre-register coordinates, for an external pixel source
    output wire [11:0] o_x,
    output wire [11:0] o_y,
    output wire        o_active,

    // registered outputs, mutually aligned
    output reg  o_hsync,
    output reg  o_vsync,
    output reg  o_de,
    output reg  o_frame_start  // one clk pulse at the first active pixel
);

    localparam integer H_TOTAL = H_ACTIVE + H_FRONT + H_SYNC + H_BACK;
    localparam integer V_TOTAL = V_ACTIVE + V_FRONT + V_SYNC + V_BACK;

    localparam integer H_SYNC_BEG = H_ACTIVE + H_FRONT;
    localparam integer H_SYNC_END = H_SYNC_BEG + H_SYNC;   // exclusive
    localparam integer V_SYNC_BEG = V_ACTIVE + V_FRONT;
    localparam integer V_SYNC_END = V_SYNC_BEG + V_SYNC;   // exclusive

    localparam integer HW = (H_TOTAL <= 2) ? 1 : $clog2(H_TOTAL);
    localparam integer VW = (V_TOTAL <= 2) ? 1 : $clog2(V_TOTAL);

    reg [HW-1:0] h_cnt;
    reg [VW-1:0] v_cnt;

    wire h_last = (h_cnt == H_TOTAL - 1);
    wire v_last = (v_cnt == V_TOTAL - 1);

    always @(posedge clk) begin
        if (!rst_n) begin
            h_cnt <= {HW{1'b0}};
            v_cnt <= {VW{1'b0}};
        end
        else if (!i_enable) begin
            // park at the top-left so every enable starts a whole frame
            h_cnt <= {HW{1'b0}};
            v_cnt <= {VW{1'b0}};
        end
        else begin
            if (h_last) begin
                h_cnt <= {HW{1'b0}};
                v_cnt <= v_last ? {VW{1'b0}} : (v_cnt + 1'b1);
            end
            else begin
                h_cnt <= h_cnt + 1'b1;
            end
        end
    end

    // combinational region decode
    wire h_act = (h_cnt < H_ACTIVE);
    wire v_act = (v_cnt < V_ACTIVE);
    wire de_c  = i_enable && h_act && v_act;

    wire h_syn = (h_cnt >= H_SYNC_BEG) && (h_cnt < H_SYNC_END);
    wire v_syn = (v_cnt >= V_SYNC_BEG) && (v_cnt < V_SYNC_END);

    wire hsync_c = SYNC_ACTIVE_LOW ? ~h_syn : h_syn;
    wire vsync_c = SYNC_ACTIVE_LOW ? ~v_syn : v_syn;

    wire frame_start_c = i_enable && (h_cnt == 0) && (v_cnt == 0);

    assign o_x      = h_act ? {{(12-HW){1'b0}}, h_cnt} : 12'd0;
    assign o_y      = v_act ? {{(12-VW){1'b0}}, v_cnt} : 12'd0;
    assign o_active = de_c;

    always @(posedge clk) begin
        if (!rst_n) begin
            o_hsync       <= SYNC_ACTIVE_LOW ? 1'b1 : 1'b0;
            o_vsync       <= SYNC_ACTIVE_LOW ? 1'b1 : 1'b0;
            o_de          <= 1'b0;
            o_frame_start <= 1'b0;
        end
        else begin
            o_hsync       <= hsync_c;
            o_vsync       <= vsync_c;
            o_de          <= de_c;
            o_frame_start <= frame_start_c;
        end
    end

endmodule

`default_nettype wire
