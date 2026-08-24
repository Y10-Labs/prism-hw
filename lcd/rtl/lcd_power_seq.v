// ---------------------------------------------------------------------------
// lcd_power_seq - power-up / power-down sequencer for the CH500WV05A-T
//
// IMPORTANT: the panel datasheet (SPEC-CH500WV05A-T V0) documents its INTERNAL
// rail order only (VDD -> VEE -> VGH on, reverse off) and gives NO numeric
// values for any of the intervals it names.  It says nothing whatsoever about
// the ordering of DISP / DCLK / DE / backlight.  The sequence below is the
// standard convention for DE-mode RGB TFTs, not a datasheet-verified figure.
// Treat every delay here as a starting point to tune on real hardware.
//
// The one rule that IS from the datasheet is Absolute Maximum Ratings:
//   Vin = -0.3 V .. VDD+0.3 V
// i.e. never drive a panel input before VDD is up or after it is down.  On the
// Prism board this is structurally satisfied: panel VDD (J701.4) and the Zynq
// VCCO_13 that powers every signal driver are the same +3V3 net.
//
// Power on : VDD stable -> blank timing -> DISP high -> backlight on -> pixels
// Power off: backlight off -> DISP low -> timing stops (VDD removed last)
// ---------------------------------------------------------------------------

`default_nettype none

module lcd_power_seq #(
    // Cycles to wait after reset for the panel's internal VDD->VEE->VGH ramp.
    // Default 332_640 = 10 ms at 33.264 MHz.
    parameter integer VDD_WAIT_CYCLES = 332640,
    // Frames of valid blank timing before DISP is asserted.
    parameter integer BLANK_FRAMES    = 2,
    // Frames after DISP before the backlight is enabled (stops the white flash).
    parameter integer DISP_FRAMES     = 10,
    // Frames after the backlight is cut before DISP drops, on the way down.
    parameter integer OFF_FRAMES      = 2
)(
    input  wire clk,
    input  wire rst_n,
    input  wire i_enable,       // high = bring the panel up, low = take it down
    input  wire i_frame_start,  // one-cycle pulse per frame from lcd_timing

    output reg  o_timing_en,    // run the timing generator
    output reg  o_blank,        // force pixel data to black
    output reg  o_disp,         // panel DISP pin (J701.31)
    output reg  o_bl_en,        // backlight boost enable (MT3608 EN)
    output wire o_ready         // sequence complete, pixels are being shown
);

    localparam [2:0] S_OFF       = 3'd0,
                     S_VDD_WAIT  = 3'd1,
                     S_BLANK     = 3'd2,
                     S_DISP_WAIT = 3'd3,
                     S_RUN       = 3'd4,
                     S_BL_OFF    = 3'd5,
                     S_DISP_OFF  = 3'd6;

    localparam integer CW = (VDD_WAIT_CYCLES <= 2) ? 1 : $clog2(VDD_WAIT_CYCLES);
    localparam integer MAXF = (BLANK_FRAMES > DISP_FRAMES)
                              ? ((BLANK_FRAMES > OFF_FRAMES) ? BLANK_FRAMES : OFF_FRAMES)
                              : ((DISP_FRAMES > OFF_FRAMES) ? DISP_FRAMES  : OFF_FRAMES);
    // +1 headroom: the counter is compared against MAXF itself, not MAXF-1,
    // because the first i_frame_start marks the start of a frame rather than
    // the end of one.
    localparam integer FW = (MAXF <= 2) ? 3 : ($clog2(MAXF) + 2);

    // Counting convention: i_frame_start pulses at the START of a frame, so a
    // state entered asynchronously seeds frame_cnt at 0, while a state entered
    // on a frame_start pulse seeds it at 1 (that pulse is already a boundary).
    // Either way, ">= N" then means exactly N complete frames.
    reg [2:0]    state;
    reg [CW-1:0] wait_cnt;
    reg [FW-1:0] frame_cnt;

    assign o_ready = (state == S_RUN);

    always @(posedge clk) begin
        if (!rst_n) begin
            state     <= S_OFF;
            wait_cnt  <= {CW{1'b0}};
            frame_cnt <= {FW{1'b0}};
        end
        else begin
            case (state)
                // ---- bring-up -------------------------------------------------
                S_OFF: begin
                    wait_cnt  <= {CW{1'b0}};
                    frame_cnt <= {FW{1'b0}};
                    if (i_enable) state <= S_VDD_WAIT;
                end

                // let the panel finish its own VDD -> VEE -> VGH ramp
                S_VDD_WAIT: begin
                    if (!i_enable) state <= S_OFF;
                    else if (wait_cnt >= VDD_WAIT_CYCLES - 1) begin
                        wait_cnt  <= {CW{1'b0}};
                        frame_cnt <= {FW{1'b0}};
                        state     <= S_BLANK;
                    end
                    else wait_cnt <= wait_cnt + 1'b1;
                end

                // valid timing running, data forced black, DISP still low
                S_BLANK: begin
                    if (!i_enable) state <= S_OFF;
                    else if (i_frame_start) begin
                        if (frame_cnt >= BLANK_FRAMES) begin
                            frame_cnt <= {{(FW-1){1'b0}}, 1'b1};  // this pulse counts
                            state     <= S_DISP_WAIT;
                        end
                        else frame_cnt <= frame_cnt + 1'b1;
                    end
                end

                // DISP asserted, still black, let the LC settle before lighting up
                S_DISP_WAIT: begin
                    if (!i_enable) state <= S_BL_OFF;
                    else if (i_frame_start) begin
                        if (frame_cnt >= DISP_FRAMES) begin
                            frame_cnt <= {FW{1'b0}};
                            state     <= S_RUN;
                        end
                        else frame_cnt <= frame_cnt + 1'b1;
                    end
                end

                S_RUN: begin
                    frame_cnt <= {FW{1'b0}};
                    if (!i_enable) state <= S_BL_OFF;
                end

                // ---- tear-down ------------------------------------------------
                // backlight goes first so the LEDs are dark before the image
                // collapses, then DISP, and only then does timing stop.
                S_BL_OFF: begin
                    if (i_frame_start) begin
                        if (frame_cnt >= OFF_FRAMES) begin
                            frame_cnt <= {{(FW-1){1'b0}}, 1'b1};  // this pulse counts
                            state     <= S_DISP_OFF;
                        end
                        else frame_cnt <= frame_cnt + 1'b1;
                    end
                end

                S_DISP_OFF: begin
                    if (i_frame_start) begin
                        if (frame_cnt >= OFF_FRAMES) begin
                            frame_cnt <= {FW{1'b0}};
                            state     <= S_OFF;
                        end
                        else frame_cnt <= frame_cnt + 1'b1;
                    end
                end

                default: state <= S_OFF;
            endcase
        end
    end

    // Outputs are registered off the state so they are glitch-free at the pins.
    always @(posedge clk) begin
        if (!rst_n) begin
            o_timing_en <= 1'b0;
            o_blank     <= 1'b1;
            o_disp      <= 1'b0;
            o_bl_en     <= 1'b0;
        end
        else begin
            o_timing_en <= (state == S_BLANK) || (state == S_DISP_WAIT) ||
                           (state == S_RUN)   || (state == S_BL_OFF)    ||
                           (state == S_DISP_OFF);
            o_blank     <= (state != S_RUN);
            o_disp      <= (state == S_DISP_WAIT) || (state == S_RUN) ||
                           (state == S_BL_OFF);
            o_bl_en     <= (state == S_RUN);
        end
    end

endmodule

`default_nettype wire
