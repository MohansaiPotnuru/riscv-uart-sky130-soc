# Simulation / lint helpers. The ASIC flow itself runs inside OpenLane (see README).
SRC := src/picorv32.v src/boot_rom.v src/uart_tx.v src/riscv_uart_soc.v
TB  := tb/tb_riscv_uart_soc.v

.PHONY: all sim wave lint synth rom clean

all: sim

sim: build/sim.vvp
	vvp -n build/sim.vvp

wave: build/sim.vvp
	cd build && vvp -n sim.vvp +vcd && echo "open build/tb_riscv_uart_soc.vcd in GTKWave"

build/sim.vvp: $(SRC) $(TB)
	@mkdir -p build
	iverilog -g2012 -Wall -Wno-timescale -o $@ $(TB) $(SRC)

lint:
	verilator --lint-only -Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-PINCONNECTEMPTY \
	  --top-module riscv_uart_soc src/boot_rom.v src/uart_tx.v src/riscv_uart_soc.v src/picorv32.v \
	  -Wno-fatal

# Quick generic synthesis to sanity-check the RTL and report cell usage.
synth:
	@mkdir -p build
	yosys -q -p "read_verilog -DSYNTHESIS $(SRC); synth -top riscv_uart_soc; stat" -l build/yosys.log
	@grep -A40 "Printing statistics" build/yosys.log | head -60

rom:
	python3 firmware/gen_rom.py

clean:
	rm -rf build
