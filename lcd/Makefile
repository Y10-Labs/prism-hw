# iverilog regression for the LCD controller.  All paths are relative to this
# makefile; run `make` from this directory (or `make -C lcd`).
IVERILOG ?= iverilog
VVP      ?= vvp

RTL  := rtl/lcd_timing.v rtl/lcd_power_seq.v rtl/lcd_clock_out.v rtl/lcd_controller.v \
        rtl/lcd_regs_axil.v rtl/lcd_async_fifo.v rtl/lcd_stream_src.v
IVFLAGS := -g2005 -I rtl
BUILD := build

# The timing tb runs three modes: the default 832x500, the ST7262 typical
# 816x496, and the default with active-high syncs.
TIMING_TYP := -Plcd_timing_tb.H_FRONT=8 -Plcd_timing_tb.H_BACK=4 \
              -Plcd_timing_tb.V_FRONT=8 -Plcd_timing_tb.V_BACK=4
TIMING_POS := -Plcd_timing_tb.SYNC_AL=0

.PHONY: all test timing timing_typ timing_pos sequence regs stream clean
all: test

test: timing timing_typ timing_pos sequence regs stream
	@echo "all LCD testbenches passed"

timing: $(BUILD)/lcd_timing_tb
	@$(VVP) $< | tee $(BUILD)/lcd_timing_tb.log
	@grep -q "== PASS ==" $(BUILD)/lcd_timing_tb.log

timing_typ: $(BUILD)/lcd_timing_typ_tb
	@$(VVP) $< | tee $(BUILD)/lcd_timing_typ_tb.log
	@grep -q "== PASS ==" $(BUILD)/lcd_timing_typ_tb.log

timing_pos: $(BUILD)/lcd_timing_pos_tb
	@$(VVP) $< | tee $(BUILD)/lcd_timing_pos_tb.log
	@grep -q "== PASS ==" $(BUILD)/lcd_timing_pos_tb.log

regs: $(BUILD)/lcd_regs_tb
	@$(VVP) $< | tee $(BUILD)/lcd_regs_tb.log
	@grep -q "== PASS ==" $(BUILD)/lcd_regs_tb.log

stream: $(BUILD)/lcd_stream_tb
	@$(VVP) $< | tee $(BUILD)/lcd_stream_tb.log
	@grep -q "== PASS ==" $(BUILD)/lcd_stream_tb.log

sequence: $(BUILD)/lcd_controller_tb
	@$(VVP) $< | tee $(BUILD)/lcd_controller_tb.log
	@grep -q "== PASS ==" $(BUILD)/lcd_controller_tb.log

$(BUILD)/lcd_timing_tb: $(RTL) tb/lcd_timing_tb.v | $(BUILD)
	$(IVERILOG) $(IVFLAGS) -o $@ -s lcd_timing_tb $(RTL) tb/lcd_timing_tb.v

$(BUILD)/lcd_timing_typ_tb: $(RTL) tb/lcd_timing_tb.v | $(BUILD)
	$(IVERILOG) $(IVFLAGS) $(TIMING_TYP) -o $@ -s lcd_timing_tb $(RTL) tb/lcd_timing_tb.v

$(BUILD)/lcd_timing_pos_tb: $(RTL) tb/lcd_timing_tb.v | $(BUILD)
	$(IVERILOG) $(IVFLAGS) $(TIMING_POS) -o $@ -s lcd_timing_tb $(RTL) tb/lcd_timing_tb.v

$(BUILD)/lcd_controller_tb: $(RTL) tb/lcd_controller_tb.v | $(BUILD)
	$(IVERILOG) $(IVFLAGS) -o $@ -s lcd_controller_tb $(RTL) tb/lcd_controller_tb.v

$(BUILD)/lcd_stream_tb: $(RTL) tb/lcd_stream_tb.v | $(BUILD)
	$(IVERILOG) $(IVFLAGS) -o $@ -s lcd_stream_tb $(RTL) tb/lcd_stream_tb.v

$(BUILD)/lcd_regs_tb: $(RTL) tb/lcd_regs_tb.v | $(BUILD)
	$(IVERILOG) $(IVFLAGS) -o $@ -s lcd_regs_tb $(RTL) tb/lcd_regs_tb.v

$(BUILD):
	@mkdir -p $(BUILD)

clean:
	rm -rf $(BUILD)
