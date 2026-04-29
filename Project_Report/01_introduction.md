# 1. Introduction

## 1.1 Background and Motivation
The Fast Fourier Transform (FFT) is an algorithm that computes the Discrete Fourier Transform (DFT) of a sequence, or its inverse, drastically reducing the computational complexity from $O(N^2)$ to $O(N \log N)$. Since its popularization by Cooley and Tukey in 1965, the FFT has become indispensable in modern engineering. It is the mathematical backbone of diverse applications, including OFDM-based wireless communications (such as 4G, 5G, and Wi-Fi), radar signal processing, audio and speech processing, biomedical signal analysis (like EEG/ECG), and more recently, certain types of machine learning algorithms.

In the realm of embedded systems, Internet of Things (IoT) edge devices, and microcontrollers, there is a growing demand to process signals locally to reduce transmission bandwidth and preserve privacy. However, computing the FFT in software on a general-purpose processor is resource-intensive. It requires extensive loop management, complex memory addressing (such as bit-reversal), and heavy floating-point arithmetic. For real-time applications with strict latency and power budgets, software-only approaches are often insufficient.

Historically, hardware acceleration for FFT has been achieved using discrete Digital Signal Processors (DSPs), Field Programmable Gate Arrays (FPGAs), or dedicated Application-Specific Integrated Circuits (ASICs). While effective, attaching these as external coprocessors introduces significant communication overhead over system buses (like AXI or AHB). The processor must spend cycles marshalling data, configuring DMA controllers, and waiting for interrupts, which can negate the performance benefits of the accelerator for smaller, frequently executed transforms.

## 1.2 The RISC-V Paradigm
The RISC-V Instruction Set Architecture (ISA) offers a compelling solution to the coprocessor communication bottleneck. Unlike proprietary ISAs, RISC-V is open, modular, and explicitly designed for extensibility. The ISA reserves specific opcode spaces specifically for custom, user-defined instructions. 

By designing a custom hardware accelerator and tightly coupling it within the processor's own execution pipeline, software can interact with the accelerator using native assembly instructions. This paradigm shift means the accelerator effectively becomes a specialized functional unit—much like an ALU—capable of accessing processor registers directly with zero bus-related latency.

## 1.3 Precision in Hardware DSP
Another critical aspect of hardware DSP design is the choice of numerical representation. Fixed-point arithmetic is traditional in hardware due to its low area and power requirements. However, fixed-point FFTs require complex scaling schedules to prevent overflow at each butterfly stage, and their Signal-to-Noise Ratio (SNR) degrades depending on the input data dynamic range.

Conversely, standard IEEE 754 single-precision (FP32) floating-point arithmetic offers vast dynamic range and ease of software development but incurs massive area and power penalties, often making it prohibitive for resource-constrained embedded cores. 

Recently, half-precision floating-point (FP16) has emerged as a standard, heavily driven by neural network accelerators. FP16 provides a dynamic range far exceeding 16-bit fixed-point formats, largely eliminating the need for scaling schedules, while requiring significantly less silicon area than FP32. Applying FP16 to embedded FFT acceleration represents a modern trade-off, balancing numerical stability with hardware efficiency.

## 1.4 Problem Statement
The objective of this major project is to address the inefficiencies of software-based FFT execution on embedded processors by designing a tightly coupled hardware accelerator. The design must overcome the latency of bus-based coprocessors, minimize the silicon area footprint to remain viable for embedded systems, support runtime-configurable transform sizes to adapt to varying application needs, and utilize a numerical format (FP16) that simplifies software development while maintaining acceptable precision.

## 1.5 Scope of the Project
This project encompasses the full-stack design of a hardware/software co-designed system. The scope includes:
1. **Hardware Design:** Developing a generic N-point (up to 64 points) radix-2 FFT engine using Verilog HDL.
2. **Datapath Implementation:** Creating custom FP16 arithmetic units (multipliers, adders/subtractors) and a complex butterfly unit.
3. **Processor Integration:** Modifying an existing 5-stage RISC-V processor pipeline to incorporate the FFT engine as a custom functional unit using the `custom-0` opcode space.
4. **Software Tooling:** Developing the corresponding assembly routines and testing scripts to interface with the new hardware.
5. **Verification and Synthesis:** Proving functional correctness through rigorous RTL simulation and assessing hardware cost through logic synthesis.

## 1.6 Organization of the Report
The remainder of this report is structured as follows:
- **Section 2** outlines the specific objectives and goals of the project.
- **Section 3** reviews the existing literature and architectures related to FFT hardware design and RISC-V extensions.
- **Section 4** details the methodology, including the underlying mathematical algorithms, the architectural design of the hardware modules, and the pipeline integration strategy.
- **Section 5** presents the comprehensive results, encompassing functional verification, cycle-count benchmarking, synthesis area reports, and accuracy analysis.
- **Section 6** concludes the report and discusses potential avenues for future research and enhancements.
