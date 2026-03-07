.PHONY: all compile sim synth svg clean

all: sim

compile:
	$(MAKE) -C sw all

sim: compile
	mkdir -p build
	iverilog -o build/core_sim.vvp -I src src/*.v tb/tb_riscv_core.v
	vvp build/core_sim.vvp

synth:
	yosys -s scripts/yosys_synth.tcl

svg: synth
	netlistsvg build/synth.json -o build/synth.svg

clean:
	rm -rf build
	$(MAKE) -C sw clean
