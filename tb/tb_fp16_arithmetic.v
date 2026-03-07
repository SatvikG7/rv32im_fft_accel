// Testbench for FP16 Arithmetic Units

`timescale 1ns/1ps

module tb_fp16_arithmetic;

    reg [15:0] a, b;
    wire [15:0] add_result, sub_result, mul_result;
    
    // Instantiate units
    fp16_add adder (
        .a(a),
        .b(b),
        .sub(1'b0),
        .result(add_result)
    );
    
    fp16_add subtractor (
        .a(a),
        .b(b),
        .sub(1'b1),
        .result(sub_result)
    );
    
    fp16_mul multiplier (
        .a(a),
        .b(b),
        .result(mul_result)
    );
    
    // Test vectors
    initial begin
        $dumpfile("sim/tb_fp16_arithmetic.vcd");
        $dumpvars(0, tb_fp16_arithmetic);
        
        $display("FP16 Arithmetic Unit Tests");
        $display("==========================");
        
        // Test 1: 1.0 + 1.0 = 2.0
        a = 16'h3C00;  // 1.0
        b = 16'h3C00;  // 1.0
        #10;
        $display("Test 1: 1.0 + 1.0 = %h (expected: 4000 for 2.0)", add_result);
        
        // Test 2: 2.0 - 1.0 = 1.0
        a = 16'h4000;  // 2.0
        b = 16'h3C00;  // 1.0
        #10;
        $display("Test 2: 2.0 - 1.0 = %h (expected: 3C00 for 1.0)", sub_result);
        
        // Test 3: 2.0 * 3.0 = 6.0
        a = 16'h4000;  // 2.0
        b = 16'h4200;  // 3.0
        #10;
        $display("Test 3: 2.0 * 3.0 = %h (expected: 4600 for 6.0)", mul_result);
        
        // Test 4: 0.5 * 0.5 = 0.25
        a = 16'h3800;  // 0.5
        b = 16'h3800;  // 0.5
        #10;
        $display("Test 4: 0.5 * 0.5 = %h (expected: 3400 for 0.25)", mul_result);
        
        // Test 5: Zero handling
        a = 16'h0000;  // 0.0
        b = 16'h3C00;  // 1.0
        #10;
        $display("Test 5: 0.0 + 1.0 = %h (expected: 3C00 for 1.0)", add_result);
        $display("Test 5: 0.0 * 1.0 = %h (expected: 0000 for 0.0)", mul_result);
        
        $display("\nAll tests completed!");
        $finish;
    end

endmodule
