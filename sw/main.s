    .section .text.init
    .globl _start

_start:
    # Initialize some registers
    li x1, 42           # Loading immediate 42 into x1
    li x2, 100          # Loading immediate 100 into x2

    # Test basic arithmetic
    add x3, x1, x2      # x3 = 142
    sub x4, x2, x1      # x4 = 58

    # Test logical ops
    and x5, x1, x2      # x5 = 42 & 100 = 32
    or x6, x1, x2       # x6 = 42 | 100 = 110

    # Test memory
    la x7, _test_data   # Load address of _test_data
    sw x3, 0(x7)        # Store 142 to memory
    lw x8, 0(x7)        # Load 142 back to x8
    
    # Test branch
    beq x3, x8, _branch_success
    
_branch_fail:
    j _branch_fail      # Infinite loop on failure

_branch_success:
    # Test custom FFT instruction (Opcode format for custom accelerator)
    # Using the standard opcode space if configured in decode_stage
    # For example: 0x0B opcode space for custom instructions, or we'll just write nop
    nop
    nop

_end:
    j _end              # End simulation infinite loop

    .section .data
    .align 4
_test_data:
    .word 0x00000000
