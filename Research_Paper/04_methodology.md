# III. Methodology

## A. Algorithm Selection

The Cooley-Tukey Decimation-In-Time (DIT) radix-2 algorithm is selected for hardware implementation due to its regular butterfly structure, in-place computation capability, and well-understood dataflow patterns [1].

For an N-point DFT defined as:

$$X[k] = \sum_{n=0}^{N-1} x[n] \cdot W_N^{nk}, \quad k = 0, 1, \ldots, N-1$$

where $W_N = e^{-j2\pi/N}$ is the N-th root of unity (twiddle factor), the radix-2 DIT algorithm decomposes the computation into log₂(N) stages, each containing N/2 butterfly operations.

Each butterfly computes:

$$A' = A + W_N^k \cdot B$$
$$B' = A - W_N^k \cdot B$$

<!-- 
[IMAGE PLACEHOLDER: Fig. 1 — Butterfly operation diagram]
Insert a diagram showing a single radix-2 butterfly operation with inputs A, B, 
twiddle factor W, and outputs A' = A + W*B, B' = A - W*B.
Show the data flow with arrows indicating complex multiply and add/subtract.
-->

The DIT algorithm requires the input sequence to be in **bit-reversed order** before processing. Our design performs this permutation in hardware during the data loading phase, as described in Section IV.

## B. Data Representation: FP16

All arithmetic operations use the IEEE 754 binary16 (half-precision) format:

| Field | Bits | Range |
|-------|------|-------|
| Sign | 1 | ± |
| Exponent | 5 | Biased by 15 |
| Mantissa | 10 | 1.0 to ~2.0 (implicit leading 1) |

This provides:
- **Dynamic range**: ±65504
- **Precision**: ~3.3 decimal digits (0.1% relative precision)
- **Special values**: ±0, ±∞, NaN, denormals

Complex numbers are represented as a packed 32-bit word: `{real[15:0], imag[15:0]}`, enabling efficient register transfer between the processor and accelerator using standard 32-bit data paths.

## C. Twiddle Factor Computation and Storage

The twiddle factors $W_{64}^k = \cos(-2\pi k/64) + j\sin(-2\pi k/64)$ for $k = 0, 1, \ldots, 31$ are pre-computed offline using double-precision arithmetic and quantized to FP16 during synthesis. These 32 entries are stored in a combinational ROM within the accelerator.

For an N-point FFT (N ≤ 64), the required twiddle factor at stage $s$ with offset $m$ is:

$$W_N^m = W_{64}^{m \cdot (64/N)}$$

This is implemented as a stride-based index: `rom_index = m × (64/N)`, allowing all FFT sizes to share the same 32-entry ROM.

<!-- 
[IMAGE PLACEHOLDER: Fig. 2 — Twiddle factor ROM sharing across FFT sizes]
Insert a diagram showing how the 32-entry W_64 ROM is indexed for different FFT sizes:
- N=4: stride=16, accessing entries {0, 16}
- N=8: stride=8, accessing entries {0, 8, 16, 24}
- N=16: stride=4, accessing entries {0, 4, 8, 12, 16, 20, 24, 28}
- N=64: stride=1, accessing all 32 entries
-->

## D. Pipeline Integration Strategy

The FFT accelerator is integrated into the execute stage of the 5-stage RISC-V pipeline using a **stall-based** synchronization mechanism:

1. **Instruction Decode**: The decode stage recognizes the custom opcode (0x0B) and asserts an `is_custom` flag, routing operands to the accelerator instead of the ALU.

2. **Command Dispatch**: The `funct3` field of the instruction selects one of four operations:

| funct3 | Instruction | Operation | Latency |
|--------|------------|-----------|---------|
| 000 | `FFT.SETN` | Set FFT size | 1 cycle |
| 001 | `FFT.LOAD` | Load sample | 1 cycle |
| 010 | `FFT.EXEC` | Execute FFT | O(N log₂N) cycles |
| 011 | `FFT.READ` | Read result | 1 cycle |

3. **Stall Mechanism**: When `FFT.EXEC` is issued, the accelerator asserts a `busy` signal. The hazard unit freezes the entire pipeline (IF, ID, EX stages) until the engine signals completion via a `done` pulse. This approach:
   - Requires **zero modifications** to the existing forwarding and hazard detection logic
   - Guarantees **no data hazards** during multi-cycle FFT execution
   - Preserves pipeline correctness for all base ISA instructions

<!-- 
[IMAGE PLACEHOLDER: Fig. 3 — Pipeline integration timing diagram]
Insert a timing diagram showing the pipeline stages (IF, ID, EX, MEM, WB) during:
1. FFT.SETN instruction (1-cycle execute)
2. FFT.LOAD instruction (1-cycle execute)  
3. FFT.EXEC instruction (multi-cycle stall, pipeline frozen)
4. FFT.READ instruction (1-cycle execute, result to WB)
Show the stall signals and pipeline freeze during FFT.EXEC.
-->

## E. Hardware Bit-Reversal

The DIT FFT algorithm produces outputs in natural order only when inputs are provided in bit-reversed order. Conventionally, this reordering is performed in software, requiring O(N) additional instructions.

Our design performs bit-reversal **in hardware** during the `FFT.LOAD` command. When sample $x[i]$ is loaded at index $i$, the engine stores it at address `bit_reverse(i, log₂N)` in the internal buffer. This is implemented using a combinational logic function that reverses the lower log₂(N) bits of the address:

For example, with N=8 (3-bit reversal):
| Input Index (binary) | Bit-Reversed (binary) | Stored Address |
|----------------------|----------------------|----------------|
| 0 (000) | 0 (000) | 0 |
| 1 (001) | 4 (100) | 4 |
| 2 (010) | 2 (010) | 2 |
| 3 (011) | 6 (110) | 6 |
| 4 (100) | 1 (001) | 1 |
| 5 (101) | 5 (101) | 5 |
| 6 (110) | 3 (011) | 3 |
| 7 (111) | 7 (111) | 7 |

*Table II: Bit-reversal permutation for N=8*

## F. Verification Methodology

The design is verified at three levels:

1. **Standalone Simulation**: The FFT engine is tested in isolation with known input vectors (4-point and 8-point FFTs), comparing hardware outputs against numpy FFT reference values with ±1 LSB tolerance per FP16 half-word.

2. **Integration Simulation**: The full RISC-V processor executes hand-assembled firmware containing the FFT instruction sequence, verifying correct pipeline integration, stall behavior, and register writeback.

3. **Automated Demo**: A Python script (`demo_fft.py`) accepts arbitrary input vectors, auto-generates a Verilog testbench, runs hardware simulation, and produces a side-by-side comparison with numpy reference results.
