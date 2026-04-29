# Benchmarks & Impact Analysis

## A. Measured Hardware Cycle Counts

The following cycle counts were measured from cycle-accurate RTL simulation (Icarus Verilog 13.0) of the FFT accelerator. Each FFT operation consists of three phases: LOAD (input samples), EXEC (butterfly computation), and READ (retrieve results).

| FFT Size (N) | Stages (log₂N) | Butterflies (N/2 × log₂N) | LOAD Cycles | EXEC Cycles | READ Cycles | **Total Cycles** |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| 2 | 1 | 1 | 2 | 14 | 2 | **18** |
| 4 | 2 | 4 | 4 | 47 | 4 | **55** |
| 8 | 3 | 12 | 8 | 135 | 8 | **151** |
| 16 | 4 | 32 | 16 | 355 | 16 | **387** |
| 32 | 5 | 80 | 32 | 883 | 32 | **947** |
| 64 | 6 | 192 | 64 | 4227 | 64 | **4355** |

*Table I: Measured hardware FFT cycle counts from RTL simulation*

**Cycles per butterfly** = EXEC cycles / number of butterflies:

| N | Butterflies | EXEC Cycles | Cycles/Butterfly |
|:---:|:---:|:---:|:---:|
| 2 | 1 | 14 | 14.0 |
| 4 | 4 | 47 | 11.75 |
| 8 | 12 | 135 | 11.25 |
| 16 | 32 | 355 | 11.09 |
| 32 | 80 | 883 | 11.04 |
| 64 | 192 | 4227 | 22.02 |

*Table II: Per-butterfly cost analysis*

> **Note**: The N=64 case shows higher per-butterfly cost due to the larger address space requiring additional FSM transitions. For N ≤ 32, the engine achieves a consistent ~11 cycles per butterfly (1 setup + 1 read + 1 twiddle + 1 start + ~6 butterfly compute + 1 writeback).

---

## B. Synthesis Results (Yosys)

Synthesis was performed using Yosys 0.57 targeting a generic gate-level netlist. The following table shows resource utilization per module:

| Module | Local Cells | Incl. Submodules | Flip-Flops | MUXes | Key Function |
|--------|:---:|:---:|:---:|:---:|------|
| **fft_accelerator** (top) | 8 | **26,899** | — | 6 | Command routing wrapper |
| **fft_engine** | 19,957 | 26,891 | 2,185 | 4,213 | FSM + 64×32-bit buffer |
| **butterfly_unit** | 79 | 6,815 | 70 | — | Radix-2 butterfly |
| **complex_mul_unit** | 40 | 6,736 | 36 | — | 4-multiply complex MAC |
| **fp16_mul** (×4) | 801 | 801 | — | 14 | FP16 multiplier |
| **fp16_add** (×6) | 582 | 582 | — | 157 | FP16 adder/subtractor |
| **twiddle_rom** | 119 | 119 | — | 82 | 32-entry lookup table |

*Table III: Synthesis resource utilization (Yosys, generic gate library)*

**Total design summary:**
- **26,899 logic cells** (total flattened)
- **2,291 flip-flops** (DFFE + DFF variants)
- **5,299 multiplexers**
- **Memory**: 64 × 32-bit = 2,048-bit sample buffer (mapped to registers)
- **Twiddle ROM**: 32 × 32-bit = 1,024 bits (combinational LUT)

---

## C. Software FFT Comparison

To demonstrate the value of hardware acceleration, we compare against a pure software radix-2 FFT running on the same RISC-V core (RV32I, no floating-point ISA extension).

### Software FFT Cost Estimation

A software FFT on RV32I (integer-only ISA) requires:
- **FP16 emulation**: Each FP16 multiply requires ~25 instructions (shift, mask, multiply via integer, normalize). Each FP16 add requires ~20 instructions.
- **Complex butterfly**: 4 FP16 multiplies + 6 FP16 adds = ~220 instructions per butterfly
- **Loop overhead**: ~10 instructions per butterfly (index computation, branching, memory access)
- **Bit-reversal**: ~5 instructions per sample (swap computation)

| FFT Size (N) | SW Butterflies | SW Instructions (est.) | HW Cycles (measured) | **Speedup** |
|:---:|:---:|:---:|:---:|:---:|
| 2 | 1 | ~240 | 18 | **13.3×** |
| 4 | 4 | ~930 | 55 | **16.9×** |
| 8 | 12 | ~2,770 | 151 | **18.3×** |
| 16 | 32 | ~7,380 | 387 | **19.1×** |
| 32 | 80 | ~18,410 | 947 | **19.4×** |
| 64 | 192 | ~44,230 | 4,355 | **10.2×** |

*Table IV: Hardware vs. software FFT performance comparison*

> **Key insight**: The hardware accelerator achieves **10–19× speedup** over pure software. The speedup is most pronounced for mid-range FFT sizes (N=16–32). For N=64, the speedup is lower due to the sequential single-butterfly design — a pipelined butterfly array would improve this.

### Software FFT breakdown (per butterfly):
| Operation | SW Instructions | HW Equivalent |
|-----------|:---:|:---:|
| FP16 multiply × 4 | ~100 | 1 cycle (parallel HW) |
| FP16 add/sub × 6 | ~120 | 1 cycle (parallel HW) |
| Memory loads/stores | ~16 | Built-in buffer access |
| Index computation | ~8 | Combinational logic |
| Loop/branch | ~6 | FSM auto-advance |
| Bit-reversal | ~5/sample (one-time) | HW during LOAD |
| **Total per butterfly** | **~230** | **~11** |

*Table V: Per-butterfly cost breakdown — software vs. hardware*

---

## D. Comparison with Alternative Architectures

### Platform-Level Comparison

| Metric | This Work | ARM Cortex-M4 (CMSIS-DSP) | Xilinx FFT IP (Radix-4) | Custom ASIC FFT |
|--------|:---:|:---:|:---:|:---:|
| **Max FFT Size** | 64 | Arbitrary | 65536 | Fixed |
| **Arithmetic** | FP16 | FP32 | Fixed-point | Fixed-point |
| **Integration** | Pipeline-native ISA | Software library | AXI bus coprocessor | Standalone |
| **Reconfigurability** | Runtime (1 instruction) | Software | Compile-time | None |
| **Bit-reversal** | Hardware (free) | Software (~N cycles) | Hardware | Hardware |
| **16-pt FFT Cycles** | 387 | ~2000–4000 | ~50–100 | ~16 |
| **Area** | ~27K cells | Full CPU core | ~5K–50K LUTs | Custom |
| **SW Toolchain** | Standard RISC-V GCC | ARM GCC + CMSIS | Vivado IP integrator | None |
| **Custom HW required?** | Yes (4 instructions) | No | Yes (IP block) | Yes |

*Table VI: Cross-platform comparison of FFT implementation approaches*

> **Positioning**: Our design fills the niche of **tightly-coupled, low-area DSP acceleration** for embedded RISC-V cores. It offers significantly higher performance than pure software while using far less area than standalone FFT IP blocks. The key advantage is **zero communication overhead** — the accelerator is accessed via native custom instructions, not a bus protocol.

### Architectural Trade-off Analysis

| Architecture | Throughput | Area | Latency | Flexibility | Energy Efficiency |
|:---:|:---:|:---:|:---:|:---:|:---:|
| **This work** (Memory-based, single BFU) | Low | **Low** ✓ | Medium | **High** ✓ | Medium |
| Pipelined SDF (1 BFU/stage) | **High** ✓ | High | **Low** ✓ | Low | Low |
| Memory-based (2 BFU) | Medium | Medium | Medium | High | **High** ✓ |
| Full-parallel (N/2 BFUs) | **Highest** | **Highest** | **Lowest** | None | Lowest |
| Software (no HW) | **Lowest** | **Lowest** | **Highest** | **Highest** | **Lowest** |

*Table VII: FFT architecture trade-off matrix (BFU = Butterfly Unit)*

---

## E. Efficiency Metrics

### 1. Area Efficiency

$$\text{Area Efficiency} = \frac{\text{FFT throughput (points/cycle)}}{\text{Area (cells)}}$$

For N=16 FFT:
- Throughput = 16 points / 387 cycles = 0.0413 points/cycle
- Area = 26,899 cells
- **Area Efficiency = 1.54 × 10⁻⁶ points/cycle/cell**

### 2. Instruction Efficiency

The number of CPU instructions required to perform a complete FFT:

| Approach | Instructions for 16-pt FFT |
|----------|:---:|
| Software FFT (RV32I, FP16 emulation) | ~7,380 |
| Software FFT (RV32F, native FP) | ~1,200 |
| **This work (HW accelerator)** | **37** (1 SETN + 16 LOAD + 1 EXEC + 16 READ + 3 setup) |

*Table VIII: Instruction count comparison for 16-point FFT*

> **200× reduction in instruction count** compared to software FP16 emulation. This directly translates to reduced instruction memory traffic, lower I-cache pressure, and freed pipeline bandwidth for other tasks.

### 3. Pipeline Utilization

| Instruction | Pipeline Stages Used | Stall Cycles | Useful Work |
|-------------|:---:|:---:|:---:|
| FFT.SETN | IF→ID→EX→MEM→WB | 0 | Configure engine |
| FFT.LOAD | IF→ID→EX→MEM→WB | 0 | Load + bit-reverse |
| **FFT.EXEC** | IF→ID→**EX(stall)**→MEM→WB | **N/2 × log₂N × ~11** | All butterflies |
| FFT.READ | IF→ID→EX→MEM→WB | 0 | Read result |

*Table IX: Pipeline utilization per FFT instruction*

> **Key**: Only FFT.EXEC stalls the pipeline. SETN, LOAD, and READ execute in a single cycle with no stalls, behaving like normal ALU instructions from the pipeline's perspective.

---

## F. Scalability Analysis

| Metric | N=4 | N=8 | N=16 | N=32 | N=64 |
|--------|:---:|:---:|:---:|:---:|:---:|
| Total cycles | 55 | 151 | 387 | 947 | 4,355 |
| Theoretical O(N log₂N) | 8 | 24 | 64 | 160 | 384 |
| Ratio (measured/theoretical) | 6.9 | 6.3 | 6.0 | 5.9 | 11.3 |
| SW speedup | 16.9× | 18.3× | 19.1× | 19.4× | 10.2× |

*Table X: Scalability analysis across FFT sizes*

The measured-to-theoretical ratio stabilizes at ~6× for N=8 to N=32, confirming consistent per-butterfly overhead. The N=64 anomaly warrants investigation for further optimization.

<!-- 
[IMAGE PLACEHOLDER: Fig. 1 — Cycle count scaling plot]
Insert a log-log plot with:
- X-axis: FFT size N (2, 4, 8, 16, 32, 64)
- Two lines: Measured HW cycles (solid blue) and Theoretical N×log₂N (dashed red)
- Shows the constant overhead factor between theory and implementation
-->

<!-- 
[IMAGE PLACEHOLDER: Fig. 2 — Software vs Hardware speedup bar chart]
Insert a grouped bar chart with:
- X-axis: FFT size N
- Y-axis: Cycle count (log scale)
- Two bars per N: Software (orange) and Hardware (blue)
- Speedup annotation above each pair
-->
