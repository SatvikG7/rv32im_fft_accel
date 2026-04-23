# FFT Accelerator

To highly optimize Digital Signal Processing workloads, this RISC-V project incorporates an integrated Floating-Point 16 (FP16) Fast Fourier Transform (FFT) Accelerator supporting **modular N-point FFTs** (N = 2, 4, 8, 16, 32, 64).

## Overview

The FFT accelerator is a hardware FSM-based engine that autonomously computes the full radix-2 Decimation-In-Time (DIT) FFT. It interfaces with the processor via four custom instructions, allowing the CPU to load samples, trigger computation, and read results — all through the existing custom opcode (`0x0B`) mechanism.

### Architecture

```
┌─────────────────────────────────────────────────┐
│               fft_accelerator.v                 │
│          (thin wrapper / signal router)         │
│                                                 │
│  ┌───────────────────────────────────────────┐  │
│  │              fft_engine.v                 │  │
│  │                                           │  │
│  │  ┌──────────┐   ┌──────────────┐         │  │
│  │  │ Internal  │   │ Twiddle ROM  │         │  │
│  │  │ Buffer    │   │ (32 entries) │         │  │
│  │  │ 64×32bit  │   └──────┬───────┘         │  │
│  │  └────┬──────┘          │                 │  │
│  │       │          ┌──────┴───────┐         │  │
│  │       └─────────►│ Butterfly    │         │  │
│  │                  │ Unit         │         │  │
│  │       ┌─────────┤ (reused per  │         │  │
│  │       │         │  butterfly)  │         │  │
│  │  ┌────▼──────┐  └──────────────┘         │  │
│  │  │ Results   │                            │  │
│  │  │ (in-place)│                            │  │
│  │  └───────────┘                            │  │
│  │                                           │  │
│  │  FSM: IDLE → COMPUTE → DONE              │  │
│  └───────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
```

### Custom Instructions

All FFT instructions use the **custom-0 opcode** (`0x0B`). The `funct3` field selects the operation:

| funct3 | Mnemonic   | Operands       | Description                                      |
|--------|------------|----------------|--------------------------------------------------|
| `000`  | `FFT.SETN` | `rd, rs1`      | Set FFT size: `engine.N = rs1[6:0]`             |
| `001`  | `FFT.LOAD` | `rd, rs1, rs2` | Load sample: `buf[bit_rev(rs2)] = rs1`           |
| `010`  | `FFT.EXEC` | `rd`           | Start FFT. Stalls pipeline until complete.       |
| `011`  | `FFT.READ` | `rd, rs1`      | Read result: `rd = buf[rs1[5:0]]`                |

### Sub-Modules

1. **FFT Engine (`fft_engine.v`)**: Core FSM module. Contains the internal 64×32-bit sample buffer, computation counters, and bit-reversal logic. Orchestrates the full Cooley-Tukey radix-2 DIT algorithm by iterating through `log₂(N)` stages, each with `N/2` butterfly operations.

2. **Butterfly Unit (`butterfly_unit.v`)**: Computes a single radix-2 butterfly: `out1 = A + W*B`, `out2 = A - W*B`. Time-multiplexed — the same unit is reused for every butterfly in the FFT.

3. **Complex Multiplier (`complex_mul_unit.v`)**: Computes `(a + bi) * (c + di) = (ac - bd) + (ad + bc)i` using FP16 arithmetic. Used internally by the butterfly unit.

4. **FP16 Arithmetic (`fp16_add.v`, `fp16_mul.v`)**: IEEE 754-like half-precision floating-point add/subtract and multiply units.

5. **Twiddle ROM (`twiddle_rom.v`)**: 32-entry combinational ROM containing pre-computed twiddle factors `W_64^k` for `k = 0..31`. Smaller FFT sizes use a subset with stride `64/N`.

### Hardware Bit-Reversal

The engine performs bit-reversal permutation **in hardware** during the LOAD phase. When a sample is loaded at index `i`, it is stored at the bit-reversed address of `i` (using `log₂(N)` bits). This eliminates the need for software bit-reversal and ensures the DIT algorithm produces outputs in natural order.

### Performance

Cycle counts per FFT size (approximate):

| N   | Stages | Butterflies | Compute Cycles | Total (load+compute+read) |
|-----|--------|-------------|----------------|---------------------------|
| 2   | 1      | 1           | ~6             | ~10                       |
| 4   | 2      | 4           | ~24            | ~32                       |
| 8   | 3      | 12          | ~72            | ~88                       |
| 16  | 4      | 32          | ~192           | ~224                      |
| 32  | 5      | 80          | ~480           | ~544                      |
| 64  | 6      | 192         | ~1152          | ~1280                     |

## Instruction Integration

The custom instruction flow integrates with the processor pipeline:

1. **Decode Stage**: Opcode `0x0B` is detected, `is_custom` signal asserted.
2. **Execute Stage**: Routes `rs1`/`rs2` operands and `funct3` to the accelerator.
3. **Hazard Unit**: Stalls the entire pipeline (`stall_if`, `stall_id`, `stall_ex`) while `fft_busy` is high. This guarantees zero data hazards.
4. **Writeback**: The accelerator result (from `FFT.READ`) is written back to the destination register via the standard pipeline path.

### Usage Example (Assembly)

```asm
# 4-point FFT of [1.0, 2.0, 3.0, 4.0]
    li x1, 4
    fft_setn x0, x1           # Set N=4

    li x10, 0x3C000000        # 1.0 + 0j (packed FP16)
    li x2, 0
    fft_load x0, x10, x2      # Load x[0]

    li x10, 0x40000000        # 2.0 + 0j
    li x2, 1
    fft_load x0, x10, x2      # Load x[1]

    li x10, 0x42000000        # 3.0 + 0j
    li x2, 2
    fft_load x0, x10, x2      # Load x[2]

    li x10, 0x44000000        # 4.0 + 0j
    li x2, 3
    fft_load x0, x10, x2      # Load x[3]

    fft_exec x0               # Execute FFT (stalls until done)

    li x2, 0
    fft_read x20, x2          # Read X[0]
    li x2, 1
    fft_read x21, x2          # Read X[1]
    li x2, 2
    fft_read x22, x2          # Read X[2]
    li x2, 3
    fft_read x23, x2          # Read X[3]
```
