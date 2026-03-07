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
        // We will run until $finish at #5000
    end
    
    // Track writes to regfile
    always @(posedge clk) begin
        if (wb_we && wb_rd != 0) begin
            $display("Time=%0t: Reg x%0d <- %h", $time, wb_rd, wb_data);
        end
    end
    
    initial begin
        #5000;
        
        // Check results
        $display("\nRegister File State (Intermediate):");
        $display("x14 (A0): %h", dut.regfile.registers[14]);
        $display("x15 (B0): %h", dut.regfile.registers[15]);
        $display("x16 (A1): %h", dut.regfile.registers[16]);
        $display("x17 (B1): %h", dut.regfile.registers[17]);
        $display("x18 (W_A1): %h", dut.regfile.registers[18]);
        $display("x19 (W_B1): %h", dut.regfile.registers[19]);
        
        $display("\nRegister File State (FFT Results):");
        $display("x20: %h (expected: 57600000 -> 118+0j)", dut.regfile.registers[20]);
        $display("x21: %h (expected: c880c700 -> -9-7j)", dut.regfile.registers[21]);
        $display("x22: %h (expected: 51800000 -> 44+0j)", dut.regfile.registers[22]);
        $display("x23: %h (expected: c8804700 -> -9+7j)", dut.regfile.registers[23]);
        
        $finish;
    end

endmodule
