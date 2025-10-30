# Makefile for Raster Core Testbench

# Default simulator (can be overridden)
SIM ?= iverilog

# Source files
SOURCES = raster_core.v tb.v
TOP_MODULE = tb_raster_core

# Simulation parameters
BRAM_LATENCY ?= 2
CORE_ID ?= 0

# Default target
all: sim

# Compile and run simulation with iverilog
sim: $(SOURCES) memory_init.hex
	@echo "Compiling with $(SIM)..."
	$(SIM) -o sim_out -D BRAM_LATENCY=$(BRAM_LATENCY) -D CORE_ID=$(CORE_ID) $(SOURCES)
	@echo "Running simulation..."
	./sim_out

# Run with different BRAM latencies
test_latency1:
	$(MAKE) sim BRAM_LATENCY=1

test_latency2:
	$(MAKE) sim BRAM_LATENCY=2

test_latency3:
	$(MAKE) sim BRAM_LATENCY=3

test_latency4:
	$(MAKE) sim BRAM_LATENCY=4

# Run all latency tests
test_all_latencies: test_latency1 test_latency2 test_latency3 test_latency4

# Clean generated files
clean:
	rm -f sim_out
	rm -f tb_raster_core.vcd
	rm -f *.out
	rm -f *.log

# View waveforms (requires gtkwave)
waves:
	gtkwave tb_raster_core.vcd &

# Help
help:
	@echo "Available targets:"
	@echo "  sim                 - Compile and run simulation (default)"
	@echo "  test_latency1       - Test with BRAM latency = 1"
	@echo "  test_latency2       - Test with BRAM latency = 2"
	@echo "  test_latency3       - Test with BRAM latency = 3"
	@echo "  test_latency4       - Test with BRAM latency = 4"
	@echo "  test_all_latencies  - Run tests with all latencies"
	@echo "  waves               - View waveforms with gtkwave"
	@echo "  clean               - Clean generated files"
	@echo "  help                - Show this help"
	@echo ""
	@echo "Parameters:"
	@echo "  BRAM_LATENCY=N      - Set BRAM latency (default: 2)"
	@echo "  CORE_ID=N           - Set core ID (default: 0)"
	@echo "  SIM=simulator       - Set simulator (default: iverilog)"

.PHONY: all sim test_latency1 test_latency2 test_latency3 test_latency4 test_all_latencies clean waves help
