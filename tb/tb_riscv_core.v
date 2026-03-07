// Testbench for RISC-V Core

`timescale 1ns/1ps

module tb_riscv_core;

    reg clk;
    reg rst_n;
    
    // Core interface
    wire [31:0] ext_mem_addr;
    wire [31:0] ext_mem_wdata;
    wire ext_mem_we;
    reg [31:0] ext_mem_rdata;
    
    // Internal signals for monitoring (accessed via hierarchical reference)
    wire [31:0] pc = dut.fetch.pc;
    wire [31:0] instruction = dut.fetch.instruction_in;
    wire [31:0] wb_data = dut.writeback.wb_data;
    wire [4:0] wb_rd = dut.writeback.wb_rd;
    wire wb_we = dut.writeback.wb_we;
    
    // Instantiate RISC-V Core
    riscv_core dut (
        .clk(clk),
        .rst_n(rst_n),
        .ext_mem_addr(ext_mem_addr),
        .ext_mem_wdata(ext_mem_wdata),
        .ext_mem_we(ext_mem_we),
        .ext_mem_rdata(ext_mem_rdata)
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
        
        $display("RISC-V Core Testbench");
        $display("=====================");
        
        rst_n = 0;
        ext_mem_rdata = 32'h0;
        #20;
        rst_n = 1;
        
        // Wait for program to execute
        #200;
        
        // Check results
        $display("\nRegister File State:");
        $display("x1: %d (expected: 42)", dut.regfile.registers[1]);
        $display("x2: %d (expected: 100)", dut.regfile.registers[2]);
        $display("x3: %d (expected: 142)", dut.regfile.registers[3]);
        $display("x4: %d (expected: 58)", dut.regfile.registers[4]);
        $display("x5: %d (expected: 32)", dut.regfile.registers[5]);
        $display("x6: %d (expected: 110)", dut.regfile.registers[6]);
        
        if (dut.regfile.registers[3] === 32'd142 && dut.regfile.registers[4] === 32'd58 && dut.regfile.registers[6] === 32'd110)
            $display("\nTEST PASSED");
        else
            $display("\nTEST FAILED");
            
        $finish;
    end

endmodule
