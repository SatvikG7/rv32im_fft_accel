# Hardware Synthesis

The hardware design is synthesized utilizing Yosys Open SYnthesis Suite.

## Process

1. **Yosys Synthesis (`make synth`)**:
   Runs standard Verilog files against `scripts/yosys_synth.tcl`. This process maps structural and behavioral descriptions into a technology-independent RTL/Gate-Level format (typically JSON/EDIF depending on workflow). The output relies upon the definitions modeled within your `oss-cad-suite` binaries context.

2. **Topological Mapping (`make svg`)**:
   Uses `netlistsvg` to transform generated `.json` logic constructs into an extremely insightful SVG picture mapping out combinations of Logic Gates, Multiplexers, Memory elements, and specific FFT structures layout connections.

## Expected Outcomes
Check the `build/` directory for `synth.json` post-synthesis or `synth.svg` representations. If the SVGs appear highly dense, it signifies accurate instantiation of full 32-bit width operations multiplexed alongside FP16 accelerator modules across pipelined environments.
