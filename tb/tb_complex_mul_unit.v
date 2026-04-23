// Standalone Testbench for Complex Multiply Unit

`timescale 1ns/1ps

module tb_complex_mul_unit;

    reg clk;
    reg rst_n;
    reg start;
    reg [15:0] a_real, a_imag;
    reg [15:0] b_real, b_imag;
    wire [15:0] result_real, result_imag;
    wire done;
    
    // Instantiate
    complex_mul_unit dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .a_real(a_real),
        .a_imag(a_imag),
        .b_real(b_real),
        .b_imag(b_imag),
        .result_real(result_real),
        .result_imag(result_imag),
        .done(done)
    );
    
    // Clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Monitor state
    always @(posedge clk) begin
        $display("T=%0t: State=%d Start=%b Done=%b Result=(%h, %h)", 
                 $time, dut.state, start, done, result_real, result_imag);
    end
    
    initial begin
        $dumpfile("build/tb_complex_mul_unit.vcd");
        $dumpvars(0, tb_complex_mul_unit);
        
        $display("=== Complex Multiply Unit Standalone Test ===");
        $display("FP16 values: 1.0=3C00, 2.0=4000, 3.0=4200");
        
        // Reset
        rst_n = 0;
        start = 0;
        a_real = 16'h0;
        a_imag = 16'h0;
        b_real = 16'h0;
        b_imag = 16'h0;
        #20;
        rst_n = 1;
        #10;
        
        // Test 1: (1+0i) * (2+0i) = (2+0i)
        $display("\n--- Test 1: (1+0i) * (2+0i) ---");
        a_real = 16'h3C00;  // 1.0
        a_imag = 16'h0000;  // 0.0
        b_real = 16'h4000;  // 2.0
        b_imag = 16'h0000;  // 0.0
        start = 1;
        #10;
        start = 0;
        
        // Wait for done
        wait(done);
        $display("Result: (%h, %h) - Expected: (4000, 0000)", result_real, result_imag);
        if (result_real == 16'h4000 && result_imag == 16'h0000)
            $display("TEST 1: PASSED");
        else
            $display("TEST 1: FAILED");
        #20;
        
        // Test 2: (1+0i) * (1+0i) = (1+0i)
        $display("\n--- Test 2: (1+0i) * (1+0i) ---");
        a_real = 16'h3C00;  // 1.0
        a_imag = 16'h0000;  // 0.0
        b_real = 16'h3C00;  // 1.0
        b_imag = 16'h0000;  // 0.0
        start = 1;
        #10;
        start = 0;
        
        wait(done);
        $display("Result: (%h, %h) - Expected: (3C00, 0000)", result_real, result_imag);
        if (result_real == 16'h3C00 && result_imag == 16'h0000)
            $display("TEST 2: PASSED");
        else
            $display("TEST 2: FAILED");
        #20;
        
        // Test 3: (2+0i) * (3+0i) = (6+0i)
        $display("\n--- Test 3: (2+0i) * (3+0i) ---");
        a_real = 16'h4000;  // 2.0
        a_imag = 16'h0000;  // 0.0
        b_real = 16'h4200;  // 3.0
        b_imag = 16'h0000;  // 0.0
        start = 1;
        #10;
        start = 0;
        
        wait(done);
        $display("Result: (%h, %h) - Expected: (4600, 0000)", result_real, result_imag);
        if (result_real == 16'h4600 && result_imag == 16'h0000)
            $display("TEST 3: PASSED");
        else
            $display("TEST 3: FAILED");
        #20;
        
        $display("\n=== Tests Complete ===");
        $finish;
    end
    
    // Timeout
    initial begin
        #2000;
        $display("TIMEOUT!");
        $finish;
    end

endmodule
