read_verilog src/*.v

# Check design hierarchy
hierarchy -check -top riscv_core

# the high-level stuff
proc; opt; fsm; opt; memory; opt

# mapping to internal cell library
techmap; opt

# clean out unused space
clean

# output JSON for netlistsvg
write_json build/synth.json
