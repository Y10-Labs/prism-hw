// ---------------------------------------------------------------------------
// lcd_regs_axil - AXI4-Lite control/status registers for lcd_controller
//
// Two clock domains:
//   s_axi_aclk  FCLK0, 50 MHz, fixed.  The bus side lives here, so the
//               registers stay readable even if the pixel clock is stopped or
//               set to something silly - software can always get back in.
//   pix_clk     FCLK1, the pixel clock, swept at runtime from Linux.
//
// Every write to a config register is followed by an automatic APPLY: a
// toggle crosses into the pixel domain through a 3-flop synchroniser and, on
// its edge, the pixel domain samples the whole (by then static) config bus.
// The toggle is echoed back, so STATUS.applied says the pixel domain has seen
// the last write.  Back-to-back writes can land mid-capture; the capture after
// the final write is always clean, so the end state is exact.
//
// Register map (byte offsets, all 32-bit):
//   0x00 ID          RO  0x4C434431 "LCD1"
//   0x04 BUILD       RO  BUILD_ID parameter (build timestamp)
//   0x08 CTRL        RW  [0] enable        [1] clk_invert
//                        [2] hs_active_low [3] vs_active_low
//                        [4] de_active_low [5] de_only (HSYNC/VSYNC held low)
//                        [8] pix_soft_rst  [9] pin_override
//                        [10] src_clear (clears the sticky stream flags)
//   0x10 H_ACT_FP    RW  [11:0] h_active   [27:16] h_front
//   0x14 H_SYNC_BP   RW  [11:0] h_sync     [27:16] h_back
//   0x18 V_ACT_FP    RW  [11:0] v_active   [27:16] v_front
//   0x1C V_SYNC_BP   RW  [11:0] v_sync     [27:16] v_back
//   0x20 PATTERN     RW  [3:0] select      [15:8] argument
//   0x24 SOLID       RW  [23:0] {R,G,B}
//   0x28 SEQ_VDD     RW  [23:0] clocks from enable to timing start
//   0x2C SEQ_FRAMES  RW  [7:0] blank  [15:8] disp  [23:16] off
//   0x30 PIN_VALUE   RW  [29:0] {bl, disp, de, vs, hs, dclk, R, G, B}
//   0x40 STATUS      RO  [2:0] seq state  [3] ready  [4] applied
//                        [5] pixel clock alive  [6] disp  [7] bl_en
//                        [9:8] stream source state (0 SEEK, 1 READY, 2 RUN)
//                        [10] stream underflow seen  [11] stream misalign seen
//   0x44 FRAME_CNT   RO  frames started since reset
//   0x48 PCLK_HZ     RO  measured pixel clock, 10 Hz resolution, 100 ms gate
//   0x4C SCRATCH     RW  bus sanity check, no effect
// ---------------------------------------------------------------------------

`default_nettype none
`include "lcd_defaults.vh"

module lcd_regs_axil #(
    parameter [31:0] BUILD_ID  = 32'h0,
    parameter integer AXI_HZ   = 50000000
)(
    // ---- AXI4-Lite slave, s_axi_aclk domain ----
    input  wire        s_axi_aclk,
    input  wire        s_axi_aresetn,
    input  wire [11:0] s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output reg         s_axi_awready,
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output reg         s_axi_wready,
    output wire [1:0]  s_axi_bresp,
    output reg         s_axi_bvalid,
    input  wire        s_axi_bready,
    input  wire [11:0] s_axi_araddr,
    input  wire        s_axi_arvalid,
    output reg         s_axi_arready,
    output reg  [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output reg         s_axi_rvalid,
    input  wire        s_axi_rready,

    // ---- pixel domain ----
    input  wire        pix_clk,
    input  wire        pix_rst_n,       // external reset, synchronous to pix_clk
    output wire        o_pix_rst_n,     // pix_rst_n AND NOT soft reset

    output reg         o_enable,
    output reg         o_clk_invert,
    output reg         o_hs_active_low,
    output reg         o_vs_active_low,
    output reg         o_de_active_low,
    output reg         o_de_only,
    output reg  [11:0] o_h_active, o_h_front, o_h_sync, o_h_back,
    output reg  [11:0] o_v_active, o_v_front, o_v_sync, o_v_back,
    output reg  [3:0]  o_pattern,
    output reg  [7:0]  o_pattern_arg,
    output reg  [23:0] o_solid,
    output reg  [23:0] o_vdd_wait,
    output reg  [7:0]  o_blank_frames,
    output reg  [7:0]  o_disp_frames,
    output reg  [7:0]  o_off_frames,
    output reg         o_pin_override,
    output reg  [29:0] o_pin_value,

    input  wire [2:0]  i_seq_state,
    input  wire        i_ready,
    input  wire        i_disp,
    input  wire        i_bl_en,
    input  wire        i_frame_start,
    input  wire [1:0]  i_src_state,
    input  wire        i_src_underflow,   // pulses, pixel domain
    input  wire        i_src_misalign
);

    localparam [31:0] ID = 32'h4C434431;   // "LCD1"

    localparam [31:0] CTRL_RST = {22'd0, 1'b0, 1'b0, 2'b00, 1'b0,
                                  `LCD_DEF_DE_ACTIVE_LOW,
                                  `LCD_DEF_VS_ACTIVE_LOW,
                                  `LCD_DEF_HS_ACTIVE_LOW,
                                  `LCD_DEF_CLK_INVERT,
                                  1'b0};    // enable off until software asks

    assign s_axi_bresp = 2'b00;
    assign s_axi_rresp = 2'b00;

    // ======================================================================
    // AXI domain
    // ======================================================================
    reg [31:0] r_ctrl, r_h_act_fp, r_h_sync_bp, r_v_act_fp, r_v_sync_bp;
    reg [31:0] r_pattern, r_solid, r_seq_vdd, r_seq_frames, r_pin_value;
    reg [31:0] r_scratch;
    reg        apply_req;           // toggles on every config write

    // ---- write channel: accept AW and W together, one at a time ----
    wire do_write = s_axi_awvalid && s_axi_wvalid && !s_axi_bvalid &&
                    !s_axi_awready;

    function [31:0] merge(input [31:0] old, input [31:0] d, input [3:0] be);
        merge = { be[3] ? d[31:24] : old[31:24], be[2] ? d[23:16] : old[23:16],
                  be[1] ? d[15:8]  : old[15:8],  be[0] ? d[7:0]   : old[7:0] };
    endfunction

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
            s_axi_bvalid  <= 1'b0;
            apply_req     <= 1'b0;
            r_ctrl        <= CTRL_RST;
            r_h_act_fp    <= {4'd0, `LCD_DEF_H_FRONT, 4'd0, `LCD_DEF_H_ACTIVE};
            r_h_sync_bp   <= {4'd0, `LCD_DEF_H_BACK,  4'd0, `LCD_DEF_H_SYNC};
            r_v_act_fp    <= {4'd0, `LCD_DEF_V_FRONT, 4'd0, `LCD_DEF_V_ACTIVE};
            r_v_sync_bp   <= {4'd0, `LCD_DEF_V_BACK,  4'd0, `LCD_DEF_V_SYNC};
            r_pattern     <= 32'd0;
            r_solid       <= 32'd0;
            r_seq_vdd     <= {8'd0, `LCD_DEF_VDD_WAIT};
            r_seq_frames  <= {8'd0, `LCD_DEF_OFF_FRAMES, `LCD_DEF_DISP_FRAMES,
                              `LCD_DEF_BLANK_FRAMES};
            r_pin_value   <= 32'd0;
            r_scratch     <= 32'd0;
        end
        else begin
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
            if (s_axi_bvalid && s_axi_bready) s_axi_bvalid <= 1'b0;

            if (do_write) begin
                s_axi_awready <= 1'b1;
                s_axi_wready  <= 1'b1;
                s_axi_bvalid  <= 1'b1;
                case (s_axi_awaddr[7:2])
                    6'h02: r_ctrl       <= merge(r_ctrl,       s_axi_wdata, s_axi_wstrb);
                    6'h04: r_h_act_fp   <= merge(r_h_act_fp,   s_axi_wdata, s_axi_wstrb);
                    6'h05: r_h_sync_bp  <= merge(r_h_sync_bp,  s_axi_wdata, s_axi_wstrb);
                    6'h06: r_v_act_fp   <= merge(r_v_act_fp,   s_axi_wdata, s_axi_wstrb);
                    6'h07: r_v_sync_bp  <= merge(r_v_sync_bp,  s_axi_wdata, s_axi_wstrb);
                    6'h08: r_pattern    <= merge(r_pattern,    s_axi_wdata, s_axi_wstrb);
                    6'h09: r_solid      <= merge(r_solid,      s_axi_wdata, s_axi_wstrb);
                    6'h0A: r_seq_vdd    <= merge(r_seq_vdd,    s_axi_wdata, s_axi_wstrb);
                    6'h0B: r_seq_frames <= merge(r_seq_frames, s_axi_wdata, s_axi_wstrb);
                    6'h0C: r_pin_value  <= merge(r_pin_value,  s_axi_wdata, s_axi_wstrb);
                    6'h13: r_scratch    <= merge(r_scratch,    s_axi_wdata, s_axi_wstrb);
                    default: ;
                endcase
                if (s_axi_awaddr[7:2] != 6'h13) apply_req <= ~apply_req;
            end
        end
    end

    // ---- status from the pixel domain ----
    reg  [2:0] ack_sync;                    // echoed apply toggle
    reg [11:0] st_sync1, st_sync2;
    reg [31:0] fc_sync1, fc_sync2;          // Gray-coded frame counter
    reg [31:0] pc_sync1, pc_sync2;          // Gray-coded pixel clock counter

    // cross-domain launch registers, declared in the pixel section below
    reg        apply_ack;
    reg  [4:0] st_pix;
    reg        i_disp_q, i_bl_en_q;
    reg  [1:0] src_state_q;
    reg        src_uf_sticky, src_mis_sticky, src_clr;
    reg [31:0] fc_gray, pc_gray;

    always @(posedge s_axi_aclk) begin
        ack_sync <= {ack_sync[1:0], apply_ack};
        st_sync1 <= {src_mis_sticky, src_uf_sticky, src_state_q,
                     i_bl_en_q, i_disp_q, 1'b0, 1'b0, st_pix[3:0]};
        st_sync2 <= st_sync1;
        fc_sync1 <= fc_gray;  fc_sync2 <= fc_sync1;
        pc_sync1 <= pc_gray;  pc_sync2 <= pc_sync1;
    end

    function [31:0] gray2bin(input [31:0] g);
        integer k;
        begin
            gray2bin[31] = g[31];
            for (k = 30; k >= 0; k = k - 1)
                gray2bin[k] = gray2bin[k + 1] ^ g[k];
        end
    endfunction

    // ---- pixel clock meter: pixel cycles per 100 ms of AXI clock ----
    localparam integer GATE = AXI_HZ / 10;
    reg [31:0] gate_cnt, pc_last, pclk_hz;
    wire [31:0] pc_now = gray2bin(pc_sync2);
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            gate_cnt <= 32'd0;
            pc_last  <= 32'd0;
            pclk_hz  <= 32'd0;
        end
        else if (gate_cnt >= GATE - 1) begin
            gate_cnt <= 32'd0;
            pc_last  <= pc_now;
            pclk_hz  <= (pc_now - pc_last) * 10;
        end
        else gate_cnt <= gate_cnt + 1'b1;
    end

    wire [31:0] status = {20'd0, st_sync2[11:8], st_sync2[7:6], (pclk_hz != 32'd0),
                          (ack_sync[2] == apply_req), st_sync2[3:0]};

    // ---- read channel ----
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rdata   <= 32'd0;
        end
        else begin
            s_axi_arready <= 1'b0;
            if (s_axi_rvalid && s_axi_rready) s_axi_rvalid <= 1'b0;
            if (s_axi_arvalid && !s_axi_rvalid && !s_axi_arready) begin
                s_axi_arready <= 1'b1;
                s_axi_rvalid  <= 1'b1;
                case (s_axi_araddr[7:2])
                    6'h00: s_axi_rdata <= ID;
                    6'h01: s_axi_rdata <= BUILD_ID;
                    6'h02: s_axi_rdata <= r_ctrl;
                    6'h04: s_axi_rdata <= r_h_act_fp;
                    6'h05: s_axi_rdata <= r_h_sync_bp;
                    6'h06: s_axi_rdata <= r_v_act_fp;
                    6'h07: s_axi_rdata <= r_v_sync_bp;
                    6'h08: s_axi_rdata <= r_pattern;
                    6'h09: s_axi_rdata <= r_solid;
                    6'h0A: s_axi_rdata <= r_seq_vdd;
                    6'h0B: s_axi_rdata <= r_seq_frames;
                    6'h0C: s_axi_rdata <= r_pin_value;
                    6'h10: s_axi_rdata <= status;
                    6'h11: s_axi_rdata <= gray2bin(fc_sync2);
                    6'h12: s_axi_rdata <= pclk_hz;
                    6'h13: s_axi_rdata <= r_scratch;
                    default: s_axi_rdata <= 32'hDEAD_BEEF;
                endcase
            end
        end
    end

    // ======================================================================
    // Pixel domain
    // ======================================================================
    reg [2:0] req_sync;
    always @(posedge pix_clk) req_sync <= {req_sync[1:0], apply_req};
    wire capture = req_sync[2] ^ req_sync[1];

    reg soft_rst;
    assign o_pix_rst_n = pix_rst_n && !soft_rst;

    // The config capture is reset by the external reset only, never by the
    // soft reset it controls.
    always @(posedge pix_clk) begin
        if (!pix_rst_n) begin
            apply_ack       <= 1'b0;
            soft_rst        <= 1'b0;
            src_clr         <= 1'b0;
            o_enable        <= CTRL_RST[0];
            o_clk_invert    <= CTRL_RST[1];
            o_hs_active_low <= CTRL_RST[2];
            o_vs_active_low <= CTRL_RST[3];
            o_de_active_low <= CTRL_RST[4];
            o_de_only       <= CTRL_RST[5];
            o_pin_override  <= 1'b0;
            o_h_active      <= `LCD_DEF_H_ACTIVE;
            o_h_front       <= `LCD_DEF_H_FRONT;
            o_h_sync        <= `LCD_DEF_H_SYNC;
            o_h_back        <= `LCD_DEF_H_BACK;
            o_v_active      <= `LCD_DEF_V_ACTIVE;
            o_v_front       <= `LCD_DEF_V_FRONT;
            o_v_sync        <= `LCD_DEF_V_SYNC;
            o_v_back        <= `LCD_DEF_V_BACK;
            o_pattern       <= 4'd0;
            o_pattern_arg   <= 8'd0;
            o_solid         <= 24'd0;
            o_vdd_wait      <= `LCD_DEF_VDD_WAIT;
            o_blank_frames  <= `LCD_DEF_BLANK_FRAMES;
            o_disp_frames   <= `LCD_DEF_DISP_FRAMES;
            o_off_frames    <= `LCD_DEF_OFF_FRAMES;
            o_pin_value     <= 30'd0;
        end
        else if (capture) begin
            apply_ack       <= req_sync[1];
            o_enable        <= r_ctrl[0];
            o_clk_invert    <= r_ctrl[1];
            o_hs_active_low <= r_ctrl[2];
            o_vs_active_low <= r_ctrl[3];
            o_de_active_low <= r_ctrl[4];
            o_de_only       <= r_ctrl[5];
            soft_rst        <= r_ctrl[8];
            src_clr         <= r_ctrl[10];
            o_pin_override  <= r_ctrl[9];
            o_h_active      <= r_h_act_fp[11:0];
            o_h_front       <= r_h_act_fp[27:16];
            o_h_sync        <= r_h_sync_bp[11:0];
            o_h_back        <= r_h_sync_bp[27:16];
            o_v_active      <= r_v_act_fp[11:0];
            o_v_front       <= r_v_act_fp[27:16];
            o_v_sync        <= r_v_sync_bp[11:0];
            o_v_back        <= r_v_sync_bp[27:16];
            o_pattern       <= r_pattern[3:0];
            o_pattern_arg   <= r_pattern[15:8];
            o_solid         <= r_solid[23:0];
            o_vdd_wait      <= r_seq_vdd[23:0];
            o_blank_frames  <= r_seq_frames[7:0];
            o_disp_frames   <= r_seq_frames[15:8];
            o_off_frames    <= r_seq_frames[23:16];
            o_pin_value     <= r_pin_value[29:0];
        end
    end

    // status launch registers, so only flops cross the boundary
    reg [31:0] fc_bin, pc_bin;
    always @(posedge pix_clk) begin
        st_pix    <= {1'b0, i_ready, i_seq_state};
        i_disp_q  <= i_disp;
        i_bl_en_q <= i_bl_en;
        src_state_q <= i_src_state;
        if (!pix_rst_n || src_clr) begin
            src_uf_sticky  <= 1'b0;
            src_mis_sticky <= 1'b0;
        end
        else begin
            if (i_src_underflow) src_uf_sticky  <= 1'b1;
            if (i_src_misalign)  src_mis_sticky <= 1'b1;
        end
        if (!pix_rst_n) begin
            fc_bin  <= 32'd0;
            fc_gray <= 32'd0;
        end
        else if (i_frame_start) begin
            fc_bin  <= fc_bin + 1'b1;
            fc_gray <= (fc_bin + 1'b1) ^ ((fc_bin + 1'b1) >> 1);
        end
        // free-running, deliberately not reset: the meter only takes deltas
        pc_bin  <= pc_bin + 1'b1;
        pc_gray <= (pc_bin + 1'b1) ^ ((pc_bin + 1'b1) >> 1);
    end

    initial begin
        pc_bin = 32'd0; pc_gray = 32'd0;
        req_sync = 3'd0; ack_sync = 3'd0;
    end

endmodule

`default_nettype wire
