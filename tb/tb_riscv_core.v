// Testbench for RISC-V Core with Modular FFT Accelerator
// Tests 8-point FFT firmware execution through the full processor pipeline

`timescale 1ns/1ps

module tb_riscv_core;

    reg clk;
    reg rst_n;

    // Internal signals for monitoring (accessed via hierarchical reference)
    wire [31:0] pc = dut.fetch.pc;
    wire [31:0] instruction = dut.fetch.instruction_in;
    wire [31:0] wb_data = dut.writeback.wb_data;
    wire [4:0] wb_rd = dut.writeback.wb_rd;
    wire wb_we = dut.writeback.wb_we;

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

    initial begin
        $readmemh("sw/firmware.hex", dut.imem.mem);
    end

    // Test sequence
    initial begin
        $dumpfile("build/tb_riscv_core.vcd");
        $dumpvars(0, tb_riscv_core);

        $display("RISC-V Core Testbench (Modular FFT)");
        $display("====================================");

        rst_n = 0;
        #20;
        rst_n = 1;

        // Wait for program to execute
        // 8-point FFT: ~88 compute cycles + load/read overhead
        // Total with firmware: ~2000 cycles should be sufficient
    end

    // Track writes to regfile
    always @(posedge clk) begin
        if (wb_we && wb_rd != 0) begin
            $display("Time=%0t: Reg x%0d <- %h", $time, wb_rd, wb_data);
        end
    end

    initial begin
        #50000;

        // Check FFT results in registers x20-x27
        // 8-point FFT of [1,2,3,4,5,6,7,8]
        $display("\nRegister File State (FFT Results):");
        $display("x20 (X[0]): %h (expected: 50800000 -> 36+0j)",   dut.regfile.registers[20]);
        $display("x21 (X[1]): %h (expected: C40048D4 -> -4+9.66j)", dut.regfile.registers[21]);
        $display("x22 (X[2]): %h (expected: C4004400 -> -4+4j)",    dut.regfile.registers[22]);
        $display("x23 (X[3]): %h (expected: C4003EA1 -> -4+1.66j)", dut.regfile.registers[23]);
        $display("x24 (X[4]): %h (expected: C4000000 -> -4+0j)",    dut.regfile.registers[24]);
        $display("x25 (X[5]): %h (expected: C400BEA1 -> -4-1.66j)", dut.regfile.registers[25]);
        $display("x26 (X[6]): %h (expected: C400C400 -> -4-4j)",    dut.regfile.registers[26]);
        $display("x27 (X[7]): %h (expected: C400C8D4 -> -4-9.66j)", dut.regfile.registers[27]);

        $finish;
    end

endmodule
