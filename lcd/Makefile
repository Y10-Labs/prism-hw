# iverilog regression for the LCD controller.  All paths are relative to this
# makefile; run `make` from this directory (or `make -C lcd`).
IVERILOG ?= iverilog
VVP      ?= vvp

RTL  := rtl/lcd_timing.v rtl/lcd_power_seq.v rtl/lcd_clock_out.v rtl/lcd_controller.v
BUILD := build

.PHONY: all test timing sequence clean
all: test

test: timing sequence
	@echo "all LCD testbenches passed"

timing: $(BUILD)/lcd_timing_tb
	@$(VVP) $< | tee $(BUILD)/lcd_timing_tb.log
	@grep -q "== PASS ==" $(BUILD)/lcd_timing_tb.log

sequence: $(BUILD)/lcd_controller_tb
	@$(VVP) $< | tee $(BUILD)/lcd_controller_tb.log
	@grep -q "== PASS ==" $(BUILD)/lcd_controller_tb.log

$(BUILD)/lcd_timing_tb: $(RTL) tb/lcd_timing_tb.v | $(BUILD)
	$(IVERILOG) -g2005 -o $@ -s lcd_timing_tb $(RTL) tb/lcd_timing_tb.v

$(BUILD)/lcd_controller_tb: $(RTL) tb/lcd_controller_tb.v | $(BUILD)
	$(IVERILOG) -g2005 -o $@ -s lcd_controller_tb $(RTL) tb/lcd_controller_tb.v

$(BUILD):
	@mkdir -p $(BUILD)

clean:
	rm -rf $(BUILD)
