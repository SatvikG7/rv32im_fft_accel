# 3. Literature Review

The development of hardware accelerators for the Fast Fourier Transform (FFT) and their integration into processor architectures has a rich history in VLSI design and computer architecture. This section reviews the fundamental approaches to FFT hardware design, the selection of numerical precision, and modern methods of accelerator integration using the RISC-V ISA.

## 3.1 FFT Hardware Architectures

Hardware implementations of the FFT are heavily influenced by the required trade-off between throughput (speed) and silicon area. The architectures broadly fall into three categories:

### 3.1.1 Pipelined Architectures
Pipelined architectures are designed for high-throughput, continuous data streams, typical in telecommunications (e.g., OFDM receivers). These designs cascade multiple stages of processing, where each stage of the FFT algorithm has dedicated hardware.
- **Multi-path Delay Commutator (MDC):** Divides the input into multiple parallel streams, utilizing commutators and delay elements to route data to butterfly units.
- **Single-path Delay Feedback (SDF):** A highly efficient pipelined approach that uses shift registers in a feedback loop to reuse a single butterfly unit per stage. For an $N$-point FFT, SDF requires $\log_2(N)$ butterfly units. While highly efficient for fixed-size continuous data, pipelined architectures consume significant area for large $N$ and are difficult to reconfigure for variable FFT sizes at runtime.

### 3.1.2 Memory-Based (In-Place) Architectures
Memory-based architectures minimize logic area by utilizing a single centralized memory buffer and a small number of Butterfly Units (often just one). The data is read from memory, processed by the butterfly unit, and written back to the memory in an iterative process.
- **Advantages:** Highly area-efficient. Easily reconfigurable for different values of $N$ by simply modifying the address generation logic and the number of loop iterations.
- **Disadvantages:** Lower throughput compared to pipelined designs. An $N$-point transform requires $O(N \log N)$ clock cycles since the single butterfly unit is time-multiplexed.

Given that this project targets embedded RISC-V processors where silicon area and flexibility are paramount, the memory-based architecture was selected as the optimal topology.

### 3.1.3 Hybrid Architectures
Recent research focuses on hybrid or parallel-memory architectures that use multiple butterfly units (e.g., 2, 4, or 8) connected to partitioned memory banks to strike a balance between the extremes of SDF and single-memory architectures.

<!-- 
[IMAGE PLACEHOLDER: Figure 3.1: Comparison of Pipelined vs. Memory-based FFT Architectures]
Insert a diagram comparing:
- Pipelined SDF: Data flowing left to right through multiple BFU stages separated by delay lines.
- Memory-based: Data circling between a single Central RAM and a single BFU.
-->

## 3.2 Numerical Precision in DSP

The choice of number format drastically affects the size of the multipliers and adders in the butterfly unit.

### 3.2.1 Fixed-Point Arithmetic
Traditionally, embedded FFT hardware relies on fixed-point arithmetic (e.g., 16-bit or 24-bit integers). Fixed-point adders and multipliers are extremely small and fast. However, FFT computation naturally causes data values to grow at each stage. To prevent register overflow, fixed-point designs require implementing a "scaling schedule" (shifting data right by 1 bit at certain stages), which reduces the dynamic range and degrades the Signal-to-Noise Ratio (SNR).

### 3.2.2 Floating-Point Arithmetic
IEEE 754 Single-Precision Floating-Point (FP32) solves dynamic range issues completely, allowing seamless software development. However, an FP32 multiplier is vastly larger than a 16-bit integer multiplier, making it too expensive for deeply embedded cores.

### 3.2.3 Half-Precision Floating-Point (FP16)
The IEEE 754 binary16 format (1 sign bit, 5 exponent bits, 10 mantissa bits) has seen massive adoption recently, driven by AI and machine learning inference. FP16 provides a dynamic range of $\pm 65504$, which is usually sufficient to avoid overflow in moderate-sized FFTs without any scaling schedules. It requires roughly double the area of 16-bit fixed-point, but only a fraction of the area of FP32. Literature shows that FP16 yields acceptable precision for many edge-DSP tasks, making it the ideal target for modern embedded accelerators.

## 3.3 RISC-V Custom Instruction Integration

Historically, accelerators were attached to the CPU via system buses (like ARM AMBA AXI). To use the accelerator, the CPU writes data to memory, configures a DMA controller, sets control registers over a memory-mapped I/O (MMIO) interface, and waits for an interrupt. This setup latency can take hundreds of cycles.

The RISC-V ISA specification explicitly provides four standard custom opcode spaces (`custom-0` through `custom-3`). This allows hardware designers to connect custom functional units directly alongside standard ALUs inside the execution pipeline.

### 3.3.1 Tightly Coupled Accelerators
By defining custom instructions, the CPU can pass data residing in its general-purpose registers (e.g., `rs1`, `rs2`) directly to the accelerator in a single clock cycle. 
Previous works (e.g., Lee et al., and Chen et al.) have demonstrated that tightly coupling DSP and ML accelerators using RISC-V custom instructions yields order-of-magnitude improvements in execution time compared to MMIO/bus-based approaches, largely by eliminating data marshalling and synchronization overhead. 

This project builds upon this paradigm by integrating the memory-based FP16 FFT engine directly into the RISC-V Execute stage, utilizing a pipeline stall mechanism to handle the multi-cycle execution phase.
