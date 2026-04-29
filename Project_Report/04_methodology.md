# 4. Methodology

This section details the theoretical algorithms, the hardware architecture, and the software integration strategy employed to construct the tightly coupled FFT accelerator.

## 4.1 Theoretical Framework: Radix-2 DIT FFT

The Discrete Fourier Transform (DFT) of a sequence $x[n]$ of length $N$ is defined as:
$$X[k] = \sum_{n=0}^{N-1} x[n] W_N^{nk}, \quad k = 0, 1, \dots, N-1$$
where $W_N = e^{-j2\pi/N}$ is the $N$-th root of unity, known as the twiddle factor.

The Cooley-Tukey Radix-2 Decimation-In-Time (DIT) algorithm recursively divides the DFT into smaller DFTs of the even-indexed and odd-indexed time samples. This divide-and-conquer approach reduces the computational complexity from $O(N^2)$ to $O(N \log_2 N)$.

The algorithm comprises $\log_2(N)$ stages. In each stage, the core operation is the "butterfly," which takes two complex inputs ($A$ and $B$) and a twiddle factor ($W_N^k$) to produce two complex outputs ($A'$ and $B'$):
$$A' = A + W_N^k \cdot B$$
$$B' = A - W_N^k \cdot B$$

<!-- 
[IMAGE PLACEHOLDER: Figure 4.2: Radix-2 DIT Butterfly Signal Flow Graph]
Insert a signal flow graph showing inputs A and B, the multiplication of B by twiddle factor W, and the cross-addition/subtraction yielding A' and B'.
-->

To produce outputs in the correct sequential frequency order (natural order), the time-domain input sequence must first be rearranged into "bit-reversed" order. For instance, the sample at index $3$ (binary `011`) in an 8-point FFT must be moved to index $6$ (binary `110`).

## 4.2 FP16 Number Representation

To balance precision and hardware area, the IEEE 754-like half-precision (binary16 or FP16) format is used for all internal datapaths. 

**Table 4.3: FP16 Format Bit Allocation**
| Sign | Exponent | Mantissa (Fraction) |
|:---:|:---:|:---:|
| 1 bit (Bit 15) | 5 bits (Bits 14-10) | 10 bits (Bits 9-0) |

The value is calculated as: $(-1)^{\text{sign}} \times 2^{(\text{exponent} - 15)} \times (1 + \text{fraction}/1024)$. Complex numbers are stored and transmitted as a single packed 32-bit word: `{real_part[15:0], imag_part[15:0]}`.

## 4.3 Hardware Architecture

The FFT hardware accelerator is divided into three primary hierarchical layers: the Accelerator Wrapper, the FFT Engine (FSM Controller), and the Datapath (Butterfly Unit).

### 4.3.1 Accelerator Wrapper
The `fft_accelerator.v` module acts as a lightweight combinational wrapper. It decodes the custom instruction fields (`funct3`, `rs1`, `rs2`) sent by the RISC-V execute stage and maps them to the internal engine's control signals (e.g., sample indices, operation modes). It also routes the engine's `busy` and `done` flags back to the CPU's hazard unit.

<!-- 
[IMAGE PLACEHOLDER: Figure 4.4: FFT Accelerator Wrapper and Pipeline Interface]
Insert a block diagram showing the interface between the RISC-V EX stage pipeline registers, the wrapper, and the FFT Engine.
-->

### 4.3.2 FFT Engine and FSM
The `fft_engine.v` is the core sequential module. It contains:
- **Sample Buffer:** A $64 \times 32$-bit register array that acts as the local working memory for the in-place algorithm.
- **Twiddle ROM:** A 32-entry combinational ROM storing the pre-computed complex twiddle factors for the maximum supported size ($N=64$). Smaller FFT sizes access this ROM using a calculated stride (e.g., stride of $2$ for $N=32$, stride of $4$ for $N=16$).
- **FSM Controller:** A state machine that manages the $\log_2(N)$ stages and the $N/2$ butterflies per stage. 

The FSM transitions through the following states:
1. `S_IDLE`: Awaits instructions. 
2. `S_COMPUTE_INIT`: Resets stage and butterfly counters upon receiving the `EXEC` command.
3. `S_BUTTERFLY_START`: Reads operands $A$ and $B$ from the buffer and sets the twiddle ROM address.
4. `S_BUTTERFLY_WAIT`: Asserts the `start` signal to the Butterfly Unit and waits for its `done` signal.
5. `S_BUTTERFLY_DONE`: Writes the newly computed $A'$ and $B'$ back to the buffer and increments the address counters.
6. `S_FFT_DONE`: Asserts the system-level `done` signal to un-stall the CPU pipeline.

<!-- 
[IMAGE PLACEHOLDER: Figure 4.5: FFT Engine Finite State Machine (FSM) Diagram]
Insert a state transition diagram detailing the states mentioned above.
-->

### 4.3.3 The Butterfly Unit and Datapath
The `butterfly_unit.v` is responsible for executing the arithmetic. It instantiates a `complex_mul_unit` which performs the complex multiplication $W \cdot B$ utilizing four FP16 multipliers (`fp16_mul.v`) and two FP16 adders/subtractors (`fp16_add.v`). The results are then passed to two more FP16 adders to compute the final $A'$ and $B'$ values. 

The FP16 modules were custom-designed to handle exponent alignment, mantissa addition/multiplication, and post-operation normalization.

<!-- 
[IMAGE PLACEHOLDER: Figure 4.6: Butterfly Unit Internal Datapath and Complex Multiplier]
Insert a schematic showing the internal wiring of multipliers and adders inside the Butterfly Unit.
-->

## 4.4 Software Integration and the Custom Instruction Set

A major objective was zero-communication-overhead integration. This was achieved by assigning the accelerator to the RISC-V `custom-0` opcode space (`0x0B`). The CPU interacts with the hardware using four instructions, differentiated by the 3-bit `funct3` field.

**Table 4.1: Custom RISC-V Instruction Encoding for FFT Accelerator**
| Instruction | funct3 | Action | Hardware Latency |
|:---:|:---:|---|:---:|
| `FFT.SETN` | `000` | Set the transform size $N$ (rs1) | 1 cycle |
| `FFT.LOAD` | `001` | Load packed complex sample (rs1) into index (rs2) | 1 cycle |
| `FFT.EXEC` | `010` | Start the FFT computation; stall pipeline until done | $O(N \log N)$ cycles |
| `FFT.READ` | `011` | Read result at index (rs1) into destination register (rd) | 1 cycle |

### 4.4.1 Hardware Bit-Reversal
When software issues an `FFT.LOAD` instruction with a natural sequence index $i$, the hardware dynamically calculates the bit-reversed index based on the configured $N$. 
$$ \text{Stored Address} = \text{BitReverse}(i, \log_2(N)) $$
This operation occurs via combinational logic in a single cycle as the data is written to the buffer, saving the CPU from executing $O(N)$ permutation instructions in software.

**Table 4.2: Hardware Bit-Reversal Permutation Mapping for N=8**
| Natural Index (Binary) | Bit-Reversed Address (Binary) |
|:---:|:---:|
| 0 (`000`) | 0 (`000`) |
| 1 (`001`) | 4 (`100`) |
| 2 (`010`) | 2 (`010`) |
| 3 (`011`) | 6 (`110`) |
| 4 (`100`) | 1 (`001`) |
| 5 (`101`) | 5 (`101`) |
| 6 (`110`) | 3 (`011`) |
| 7 (`111`) | 7 (`111`) |

### 4.4.2 Pipeline Stall Mechanism
The integration strictly avoids altering the processor's critical hazard unit logic. When `FFT.EXEC` is dispatched in the Execute stage, the wrapper asserts a `busy` signal. The hazard unit interprets this as a multi-cycle stall condition (similar to a cache miss or multicycle divider), freezing the Instruction Fetch (IF), Decode (ID), and Execute (EX) stages. Once the FSM reaches `S_FFT_DONE`, it pulses a `done` signal, allowing the CPU pipeline to resume.

<!-- 
[IMAGE PLACEHOLDER: Figure 4.8: Pipeline Timing Diagram demonstrating Stall Mechanism during FFT.EXEC]
Insert a waveform-style timing diagram showing IF, ID, EX, MEM, WB stages stalling while the `busy` signal is high.
-->
