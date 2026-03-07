// Integration Testbench for RISC-V Core + FFT Accelerator

`timescale 1ns/1ps

module tb_integration;

    reg clk;
    reg rst_n;
    
    // Core interface
    wire [31:0] ext_mem_addr;
    wire [31:0] ext_mem_wdata;
    wire ext_mem_we;
    reg [31:0] ext_mem_rdata;
    
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
    
    // Initialize instruction memory with FFT using custom instructions
    initial begin
        // Program with proper pipeline delays:
        // With a 5-stage pipeline: IF-ID-EX-MEM-WB
        // LUI result written in WB (cycle 5 after IF)
        // Next instruction needs to wait until value is in register file
        // Need at least 3 NOPs after LUI to ensure value is ready in register file
        
        // 0: LUI x1, 0x3C000
        dut.imem.mem[0] = 32'h3C0000B7; 
        
        // 1: LUI x2, 0x40000
        dut.imem.mem[1] = 32'h40000137;
        
        // 2-5: NOPs (wait for x1 and x2 to be written back)
        dut.imem.mem[2] = 32'h00000013;
        dut.imem.mem[3] = 32'h00000013;
        dut.imem.mem[4] = 32'h00000013;
        dut.imem.mem[5] = 32'h00000013;
        
        // 6: FFT.CMUL x3, x1, x2
        dut.imem.mem[6] = 32'h0020918B;
        
        // 7: FFT.BUTTERFLY x4, x1, x2
        dut.imem.mem[7] = 32'h0020820B;
        
        // 8-11: NOPs
        dut.imem.mem[8] = 32'h00000013;
        dut.imem.mem[9] = 32'h00000013;
        dut.imem.mem[10] = 32'h00000013;
        dut.imem.mem[11] = 32'h00000013;
    end
    
    // Test sequence
    initial begin
        $dumpfile("sim/tb_integration.vcd");
        $dumpvars(0, tb_integration);
        
        $display("Integration Test: RISC-V + FFT Accelerator");
        $display("========================================");
        
        rst_n = 0;
        #20;
        rst_n = 1;
        
        // Wait for execution
        #500;
        
        // Check results
        $display("\nRegister State:");
        $display("x1 (A): %h", dut.regfile.registers[1]);
        $display("x2 (B/W): %h", dut.regfile.registers[2]);
        $display("x3 (CMUL Result): %h", dut.regfile.registers[3]);
        $display("x4 (Butterfly Result): %h", dut.regfile.registers[4]);
        
        // x3 = x1 * x2 = 1.0 * 2.0 = 2.0 (0x4000 0000)
        if (dut.regfile.registers[3] === 32'h40000000)
            $display("CMUL: PASSED");
        else
            $display("CMUL: FAILED (Expected 40000000)");

        // x4 = x1 + W*1.0 = 1.0 + 2.0*1.0 = 3.0 (0x4200 0000)
        if (dut.regfile.registers[4] === 32'h42000000)
            $display("BUTTERFLY: PASSED");
        else
            $display("BUTTERFLY: FAILED (Expected 42000000)"); // Note: butterfly result packing might differ
            
        // Wait, butterfly returns TWO values: A+WB and A-WB.
        // My accelerator outputs BOTH in one 32-bit register?
        // fft_accelerator.v:
        // result <= {butterfly_out1_real, butterfly_out1_imag};
        // It outputs 'out1' (A+WB) only! 'out2' is lost?
        // Wait, result is 32-bit.
        // butterfly_unit computes out1 and out2.
        // fft_accelerator only assigns out1 to result?
        // Let's check fft_accelerator.v
        
        $finish;
    end

endmodule
