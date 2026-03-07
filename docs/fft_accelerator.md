# FFT Accelerator

To highly optimize Digital Signal Processing workloads, this RISC-V project incorporates an integrated Floating-Point 16 (FP16) Fast Fourier Transform (FFT) Accelerator.

## Overview
The `fft_accelerator.v` module resides alongside the pipeline (connected via the Execute stage) and provides dedicated compute paths for hardware-level mathematical transformation.

### Available Operations
The accelerator decodes a specific 3-bit operation signal:
- `000` (`butterfly`): Triggers the FP16 Butterfly Unit.
- `001` (`complex_mul`): Triggers the Complex Multiplier Unit.

### Sub-Modules
1. **Butterfly Unit (`butterfly_unit.v`)**: Computes an algorithmic FFT butterfly calculation using FP16 adders and multipliers. It processes a base node and its relative offset node using a Twiddle Factor.
2. **Complex Multiplier (`complex_mul_unit.v`)**: Highly pipelined mechanism resolving `(a + bi) * (c + di)` exclusively mapped over half-precision floats.
3. **FP16 Arithmetic Modules (`fp16_add.v`, `fp16_mul.v`)**: Provide standard IEEE-754 like half-precision floating pointer functionality essential for precise frequency representations.
4. **Twiddle ROM (`twiddle_rom.v`)**: Contains pre-computed trigonometric Twiddle Factors needed during deep FFT passes.

## Instruction Integration
The custom instruction set integrates tightly with the software stack:
- Opcode `0x0B` triggers custom instructions inside the Decode stage.
- Operands are loaded from the standard 32-bit registers (e.g., each 32-bit register packs two 16-bit half-precision chunks: real & imaginary).
- The custom instructions invoke `start` on the accelerator and stall the CPU pipeline if the compute takes multiple cycles (`fft_busy`).
- `fft_done` signals the end of the operation, subsequently writing the 32-bit custom FP16 chunks payload back into the destination register.
