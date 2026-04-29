# 6. Conclusion and Future Scope

## 6.1 Conclusion

This major project successfully demonstrates the design, implementation, and integration of a tightly coupled, runtime-configurable Fast Fourier Transform (FFT) hardware accelerator within a RISC-V processor architecture. 

By analyzing the inefficiencies of software-executed DSP algorithms on general-purpose embedded cores, this project identified the critical bottlenecks: instruction fetch overhead, loop management, complex bit-reversal indexing, and floating-point arithmetic delays. To address these, a memory-based FFT engine was developed to support variable transform sizes ($N=2$ to $64$). The adoption of the IEEE 754-like half-precision (FP16) floating-point format proved highly effective, completely eliminating the need for complex fixed-point scaling schedules while avoiding the severe area penalty associated with 32-bit floating-point (FP32) arithmetic.

The most defining innovation of this implementation is the integration methodology. Rather than relegating the hardware to a peripheral system bus (which incurs massive communication latencies), the engine was mapped directly into the RISC-V `custom-0` opcode space. This allowed the CPU to interact with the accelerator natively using four custom assembly instructions: `FFT.SETN`, `FFT.LOAD`, `FFT.EXEC`, and `FFT.READ`. 

The results validate the design methodology emphatically. Functional verification proved the mathematical correctness of the engine, maintaining a relative error of less than 2% for 16-point transforms. Synthesis profiling confirmed the highly constrained area footprint, utilizing only ~27,000 logic cells by multiplexing a single Butterfly Unit. Cycle-accurate benchmarking revealed that the hardware accelerator provides a **10× to 19× performance speedup** compared to a software baseline, whilst reducing the required instruction execution count by a factor of 200×. 

Ultimately, this project highlights the sheer potential of the extensible RISC-V ISA paradigm in edge computing, offering a blueprint for high-performance, low-area domain-specific acceleration.

## 6.2 Future Scope

While the current implementation fulfills all the primary objectives, several avenues for future enhancement exist to elevate the design to commercial-grade standards:

1. **Pipelined Multiple Butterfly Units:**
   The current memory-based architecture uses a single time-multiplexed Butterfly Unit. To increase throughput—especially for larger FFT sizes like $N=64$ where latency spikes—future iterations could instantiate 2 or 4 parallel Butterfly Units, accessing partitioned dual-port memory banks simultaneously.

2. **Larger Transform Sizes and Twiddle Factor Generation:**
   Expanding support for larger transforms (e.g., $N=256$ or $1024$) would make the accelerator viable for higher-end wireless applications like Wi-Fi or LTE. Instead of storing all twiddle factors in a massive ROM, future work could integrate a CORDIC (Coordinate Rotation Digital Computer) algorithm to compute sine and cosine values on the fly, saving silicon area.

3. **Compiler Integration:**
   Presently, the accelerator is controlled via hand-written inline assembly routines. Modifying an open-source compiler toolchain (such as GCC or LLVM) to auto-vectorize standard C-level FFT library calls into our custom RISC-V instructions would massively improve software developer productivity.

4. **ASIC Physical Implementation:**
   Moving beyond generic gate-level synthesis with Yosys, the next logical step involves a full standard-cell ASIC layout utilizing open-source PDKs (e.g., SkyWater 130nm) to generate hard power consumption, thermal density, and critical-path timing metrics.
