# IV. Architecture

## A. System Overview

The complete system consists of a 5-stage pipelined RISC-V processor (RV32I base) with an integrated FFT accelerator. The processor implements the standard pipeline stages: Instruction Fetch (IF), Instruction Decode (ID), Execute (EX), Memory Access (MEM), and Write-Back (WB).

<!-- 
[IMAGE PLACEHOLDER: Fig. 4 — System-level block diagram]
Insert a high-level block diagram showing:
- RISC-V Core (5-stage pipeline)
  - IF Stage → Instruction Memory
  - ID Stage → Register File
  - EX Stage → ALU + FFT Accelerator (highlighted)
  - MEM Stage → Data Memory
  - WB Stage → Register File writeback
- Hazard Unit (with stall signals)
- Show the FFT Accelerator integrated at the EX stage with custom opcode routing
-->

## B. FFT Accelerator Top Module

The FFT accelerator (`fft_accelerator.v`) serves as a lightweight interface wrapper between the processor pipeline and the FFT computation engine. It performs three functions:

1. **Signal routing**: Maps processor operands (`rs1`, `rs2`) to engine command signals based on the instruction type.
2. **Index selection**: Routes the sample index from `rs2` (for LOAD) or `rs1` (for READ) to the engine.
3. **Result forwarding**: Passes the engine's `data_out`, `done`, and `busy` signals back to the execute stage.

The wrapper contains no sequential logic — it is purely combinational, adding zero latency to the command path.

<!-- 
[IMAGE PLACEHOLDER: Fig. 5 — FFT Accelerator wrapper block diagram]
Insert a block diagram showing:
- Inputs: start, operand_a (rs1), operand_b (rs2), operation (funct3)
- Signal routing logic (muxes for index and data_in)
- FFT Engine instance
- Outputs: result, done, busy
-->

## C. FFT Engine

The FFT engine (`fft_engine.v`) is the core computational module, implementing a finite state machine (FSM) that orchestrates the entire radix-2 DIT FFT computation. Its internal components are:

### 1) Sample Buffer
A 64×32-bit register array stores complex samples in packed FP16 format. The buffer supports dual-port access for simultaneous reading of butterfly operand pairs during computation.

### 2) FSM Controller
The engine FSM has six states:

<!-- 
[IMAGE PLACEHOLDER: Fig. 6 — FFT Engine FSM state diagram]
Insert a state transition diagram showing:
- S_IDLE: Accepts commands (SETN, LOAD, READ → done in 1 cycle; EXEC → transition)
- S_COMPUTE_INIT: Initialize stage and butterfly counters
- S_BUTTERFLY_START: Read operands from buffer, set twiddle address
- S_BUTTERFLY_WAIT: Pulse butterfly start, wait for completion
- S_BUTTERFLY_DONE: Write results back, advance counters (→ next butterfly or next stage)
- S_FFT_DONE: Signal completion, return to IDLE
Show transitions with labels (conditions).
-->

| State | Description | Next State |
|-------|-------------|------------|
| `S_IDLE` | Accept commands | `S_COMPUTE_INIT` (on EXEC) |
| `S_COMPUTE_INIT` | Reset stage/butterfly counters | `S_BUTTERFLY_START` |
| `S_BUTTERFLY_START` | Read operands, set twiddle addr | `S_BUTTERFLY_WAIT` |
| `S_BUTTERFLY_WAIT` | Start butterfly, await completion | `S_BUTTERFLY_DONE` |
| `S_BUTTERFLY_DONE` | Write results, advance counters | `S_BUTTERFLY_START` or `S_FFT_DONE` |
| `S_FFT_DONE` | De-assert busy, pulse done | `S_IDLE` |

*Table III: FFT Engine FSM states*

### 3) Butterfly Address Generator

The address generator computes butterfly operand pair indices using the Cooley-Tukey DIT addressing pattern. For stage $s$ and butterfly index $b$:

$$\text{half\_block} = 2^s$$
$$\text{block\_num} = \lfloor b / \text{half\_block} \rfloor$$
$$\text{offset} = b \mod \text{half\_block}$$
$$p = \text{block\_num} \times 2^{s+1} + \text{offset}$$
$$q = p + \text{half\_block}$$

The twiddle factor index is computed as:
$$\text{tw\_index} = \text{offset} \times \lfloor 64 / 2^{s+1} \rfloor = \text{offset} \ll (5 - s)$$

This mapping is implemented using a case statement on the stage counter, avoiding runtime multiplication.

<!-- 
[IMAGE PLACEHOLDER: Fig. 7 — 8-point FFT butterfly dataflow diagram]
Insert a signal flow graph (butterfly diagram) for an 8-point DIT FFT showing:
- 3 stages (stage 0, 1, 2)
- Bit-reversed input order on the left
- Natural output order on the right
- Twiddle factors labeled on each butterfly
- Highlight the butterfly pairs computed at each stage
This is the classic "FFT butterfly diagram" with W_8^k labels.
-->

## D. Butterfly Unit

The butterfly unit (`butterfly_unit.v`) computes a single radix-2 butterfly operation:

$$\text{out}_1 = A + W \cdot B$$
$$\text{out}_2 = A - W \cdot B$$

The complex multiplication $W \cdot B$ is delegated to a sub-module (`complex_mul_unit.v`), which computes:

$$(W_r + jW_i)(B_r + jB_i) = (W_rB_r - W_iB_i) + j(W_rB_i + W_iB_r)$$

using four FP16 multiplications and two FP16 additions. The butterfly unit then adds/subtracts this product from $A$ using two additional FP16 add/subtract operations.

<!-- 
[IMAGE PLACEHOLDER: Fig. 8 — Butterfly unit internal datapath]
Insert a datapath diagram showing:
- Inputs: A_real, A_imag, B_real, B_imag, W_real, W_imag
- Complex Multiplier: 4× fp16_mul + 2× fp16_add → WB_real, WB_imag
- Adder: A + WB → out1
- Subtractor: A - WB → out2
- Outputs: out1_real, out1_imag, out2_real, out2_imag
- Pipeline stages and timing annotations
-->

## E. FP16 Arithmetic Units

### 1) FP16 Multiplier (`fp16_mul.v`)
Implements IEEE 754-like half-precision multiplication:
- Exponent addition with bias correction
- 11×11 mantissa multiplication (including implicit leading 1)
- Normalization and rounding

### 2) FP16 Adder/Subtractor (`fp16_add.v`)
Implements half-precision addition and subtraction:
- Exponent alignment (right-shift smaller operand)
- Mantissa addition/subtraction
- Normalization and rounding
- Special case handling (zero, infinity)

## F. Twiddle Factor ROM

The twiddle ROM (`twiddle_rom.v`) stores 32 pre-computed complex twiddle factors $W_{64}^k$ for $k = 0, \ldots, 31$ as packed 32-bit values. The ROM is implemented as a combinational lookup table (no clock required), providing zero-latency access during butterfly computation.

<!-- 
[IMAGE PLACEHOLDER: Fig. 9 — Complete FFT Engine internal architecture]
Insert a comprehensive block diagram showing the internal architecture of fft_engine.v:
- Sample Buffer (64×32-bit)
- FSM Controller
- Address Generator (butterfly index → p, q, tw_index)
- Twiddle ROM (32 entries)
- Butterfly Unit (with complex multiplier and FP16 add/sub)
- Muxes and data paths connecting all components
- Control signals (start, done, busy)
This should be the most detailed diagram in the paper.
-->

## G. Module Hierarchy

The complete module hierarchy is:

```
riscv_core
├── fetch_stage
│   └── instruction_memory
├── decode_stage
│   └── register_file
├── execute_stage
│   ├── alu
│   └── fft_accelerator          ← Custom extension
│       └── fft_engine
│           ├── butterfly_unit
│           │   └── complex_mul_unit
│           │       ├── fp16_mul (×4)
│           │       └── fp16_add (×2)
│           └── twiddle_rom
├── memory_stage
│   └── data_memory
├── writeback_stage
└── hazard_unit
```

*Fig. 10: Module hierarchy*
