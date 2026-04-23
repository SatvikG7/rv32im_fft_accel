    .section .text.init
    .globl _start

# ===========================================================================
# Custom FFT Instruction Macros (opcode = 0x0B)
# ===========================================================================

# FFT.SETN rd, rs1 — Set FFT size (funct3=000)
# engine.N = rs1[6:0]
.macro fft_setn rd, rs1
    .word (0x0B | (\rd << 7) | (0 << 12) | (\rs1 << 15) | (0 << 20) | (0 << 25))
.endm

# FFT.LOAD rd, rs1, rs2 — Load sample at index (funct3=001)
# engine.buf[rs2[5:0]] = rs1 (packed {real[15:0], imag[15:0]})
.macro fft_load rd, rs1, rs2
    .word (0x0B | (\rd << 7) | (1 << 12) | (\rs1 << 15) | (\rs2 << 20) | (0 << 25))
.endm

# FFT.EXEC rd — Execute FFT computation (funct3=010)
# Stalls pipeline until FFT is complete
.macro fft_exec rd
    .word (0x0B | (\rd << 7) | (2 << 12) | (0 << 15) | (0 << 20) | (0 << 25))
.endm

# FFT.READ rd, rs1 — Read FFT result at index (funct3=011)
# rd = engine.buf[rs1[5:0]]
.macro fft_read rd, rs1
    .word (0x0B | (\rd << 7) | (3 << 12) | (\rs1 << 15) | (0 << 20) | (0 << 25))
.endm

# ===========================================================================
# Program: 8-Point FFT Demonstration
# Inputs: [1, 2, 3, 4, 5, 6, 7, 8] (real-only, imag=0)
# Expected outputs (from fft_ref.py):
#   X[0] = 36.0 + 0.0j    -> 0x50800000
#   X[1] = -4.0 + 9.66j   -> 0xC40048D4
#   X[2] = -4.0 + 4.0j    -> 0xC4004400
#   X[3] = -4.0 + 1.66j   -> 0xC4003EA1
#   X[4] = -4.0 + 0.0j    -> 0xC4000000
#   X[5] = -4.0 - 1.66j   -> 0xC400BEA1
#   X[6] = -4.0 - 4.0j    -> 0xC400C400
#   X[7] = -4.0 - 9.66j   -> 0xC400C8D4
# ===========================================================================

_start:
    # ------------------------------------------------------------------
    # Step 1: Set FFT size to 8
    # ------------------------------------------------------------------
    li x1, 8
    fft_setn 0, 1           # FFT.SETN x0, x1 (N=8, discard result)
    nop
    nop
    nop

    # ------------------------------------------------------------------
    # Step 2: Load 8 input samples
    # Each sample is packed as {real_fp16, imag_fp16} in a 32-bit register
    # ------------------------------------------------------------------
    # x[0] = 1.0 + 0j
    li x10, 0x3C000000      # FP16: real=0x3C00 (1.0), imag=0x0000 (0.0)
    li x2, 0
    fft_load 0, 10, 2       # FFT.LOAD x0, x10, x2
    nop; nop; nop

    # x[1] = 2.0 + 0j
    li x10, 0x40000000      # FP16: real=0x4000 (2.0), imag=0x0000
    li x2, 1
    fft_load 0, 10, 2
    nop; nop; nop

    # x[2] = 3.0 + 0j
    li x10, 0x42000000      # FP16: real=0x4200 (3.0), imag=0x0000
    li x2, 2
    fft_load 0, 10, 2
    nop; nop; nop

    # x[3] = 4.0 + 0j
    li x10, 0x44000000      # FP16: real=0x4400 (4.0), imag=0x0000
    li x2, 3
    fft_load 0, 10, 2
    nop; nop; nop

    # x[4] = 5.0 + 0j
    li x10, 0x45000000      # FP16: real=0x4500 (5.0), imag=0x0000
    li x2, 4
    fft_load 0, 10, 2
    nop; nop; nop

    # x[5] = 6.0 + 0j
    li x10, 0x46000000      # FP16: real=0x4600 (6.0), imag=0x0000
    li x2, 5
    fft_load 0, 10, 2
    nop; nop; nop

    # x[6] = 7.0 + 0j
    li x10, 0x47000000      # FP16: real=0x4700 (7.0), imag=0x0000
    li x2, 6
    fft_load 0, 10, 2
    nop; nop; nop

    # x[7] = 8.0 + 0j
    li x10, 0x48000000      # FP16: real=0x4800 (8.0), imag=0x0000
    li x2, 7
    fft_load 0, 10, 2
    nop; nop; nop

    # ------------------------------------------------------------------
    # Step 3: Execute FFT (pipeline stalls until complete)
    # ------------------------------------------------------------------
    fft_exec 0               # FFT.EXEC x0
    nop; nop; nop

    # ------------------------------------------------------------------
    # Step 4: Read results
    # ------------------------------------------------------------------
    li x2, 0
    fft_read 20, 2           # X[0] -> x20
    nop; nop; nop

    li x2, 1
    fft_read 21, 2           # X[1] -> x21
    nop; nop; nop

    li x2, 2
    fft_read 22, 2           # X[2] -> x22
    nop; nop; nop

    li x2, 3
    fft_read 23, 2           # X[3] -> x23
    nop; nop; nop

    li x2, 4
    fft_read 24, 2           # X[4] -> x24
    nop; nop; nop

    li x2, 5
    fft_read 25, 2           # X[5] -> x25
    nop; nop; nop

    li x2, 6
    fft_read 26, 2           # X[6] -> x26
    nop; nop; nop

    li x2, 7
    fft_read 27, 2           # X[7] -> x27
    nop; nop; nop

    # ------------------------------------------------------------------
    # Step 5: Store results to memory for verification
    # ------------------------------------------------------------------
    li x3, 0                 # Base address for stores
    sw x20, 0(x3)            # X[0]
    sw x21, 4(x3)            # X[1]
    sw x22, 8(x3)            # X[2]
    sw x23, 12(x3)           # X[3]
    sw x24, 16(x3)           # X[4]
    sw x25, 20(x3)           # X[5]
    sw x26, 24(x3)           # X[6]
    sw x27, 28(x3)           # X[7]

Infinite_Loop:
    j Infinite_Loop
