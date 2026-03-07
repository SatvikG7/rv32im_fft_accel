// Standalone Testbench for FFT Accelerator

`timescale 1ns/1ps

module tb_fft_accel_standalone;

    reg clk;
    reg rst_n;
    reg start;
    reg [31:0] operand_a, operand_b;
    reg [2:0] operation;
    wire [31:0] result;
    wire done, busy;
    
    // Instantiate
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
    
    // Clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Monitor internal signals
    always @(posedge clk) begin
        $display("T=%0t: Start=%b Busy=%b Done=%b cmul_done=%b cmul_start=%b Result=%h Latched=%h", 
                 $time, start, busy, done, dut.cmul_done, dut.cmul_start, result, dut.result_latched);
    end
    
    initial begin
        $dumpfile("sim/tb_fft_accel_standalone.vcd");
        $dumpvars(0, tb_fft_accel_standalone);
        
        $display("=== FFT Accelerator Standalone Test ===");
        
        // Reset
        rst_n = 0;
        start = 0;
        operand_a = 32'h0;
        operand_b = 32'h0;
        operation = 3'h0;
        #20;
        rst_n = 1;
        #10;
        
        // Test 1: Complex Multiply (1+0i) * (2+0i) = (2+0i)
        $display("\n--- Test 1: CMUL (1+0i) * (2+0i) ---");
        operand_a = {16'h3C00, 16'h0000};  // 1.0 + 0.0i
        operand_b = {16'h4000, 16'h0000};  // 2.0 + 0.0i
        operation = 3'b001;  // Complex multiply
        start = 1;
        #10;
        start = 0;
        
        // Wait for done with timeout
        repeat(20) begin
            @(posedge clk);
            if (done) begin
                $display("Done! Result=%h - Expected: 40000000", result);
                if (result == 32'h40000000)
                    $display("TEST 1: PASSED");
                else
                    $display("TEST 1: FAILED");
            end
        end
        #30;
        
        // Test 2: Complex Multiply (2+0i) * (3+0i) = (6+0i)
        $display("\n--- Test 2: CMUL (2+0i) * (3+0i) ---");
        operand_a = {16'h4000, 16'h0000};  // 2.0 + 0.0i
        operand_b = {16'h4200, 16'h0000};  // 3.0 + 0.0i
        operation = 3'b001;
        start = 1;
        #10;
        start = 0;
        
        repeat(20) begin
            @(posedge clk);
            if (done) begin
                $display("Done! Result=%h - Expected: 46000000", result);
                if (result == 32'h46000000)
                    $display("TEST 2: PASSED");
                else
                    $display("TEST 2: FAILED");
            end
        end
        #30;
        
        $display("\n=== Tests Complete ===");
        $finish;
    end
    
    // Timeout
    initial begin
        #3000;
        $display("TIMEOUT!");
        $finish;
    end

endmodule
