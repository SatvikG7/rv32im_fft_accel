# 2. Objectives

The primary aim of this major project is to design, implement, and verify a modular, tightly coupled hardware Fast Fourier Transform (FFT) accelerator within a RISC-V processor architecture. To achieve this overarching goal, the project is divided into several specific, measurable objectives across hardware design, system integration, and performance validation.

## 2.1 Primary Objectives

1. **Design a Modular FFT Computational Engine:**
   - Develop an RTL (Register Transfer Level) implementation of the Cooley-Tukey Radix-2 Decimation-In-Time (DIT) FFT algorithm.
   - Ensure the architecture is runtime-configurable to support variable transform sizes: $N \in \{2, 4, 8, 16, 32, 64\}$.
   - Optimize for low silicon area by employing a memory-based architecture utilizing a single, time-multiplexed Butterfly Unit rather than a fully parallel or deep pipelined array.

2. **Implement Half-Precision (FP16) Arithmetic:**
   - Design custom floating-point adders, subtractors, and multipliers compliant with the IEEE 754 binary16 format.
   - Utilize FP16 to eliminate the need for fixed-point scaling schedules while maintaining a smaller area footprint compared to standard 32-bit floating-point (FP32).

3. **Develop Zero-Overhead Hardware Integration:**
   - Integrate the FFT engine directly into the Execute (EX) stage of a standard 5-stage pipelined RISC-V core.
   - Define and implement a custom instruction set (utilizing RISC-V custom opcodes) to interface with the accelerator natively, avoiding standard bus (e.g., AXI/Wishbone) communication overhead.
   - Implement a hazard-free stall mechanism that freezes the processor pipeline during multi-cycle FFT computations without requiring destructive modifications to the core's native hazard detection and forwarding logic.

## 2.2 Secondary Objectives

4. **Hardware-Accelerated Data Permutation:**
   - Implement bit-reversal sorting directly in hardware during the data loading phase. This objective aims to entirely offload the $O(N)$ permutation overhead from the software, simplifying firmware development and reducing overall transform latency.

5. **Resource-Efficient Twiddle Factor Storage:**
   - Design a unified twiddle factor strategy that shares a single, compact Read-Only Memory (ROM) across all supported FFT sizes.
   - Implement combinatorial logic to calculate the correct stride and address offset for varying $N$, avoiding the need for multiple ROMs or runtime trigonometric calculations.

6. **Comprehensive Verification and Benchmarking:**
   - Develop automated testbenches to verify functional correctness against golden reference models (e.g., NumPy FFT).
   - Perform cycle-accurate simulations to quantify the performance speedup of the hardware accelerator compared to a pure software emulation running on the same RISC-V core.
   - Synthesize the design using open-source tools (Yosys) to accurately profile logic cell utilization and prove the design's viability for embedded implementations.
   - Analyze the quantization error introduced by the FP16 format across multiple stages of computation.
