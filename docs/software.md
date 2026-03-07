# Software Environment

Programs meant for the RISC-V core are coded in RISC-V Assembly (or C) and built into firmware hexadecimal routines. Memory operations and linker offsets align directly with the processor's Instruction Memory initialization expectations.

## Directory Structure
- `sw/main.s`: The primary testing and evaluation assembly payload.
- `sw/link.ld`: The linker script to accurately place addresses for simulation loading.
- `sw/Makefile`: Manages compilation directly with RISC-V GCC toolchains.

## Standard Payload (`main.s`)
The bare-metal implementation performs:
1. **Register loading**: Uses combinations of standard Immediate and Logical instructions (`li`, `add`, `sub`).
2. **Memory Interaction**: Verifies Store and Load consistency to dynamic memories (`sw`, `lw`).
3. **Branches**: Tests Conditional structures (`beq`, `bne`).
4. **Custom Accelerators**: Utilizing pre-reserved operations mappings (`nop` placeholders or custom Opcodes `0x0B`) to activate hardware acceleration tests.

## Compilation Process
Typing `make compile` from the root directory invokes:
1. `riscv32-unknown-elf-gcc` to assemble the payload.
2. `riscv32-unknown-elf-objcopy` to yield `.bin` and `.hex` binaries.
3. `riscv32-unknown-elf-objdump` to provide a readable `.dump` view for debugging instruction flow.

*Note: Ensure your environment has standard `riscv64-unknown-elf-*` or `riscv32-unknown-elf-*` GCC packages sourced and configured on the `PATH`.*
