    .section .text.init
    .globl _start

# Custom Macros for FFT ops
.macro fft_add rd, rs1, rs2
    .word (0x0B | (\rd << 7) | (0 << 12) | (\rs1 << 15) | (\rs2 << 20) | (0 << 25))
.endm

.macro fft_cmul rd, rs1, rs2
    .word (0x0B | (\rd << 7) | (1 << 12) | (\rs1 << 15) | (\rs2 << 20) | (0 << 25))
.endm

.macro fft_sub rd, rs1, rs2
    .word (0x0B | (\rd << 7) | (2 << 12) | (\rs1 << 15) | (\rs2 << 20) | (0 << 25))
.endm

_start:
    # 1. Load inputs and twiddle factors using immediate loads (dmem is uninitialized initially)
    li x10, 0x50800000  # x[0] = 36 + 0j
    li x11, 0x4D800000  # x[1] = 22 + 0j
    li x12, 0x51A00000  # x[2] = 45 + 0j
    li x13, 0x4B800000  # x[3] = 15 + 0j
    
    li x5, 0x3C000000   # W_4_0 = 1 + 0j
    li x6, 0x0000BC00   # W_4_1 = 0 - 1j

    # Wait for memory load
    nop
    nop
    nop

    # Stage 1: Butterfly
    # A0 = x[0] + x[2]
    fft_add 14, 10, 12
    nop; nop; nop;
    # B0 = x[0] - x[2]
    fft_sub 15, 10, 12
    nop; nop; nop;
    # A1 = x[1] + x[3]
    fft_add 16, 11, 13
    nop; nop; nop;
    # B1 = x[1] - x[3]
    fft_sub 17, 11, 13

    # NOPs to handle latency if any
    nop
    nop
    nop

    # Stage 2: Multiply and Butterfly
    # W_A1 = A1 * W_4_0
    fft_cmul 18, 16, 5
    nop; nop; nop;

    # X[0] = A0 + W_A1
    fft_add 20, 14, 18
    nop; nop; nop;
    # X[2] = A0 - W_A1
    fft_sub 22, 14, 18
    nop; nop; nop;

    # W_B1 = B1 * W_4_1
    fft_cmul 19, 17, 6
    nop; nop; nop;

    # X[1] = B0 + W_B1
    fft_add 21, 15, 19
    nop; nop; nop;
    # X[3] = B0 - W_B1
    fft_sub 23, 15, 19
    nop; nop; nop;

    nop
    nop
    nop

    # Store results back to memory
    sw x20, 24(x1)  # X[0] = 118
    sw x21, 28(x1)  # X[1] = -9 - 7j
    sw x22, 32(x1)  # X[2] = 44
    sw x23, 36(x1)  # X[3] = -9 + 7j

Infinite_Loop:
    j Infinite_Loop


    .section .data
    .align 4
_data:
    .word 0x50800000  # x[0]
    .word 0x4D800000  # x[1]
    .word 0x51A00000  # x[2]
    .word 0x4B800000  # x[3]
    .word 0x3C000000  # W_4^0 = 1 + 0j
    .word 0x0000BC00  # W_4^1 = 0 - 1j
    
    # Space for Outputs X[0]..X[3]
    .word 0x00000000
    .word 0x00000000
    .word 0x00000000
    .word 0x00000000

