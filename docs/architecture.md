# RISC-V Core Architecture

The processor core (`src/riscv_core.v`) is designed as a classic 5-stage pipeline implementing the RV32I Base Integer Instruction Set. 

## Pipeline Stages

1. **Fetch Stage (`fetch_stage.v`)**:
   - Manages the Program Counter (PC).
   - Interfaces with the Instruction Memory to fetch the 32-bit instruction.
   - Handles branch target updates and instruction flushing.
2. **Decode Stage (`decode_stage.v`)**:
   - Decodes the fetched instruction.
   - Reads source operands from the Register File (`register_file.v`).
   - Generates the immediate values and all control signals required for subsequent stages.
   - Detects the custom FFT instruction (Opcode `0x0B`) and asserts `is_custom`.
3. **Execute Stage (`execute_stage.v`)**:
   - Contains the Arithmetic Logic Unit (ALU) (`alu.v`) for standard operations.
   - Performs branch condition checking and calculates branch targets.
   - Interfaces closely with the FFT Accelerator to route operands for custom DSP instructions.
4. **Memory Stage (`memory_stage.v`)**:
   - Interfaces with the Data Memory (`data_memory.v`).
   - Manages Load and Store instructions, passing non-memory results appropriately through a pipeline register.
5. **Writeback Stage (`writeback_stage.v`)**:
   - Chooses between the ALU/Custom result and the data memory result.
   - Writes the final data back into the destination register inside the Register File.

## Hazard Detection and Forwarding

The architecture includes a sophisticated **Hazard Unit (`hazard_unit.v`)**:
- **Data Forwarding**: Resolves Read-After-Write (RAW) data hazards by forwarding results from the EX/MEM and MEM/WB pipeline registers directly to the Execute stage input Muxes.
- **Stalling**: Checks for load-use hazards. If a load instruction is immediately followed by a dependent instruction, the hazard unit stalls the IF and ID stages while inserting a bubble into the EX stage.
- **Flushing**: Resolves control hazards by flushing the pipeline (IF/ID and ID/EX registers) when a branch is taken.

## Memory Subsystem

- **Instruction Memory (`instruction_memory.v`)**: Simulated ROM initialized with software payloads (e.g., standard hex dump).
- **Data Memory (`data_memory.v`)**: Read/Write RAM synchronized with the pipeline.
- The external memory interface placeholders optionally route to advanced architectures (AXI, Wishbone) for realistic SoC integration.
