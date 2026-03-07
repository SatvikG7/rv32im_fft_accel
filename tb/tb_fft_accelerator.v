// Testbench for FFT Accelerator

`timescale 1ns/1ps

module tb_fft_accelerator;

    reg clk, rst_n;
    reg start;
    reg [31:0] operand_a, operand_b;
    reg [2:0] operation;
    wire [31:0] result;
    wire done, busy;
    
    // Instantiate FFT accelerator
    fft_accelerator dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .operand_a(operand_a),
        .operand_b(operand_b),
        .operation(operation),
        .result(result),
        .done(done),
        .busy(busy)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Test sequence
    initial begin
        $dumpfile("sim/tb_fft_accelerator.vcd");
        $dumpvars(0, tb_fft_accelerator);
        
        $display("FFT Accelerator Tests");
        $display("=====================");
        
        // Reset
        rst_n = 0;
        start = 0;
        operand_a = 32'h0;
        operand_b = 32'h0;
        operation = 3'h0;
        #20;
        rst_n = 1;
        #10;
        
        // Test 1: Complex multiply (1+0i) * (1+0i) = (1+0i)
        $display("\nTest 1: Complex Multiply (1+0i) * (1+0i)");
        operand_a = {16'h3C00, 16'h0000};  // 1.0 + 0.0i
        operand_b = {16'h3C00, 16'h0000};  // 1.0 + 0.0i
        operation = 3'b001;  // Complex multiply
        start = 1;
        #10;
        start = 0;
        
        wait(done);
        $display("Result: %h (expected: 3C000000 for 1.0+0.0i)", result);
        #20;
        
        // Test 2: Complex multiply (2+0i) * (3+0i) = (6+0i)
        $display("\nTest 2: Complex Multiply (2+0i) * (3+0i)");
        operand_a = {16'h4000, 16'h0000};  // 2.0 + 0.0i
        operand_b = {16'h4200, 16'h0000};  // 3.0 + 0.0i
        operation = 3'b001;
        start = 1;
        #10;
        start = 0;
        
        wait(done);
        $display("Result: %h (expected: 46000000 for 6.0+0.0i)", result);
        #20;
        
        // Test 3: Butterfly operation
        $display("\nTest 3: Butterfly Operation");
        operand_a = {16'h3C00, 16'h0000};  // A = 1.0 + 0.0i
        operand_b = {16'h3C00, 16'h0000};  // W = 1.0 + 0.0i (twiddle)
        operation = 3'b000;  // Butterfly
        start = 1;
        #10;
        start = 0;
        
        wait(done);
        $display("Result: %h", result);
        #20;
        
        $display("\nAll FFT accelerator tests completed!");
        #100;
        $finish;
    end
    
    // Timeout
    initial begin
        #10000;
        $display("ERROR: Timeout!");
        $finish;
    end

endmodule
