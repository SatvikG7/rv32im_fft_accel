// Integration Testbench for RISC-V Core + FFT Engine
// Tests the new SETN/LOAD/EXEC/READ instruction flow through the full pipeline

`timescale 1ns/1ps

module tb_integration;

    reg clk;
    reg rst_n;

    // Instantiate RISC-V Core
    riscv_core dut (
        .clk(clk),
        .rst_n(rst_n)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Initialize instruction memory with a 4-point FFT program
    // Inputs: [36, 22, 45, 15] -> Expected: [118+0j, -9-7j, 44+0j, -9+7j]
    initial begin
        // --- Step 1: Set FFT size to 4 ---
        // LUI x1, 0x00008  (x1 = 8 << 12, but we need x1 = 4)
        // ADDI x1, x0, 4
        dut.imem.mem[0] = 32'h00400093;   // addi x1, x0, 4

        // NOP padding (wait for x1 to be available)
        dut.imem.mem[1] = 32'h00000013;   // nop
        dut.imem.mem[2] = 32'h00000013;   // nop

        // FFT.SETN x0, x1 : funct3=000, opcode=0x0B
        // .word (0x0B | (0 << 7) | (0 << 12) | (1 << 15) | (0 << 20) | (0 << 25))
        dut.imem.mem[3] = 32'h0000800B;   // FFT.SETN x0, x1

        // NOP padding
        dut.imem.mem[4] = 32'h00000013;   // nop
        dut.imem.mem[5] = 32'h00000013;   // nop
        dut.imem.mem[6] = 32'h00000013;   // nop

        // --- Step 2: Load 4 samples ---
        // Load x[0] = 36+0j = 0x50800000
        // LUI x10, 0x50800
        dut.imem.mem[7]  = 32'h50800537;  // lui x10, 0x50800
        // ADDI x2, x0, 0  (index 0)
        dut.imem.mem[8]  = 32'h00000113;  // addi x2, x0, 0
        dut.imem.mem[9]  = 32'h00000013;  // nop
        dut.imem.mem[10] = 32'h00000013;  // nop
        // FFT.LOAD x0, x10, x2 : funct3=001
        // .word (0x0B | (0 << 7) | (1 << 12) | (10 << 15) | (2 << 20) | (0 << 25))
        dut.imem.mem[11] = 32'h0025100B;  // FFT.LOAD x0, x10, x2

        dut.imem.mem[12] = 32'h00000013;  // nop
        dut.imem.mem[13] = 32'h00000013;  // nop
        dut.imem.mem[14] = 32'h00000013;  // nop

        // Load x[1] = 22+0j = 0x4D800000
        dut.imem.mem[15] = 32'h4D800537;  // lui x10, 0x4D800
        dut.imem.mem[16] = 32'h00100113;  // addi x2, x0, 1
        dut.imem.mem[17] = 32'h00000013;  // nop
        dut.imem.mem[18] = 32'h00000013;  // nop
        dut.imem.mem[19] = 32'h0025100B;  // FFT.LOAD x0, x10, x2

        dut.imem.mem[20] = 32'h00000013;  // nop
        dut.imem.mem[21] = 32'h00000013;  // nop
        dut.imem.mem[22] = 32'h00000013;  // nop

        // Load x[2] = 45+0j = 0x51A00000
        dut.imem.mem[23] = 32'h51A00537;  // lui x10, 0x51A00
        dut.imem.mem[24] = 32'h00200113;  // addi x2, x0, 2
        dut.imem.mem[25] = 32'h00000013;  // nop
        dut.imem.mem[26] = 32'h00000013;  // nop
        dut.imem.mem[27] = 32'h0025100B;  // FFT.LOAD x0, x10, x2

        dut.imem.mem[28] = 32'h00000013;  // nop
        dut.imem.mem[29] = 32'h00000013;  // nop
        dut.imem.mem[30] = 32'h00000013;  // nop

        // Load x[3] = 15+0j = 0x4B800000
        dut.imem.mem[31] = 32'h4B800537;  // lui x10, 0x4B800
        dut.imem.mem[32] = 32'h00300113;  // addi x2, x0, 3
        dut.imem.mem[33] = 32'h00000013;  // nop
        dut.imem.mem[34] = 32'h00000013;  // nop
        dut.imem.mem[35] = 32'h0025100B;  // FFT.LOAD x0, x10, x2

        dut.imem.mem[36] = 32'h00000013;  // nop
        dut.imem.mem[37] = 32'h00000013;  // nop
        dut.imem.mem[38] = 32'h00000013;  // nop

        // --- Step 3: Execute FFT ---
        // FFT.EXEC x0 : funct3=010
        // .word (0x0B | (0 << 7) | (2 << 12) | (0 << 15) | (0 << 20) | (0 << 25))
        dut.imem.mem[39] = 32'h0000200B;  // FFT.EXEC x0

        dut.imem.mem[40] = 32'h00000013;  // nop
        dut.imem.mem[41] = 32'h00000013;  // nop
        dut.imem.mem[42] = 32'h00000013;  // nop

        // --- Step 4: Read results ---
        // FFT.READ x20, x2 : funct3=011
        // Read X[0]
        dut.imem.mem[43] = 32'h00000113;  // addi x2, x0, 0
        dut.imem.mem[44] = 32'h00000013;  // nop
        dut.imem.mem[45] = 32'h00000013;  // nop
        // .word (0x0B | (20 << 7) | (3 << 12) | (2 << 15) | (0 << 20))
        dut.imem.mem[46] = 32'h00013A0B;  // FFT.READ x20, x2

        dut.imem.mem[47] = 32'h00000013;  // nop
        dut.imem.mem[48] = 32'h00000013;  // nop
        dut.imem.mem[49] = 32'h00000013;  // nop

        // Read X[1]
        dut.imem.mem[50] = 32'h00100113;  // addi x2, x0, 1
        dut.imem.mem[51] = 32'h00000013;  // nop
        dut.imem.mem[52] = 32'h00000013;  // nop
        dut.imem.mem[53] = 32'h00013A8B;  // FFT.READ x21, x2

        dut.imem.mem[54] = 32'h00000013;  // nop
        dut.imem.mem[55] = 32'h00000013;  // nop
        dut.imem.mem[56] = 32'h00000013;  // nop

        // Read X[2]
        dut.imem.mem[57] = 32'h00200113;  // addi x2, x0, 2
        dut.imem.mem[58] = 32'h00000013;  // nop
        dut.imem.mem[59] = 32'h00000013;  // nop
        dut.imem.mem[60] = 32'h00013B0B;  // FFT.READ x22, x2

        dut.imem.mem[61] = 32'h00000013;  // nop
        dut.imem.mem[62] = 32'h00000013;  // nop
        dut.imem.mem[63] = 32'h00000013;  // nop

        // Read X[3]
        dut.imem.mem[64] = 32'h00300113;  // addi x2, x0, 3
        dut.imem.mem[65] = 32'h00000013;  // nop
        dut.imem.mem[66] = 32'h00000013;  // nop
        dut.imem.mem[67] = 32'h00013B8B;  // FFT.READ x23, x2

        // Padding
        dut.imem.mem[68] = 32'h00000013;  // nop
        dut.imem.mem[69] = 32'h00000013;  // nop
        dut.imem.mem[70] = 32'h00000013;  // nop
    end

    // Test sequence
    initial begin
        $dumpfile("build/tb_integration.vcd");
        $dumpvars(0, tb_integration);

        $display("Integration Test: RISC-V + FFT Engine (4-Point)");
        $display("================================================");

        rst_n = 0;
        #20;
        rst_n = 1;

        // Wait for execution (4-point FFT should complete in ~500 cycles)
        #10000;

        // Check results
        $display("\nRegister State:");
        $display("x20 (X[0]): %h (expected: 57600000 -> 118+0j)",  dut.regfile.registers[20]);
        $display("x21 (X[1]): %h (expected: C880C700 -> -9-7j)",   dut.regfile.registers[21]);
        $display("x22 (X[2]): %h (expected: 51800000 -> 44+0j)",   dut.regfile.registers[22]);
        $display("x23 (X[3]): %h (expected: C8804700 -> -9+7j)",   dut.regfile.registers[23]);

        // Verify
        if (dut.regfile.registers[20] === 32'h57600000)
            $display("X[0]: PASSED");
        else
            $display("X[0]: FAILED (got %h)", dut.regfile.registers[20]);

        if (dut.regfile.registers[21] === 32'hC880C700)
            $display("X[1]: PASSED");
        else
            $display("X[1]: FAILED (got %h)", dut.regfile.registers[21]);

        if (dut.regfile.registers[22] === 32'h51800000)
            $display("X[2]: PASSED");
        else
            $display("X[2]: FAILED (got %h)", dut.regfile.registers[22]);

        if (dut.regfile.registers[23] === 32'hC8804700)
            $display("X[3]: PASSED");
        else
            $display("X[3]: FAILED (got %h)", dut.regfile.registers[23]);

        $finish;
    end

endmodule
