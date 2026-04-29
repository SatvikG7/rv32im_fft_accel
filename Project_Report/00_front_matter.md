# Abstract

The Fast Fourier Transform (FFT) is one of the most fundamentally important algorithms in digital signal processing (DSP), enabling efficient transformation between time and frequency domains. As the demand for real-time processing in edge computing, telecommunications, and embedded systems grows, software implementations of FFT on general-purpose processors struggle to meet stringent latency and power constraints. To address these limitations, hardware acceleration is frequently employed. However, traditional coprocessor-based accelerators often suffer from significant communication overhead and lack flexibility.

This project presents the comprehensive design, implementation, and verification of a modular, runtime-configurable FFT hardware accelerator tightly integrated within the execution stage of a custom 5-stage pipelined RISC-V processor. The architecture supports N-point radix-2 Decimation-In-Time (DIT) FFT computations for variable sizes (N = 2, 4, 8, 16, 32, and 64), utilizing the IEEE 754-like half-precision floating-point (FP16) arithmetic format to optimize the balance between dynamic range and hardware area.

A key innovation of this design is its seamless integration via the RISC-V custom instruction extension space. The accelerator is controlled using four custom instructions (`FFT.SETN`, `FFT.LOAD`, `FFT.EXEC`, and `FFT.READ`), which eliminate bus communication latency. The hardware architecture features automated on-the-fly bit-reversal during data loading, a compact 32-entry combinational twiddle factor ROM shared across all transform sizes, and a time-multiplexed memory-based butterfly engine that ensures low area overhead. Pipeline synchronization is achieved through a stall-based mechanism that ensures hazard-free execution without requiring modifications to the core's existing forwarding or hazard detection logic.

The design was verified using cycle-accurate RTL simulation and synthesized targeting a generic gate-level netlist using Yosys. Experimental results demonstrate that the tightly coupled hardware accelerator achieves a 10× to 19× speedup over an equivalent software implementation running on the same core, while reducing the instruction count by over 200× for a 16-point transform. The hardware utilizes approximately 27,000 logic cells and maintains a relative computational error of less than 2%, establishing it as a highly efficient solution for embedded DSP applications requiring strict area-performance trade-offs.

---

# List of Tables

1. Table 4.1: Custom RISC-V Instruction Encoding for FFT Accelerator
2. Table 4.2: Hardware Bit-Reversal Permutation Mapping for N=8
3. Table 4.3: FP16 Format Bit Allocation
4. Table 5.1: Verification Toolchain and Environment
5. Table 5.2: 4-Point FFT Functional Verification Results
6. Table 5.3: 8-Point FFT Functional Verification Results
7. Table 5.4: Synthesis Resource Utilization by Module (Yosys)
8. Table 5.5: Measured Hardware FFT Cycle Counts across N
9. Table 5.6: Hardware vs. Software Cycle Count and Speedup
10. Table 5.7: Instruction Count Reduction for 16-point FFT
11. Table 5.8: Cross-Platform Architectural Comparison
12. Table 5.9: FP16 Quantization Error Analysis

---

# List of Figures

1. Figure 1.1: Typical DSP pipeline utilizing FFT
2. Figure 3.1: Comparison of Pipelined vs. Memory-based FFT Architectures
3. Figure 4.1: System-Level Block Diagram of RISC-V Core with FFT Accelerator
4. Figure 4.2: Radix-2 DIT Butterfly Signal Flow Graph
5. Figure 4.3: Twiddle Factor ROM Indexing Strategy for Variable N
6. Figure 4.4: FFT Accelerator Wrapper and Pipeline Interface
7. Figure 4.5: FFT Engine Finite State Machine (FSM) Diagram
8. Figure 4.6: Butterfly Unit Internal Datapath and Complex Multiplier
9. Figure 4.7: FP16 Multiplier and Adder Hardware Dataflow
10. Figure 4.8: Pipeline Timing Diagram demonstrating Stall Mechanism during `FFT.EXEC`
11. Figure 5.1: 16-Point FFT Hardware vs. Reference Output Comparison Chart
12. Figure 5.2: Relative Error per Bin for 16-point FFT
13. Figure 5.3: Log-log Plot of Cycle Count vs. FFT Size
14. Figure 5.4: Speedup Factor Bar Chart (Hardware vs. Software)
15. Figure 5.5: Simulation Waveform (VCD) showing FSM transitions and signal states

---

# List of Symbols and Abbreviations

- **ALU**: Arithmetic Logic Unit
- **ASIC**: Application-Specific Integrated Circuit
- **BFU**: Butterfly Unit
- **CPU**: Central Processing Unit
- **DFT**: Discrete Fourier Transform
- **DIT**: Decimation-In-Time
- **DSP**: Digital Signal Processing
- **FFT**: Fast Fourier Transform
- **FP16**: Half-Precision Floating-Point (16-bit)
- **FP32**: Single-Precision Floating-Point (32-bit)
- **FSM**: Finite State Machine
- **HDL**: Hardware Description Language
- **IF, ID, EX, MEM, WB**: Instruction Fetch, Decode, Execute, Memory, Write-Back (Pipeline Stages)
- **ISA**: Instruction Set Architecture
- **LSB**: Least Significant Bit
- **LUT**: Look-Up Table
- **MAC**: Multiply-Accumulate
- **MDC**: Multi-path Delay Commutator
- **RISC-V**: Reduced Instruction Set Computer - Five
- **ROM**: Read-Only Memory
- **RTL**: Register Transfer Level
- **SDF**: Single-path Delay Feedback
- **SNR**: Signal-to-Noise Ratio
- **VCD**: Value Change Dump
