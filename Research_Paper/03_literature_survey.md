# II. Literature Survey

## A. FFT Hardware Architectures

Hardware FFT implementations have been extensively studied and can be broadly classified into three categories: pipelined, memory-based, and hybrid architectures.

**Pipelined FFT architectures**, such as the Single-path Delay Feedback (SDF) and Multi-path Delay Commutator (MDC), dedicate a butterfly processing element to each FFT stage. While these achieve high throughput with one output per clock cycle, they require N/2 × log₂(N) butterfly units, leading to significant area overhead for larger FFT sizes [6]. He and Torkelson [7] proposed the R2²SDF architecture which reduces hardware complexity by 50% compared to R2SDF while maintaining single-path throughput.

**Memory-based architectures** use a single butterfly unit shared across all stages, reading operands from and writing results to an internal memory buffer. Bi and Jones [8] demonstrated that memory-based designs achieve the best area efficiency at the cost of higher latency (O(N log₂N) cycles). This approach is particularly suited for embedded systems where area is constrained.

**Hybrid architectures** combine elements of both approaches. Garrido et al. [9] proposed feedback architectures that achieve configurable FFT sizes while maintaining reasonable throughput-area tradeoffs.

Our work adopts the memory-based approach with a single time-multiplexed butterfly unit, optimizing for area efficiency in an embedded RISC-V context.

## B. Floating-Point Precision in FFT

Traditional FFT hardware implementations use fixed-point arithmetic for area and power efficiency. However, fixed-point designs require careful wordlength optimization to prevent overflow and maintain signal-to-noise ratio (SNR), which is input-dependent [10].

Half-precision floating-point (FP16) has gained prominence with the rise of neural network inference accelerators. Micikevicius et al. [11] demonstrated that FP16 provides sufficient precision for a wide range of deep learning and DSP workloads. The IEEE 754-2008 standard defines the binary16 format with 1 sign bit, 5 exponent bits, and 10 mantissa bits, providing a dynamic range of ±65504 with approximately 3 decimal digits of precision [12].

For FFT applications, FP16 eliminates the need for scaling schedules required by fixed-point implementations, at the cost of approximately 2× area overhead compared to equivalent fixed-point datapaths [13].

## C. RISC-V Custom Instruction Extensions

The RISC-V ISA reserves four custom opcode spaces (custom-0 through custom-3) for user-defined extensions, enabling domain-specific acceleration without modifying the base ISA [4].

Several works have explored custom instruction integration for DSP acceleration. Lee et al. [14] implemented a tightly-coupled neural network accelerator using RISC-V custom instructions, demonstrating 10× speedup over software execution. Chen et al. [15] proposed a configurable FFT accelerator as a RISC-V coprocessor using the RoCC (Rocket Custom Coprocessor) interface, achieving high throughput but with multi-cycle communication overhead.

In contrast, our approach integrates the FFT engine directly into the execute stage of the processor pipeline, using the custom-0 opcode space. This eliminates coprocessor communication latency and leverages the existing pipeline stall mechanism for synchronization.

## D. Comparison with Existing Approaches

| Feature | [8] Bi & Jones | [7] He & Torkelson (R2²SDF) | [15] Chen et al. | **This Work** |
|---------|:---:|:---:|:---:|:---:|
| FFT Size | Fixed N | Fixed N | Fixed N | **N=2 to 64 (runtime)** |
| Architecture | Memory-based | Pipelined SDF | Pipelined | Memory-based |
| Arithmetic | Fixed-point | Fixed-point | FP32 | **FP16** |
| Integration | Standalone | Standalone | RoCC Coprocessor | **Pipeline-native ISA** |
| Bit-reversal | Software | External | Software | **Hardware (zero-cost)** |
| Custom ISA | None | None | RoCC protocol | **4 custom instructions** |
| Comm. overhead | Bus interface | Bus interface | Multi-cycle RoCC | **Zero (native pipeline)** |
| Butterfly units | 1 (shared) | log₂N (dedicated) | N/2 (parallel) | 1 (shared) |
| Area | Low | High | High | **Low (~27K cells)** |
| 16-pt FFT latency | — | ~16 cycles | — | **387 cycles** |

*Table I: Comparison of FFT accelerator approaches*

The key differentiator of our design is the combination of runtime-configurable FFT size, FP16 precision, and zero-overhead pipeline integration through native custom instructions. While pipelined architectures [7] achieve lower latency, they require dedicated butterfly hardware per FFT stage and cannot easily support variable FFT sizes. Our memory-based approach trades latency for **area efficiency** and **runtime flexibility**, achieving a **10–19× speedup** over equivalent software execution on the same core (measured via RTL simulation) while using only a single butterfly unit.
