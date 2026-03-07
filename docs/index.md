# RISC-V RV32I Processor with FFT Accelerator

Welcome to the documentation for the 32-bit RISC-V processor project! This project implements a fully functional 5-stage pipelined RISC-V RV32I core from scratch in Verilog, designed with modularity in mind and optimized for digital signal processing tasks via a custom built-in floating-point (FP16) FFT accelerator.

## Project Structure

```text
.
├── src/        # Verilog source files for the RISC-V core and FFT accelerator
├── sw/         # Software components, firmware, assembly programs, and linker script
├── tb/         # Testbenches for verification and simulation
├── scripts/    # Scripts for EDA tools (e.g., Yosys synthesis)
├── docs/       # Project documentation (you are here)
├── build/      # Generated files during simulation or synthesis (created by make)
└── Makefile    # Top-level Makefile for build, simulation, synth, and svg generation
```

## Key Features
- **RV32I Base Integer Instruction Set**: Full support for standard RISC-V integer arithmetic, logical, memory, and branch instructions.
- **5-Stage Pipeline**: Classic RISC pipeline structure (Fetch, Decode, Execute, Memory, Writeback).
- **Hazard Unit**: Handles data hazards (data forwarding) and control hazards (pipeline flushing and stalling).
- **FFT Accelerator**: Custom floating-point (FP16) hardware accelerator for fast Fourier transform operations.
- **Custom Instructions**: Extended opcode space (`0x0B`) seamlessly integrates FFT compute into the processor pipeline.
- **Toolchain Integration**: Easily simulate using Icarus Verilog, test bare-metal programs with a GNU RISC-V toolchain, and synthesize with Yosys.

## Getting Started

To compile software, run tests, and synthesize the hardware, please refer to the specific documentation files:
- [Core Architecture](architecture.md)
- [FFT Accelerator](fft_accelerator.md)
- [Software Development](software.md)
- [Simulation & Intergration](simulation.md)
- [Synthesis](synthesis.md)

At a high level, the `Makefile` in the root directory controls the primary flow:
- `make sim`: Compiles the software in `sw/`, builds the simulation executable with `iverilog`, and runs it.
- `make compile`: Only compiles the RISC-V software payload.
- `make synth`: Synthesizes the design using Yosys.
- `make svg`: Generates a netlist SVG visualization using `netlistsvg`.
- `make clean`: Removes the `build/` directory and cleans `sw/`.
