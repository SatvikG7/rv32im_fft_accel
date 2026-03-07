# Simulation and Verification

Verification takes place heavily in the `tb/` (testbench) directory utilizing open-source Verilog simulation tools.

## Tools Required
- **Icarus Verilog (`iverilog`)**: Compilation engine for testbenches.
- **GtkWave**: Waveform viewer for analyzing `.vcd` files.
- `oss-cad-suite`: Provides integrated versions of necessary open-source verification software.

## Testbenches include:
- `tb_riscv_core.v`: Verifies the full Core pipeline execution (instructions executing properly and hazard control verification).
- `tb_integration.v`: Tests interactions between the RISC-V pipeline and the FFT Accelerator payload.
- `tb_fft_accelerator.v` / `tb_fft_accel_standalone.v`: Isolated evaluation of complex FFT workloads.
- `tb_complex_mul_unit.v` / `tb_fp16_arithmetic.v`: Unit testing arithmetic accuracy for FP16 compute nodes matching IEEE specs.
- `tb_benchmark.v`: Evaluates total instruction throughput metrics and overall cycles necessary relative to varying hardware topologies.

## Running Simulations
From the root directory:
```bash
make sim
```
This triggers the firmware assembly build, invokes `iverilog` to create `build/core_sim.vvp`, and executes `vvp`. VCD traces are typically captured and dumped to the `build/` directory for manual inspection via `gtkwave`.
