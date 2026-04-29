# I. Introduction

The Fast Fourier Transform (FFT), first popularized by Cooley and Tukey in 1965 [1], remains one of the most widely used algorithms in digital signal processing (DSP). It reduces the computational complexity of the Discrete Fourier Transform (DFT) from O(N²) to O(N log N), enabling real-time spectral analysis in applications ranging from wireless communications and radar to medical imaging and audio processing [2].

In embedded and edge-computing scenarios, FFT computation is often delegated to software routines running on general-purpose processors. While this approach offers flexibility, it introduces significant latency, energy overhead, and instruction-fetch bottlenecks — particularly for real-time constraints. Dedicated DSP processors and FPGA-based accelerators address these limitations, but they typically operate as external coprocessors with high communication overhead [3].

The RISC-V instruction set architecture (ISA) [4] has emerged as an open, extensible platform that explicitly supports domain-specific customization through reserved custom opcode spaces. This extensibility enables the tight integration of hardware accelerators directly into the processor pipeline, eliminating the latency of coprocessor communication protocols while maintaining software programmability.

This paper presents a modular FFT hardware accelerator designed as a custom functional unit within a 5-stage pipelined RISC-V processor. The key contributions of this work are:

1. **Modular FFT Engine**: A single FSM-based engine supporting N-point radix-2 DIT FFT for N ∈ {2, 4, 8, 16, 32, 64}, configurable at runtime through a custom instruction.

2. **FP16 Arithmetic Pipeline**: All computations use IEEE 754-like half-precision floating-point (FP16) arithmetic, balancing numerical precision with area efficiency — a format increasingly relevant for edge AI and DSP workloads [5].

3. **Tight Pipeline Integration**: Four custom RISC-V instructions (`FFT.SETN`, `FFT.LOAD`, `FFT.EXEC`, `FFT.READ`) interface directly with the processor's execute stage, using a stall-based mechanism that requires zero modifications to the existing hazard forwarding logic.

4. **Hardware Bit-Reversal**: The input permutation required by the DIT algorithm is performed in hardware during the data loading phase, eliminating software overhead and reducing total cycle count.

5. **Compact Twiddle Factor Storage**: A single 32-entry ROM stores pre-computed twiddle factors for the maximum supported FFT size (N=64), with smaller sizes accessing the same table through stride-based indexing.

The remainder of this paper is organized as follows. Section II reviews related work in FFT hardware implementations and RISC-V accelerator integration. Section III details the design methodology, including the algorithm, data representation, and integration strategy. Section IV presents the hardware architecture of the FFT engine and processor pipeline. Section V reports simulation and synthesis results, and Section VI concludes with future work.
