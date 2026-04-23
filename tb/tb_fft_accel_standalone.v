// Standalone Testbench for FFT Accelerator (Modular N-Point)
// Tests the accelerator with SETN/LOAD/EXEC/READ command flow
// Test 1: 4-point FFT with inputs [36, 22, 45, 15]
// Test 2: 8-point FFT with inputs [1, 2, 3, 4, 5, 6, 7, 8]

`timescale 1ns/1ps

module tb_fft_accel_standalone;

    reg clk;
    reg rst_n;
    reg start;
    reg [31:0] operand_a, operand_b;
    reg [2:0] operation;
    wire [31:0] result;
    wire done, busy;

    // Instantiate accelerator
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

    // Clock: 10ns period
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Track pass/fail
    integer test_pass, test_fail;

    // =========================================================================
    // Task: Issue a command and wait for done
    // =========================================================================
    task issue_cmd;
        input [2:0] op;
        input [31:0] op_a;
        input [31:0] op_b;
        begin
            // Setup signals on negedge (before engine samples on posedge)
            @(negedge clk);
            operation = op;
            operand_a = op_a;
            operand_b = op_b;
            start = 1;

            // Engine samples at next posedge, processes command
            @(posedge clk);
            #1;  // small delta to let NBA settle
            start = 0;

            // Wait for done (with timeout)
            // For fast ops (SETN/LOAD/READ), done pulses 1 cycle after start
            repeat (4000) begin
                if (done) begin
                    disable issue_cmd;
                end
                @(posedge clk);
                #1;  // let NBA settle before checking done
            end
            $display("  ERROR: Timeout waiting for done! op=%b", op);
            test_fail = test_fail + 1;
        end
    endtask

    // =========================================================================
    // Test vectors (module-level to avoid unpacked array task ports)
    // =========================================================================
    reg [31:0] samples [0:63];
    reg [31:0] expected [0:63];

    integer i;
    reg [31:0] got;
    reg all_match;

    // FP16 tolerance check: ±1 LSB per half-word
    reg [15:0] got_real, got_imag, exp_real, exp_imag;
    reg [15:0] diff_real, diff_imag;
    reg within_tol;

    // =========================================================================
    // Main test sequence
    // =========================================================================
    initial begin
        $dumpfile("build/tb_fft_accel_standalone.vcd");
        $dumpvars(0, tb_fft_accel_standalone);

        $display("=== FFT Accelerator Standalone Test (Modular N-Point) ===");
        test_pass = 0;
        test_fail = 0;

        // Reset
        rst_n = 0;
        start = 0;
        operand_a = 32'h0;
        operand_b = 32'h0;
        operation = 3'h0;
        #20;
        rst_n = 1;
        #10;

        // ==================================================================
        // Test 1: 4-point FFT  [36, 22, 45, 15]
        // ==================================================================
        $display("\n--- Test 1: 4-Point FFT ---");

        // Initialize arrays
        for (i = 0; i < 64; i = i + 1) begin
            samples[i] = 32'h0;
            expected[i] = 32'h0;
        end

        samples[0] = 32'h50800000;  // 36 + 0j
        samples[1] = 32'h4D800000;  // 22 + 0j
        samples[2] = 32'h51A00000;  // 45 + 0j
        samples[3] = 32'h4B800000;  // 15 + 0j

        expected[0] = 32'h57600000;  // 118 + 0j
        expected[1] = 32'hC880C700;  // -9 - 7j
        expected[2] = 32'h51800000;  // 44 + 0j
        expected[3] = 32'hC8804700;  // -9 + 7j

        // 1. Set FFT size
        $display("  Setting N=4");
        issue_cmd(3'b000, 32'd4, 32'h0);  // FFT.SETN

        // 2. Load samples
        for (i = 0; i < 4; i = i + 1) begin
            issue_cmd(3'b001, samples[i], i);  // FFT.LOAD
        end
        $display("  Loaded 4 samples");

        // 3. Execute FFT
        $display("  Executing FFT...");
        issue_cmd(3'b010, 32'h0, 32'h0);  // FFT.EXEC
        $display("  FFT complete!");

        // 4. Read and verify (±1 LSB tolerance per FP16 half)
        all_match = 1;
        for (i = 0; i < 4; i = i + 1) begin
            issue_cmd(3'b011, i, 32'h0);  // FFT.READ
            got = result;
            got_real = got[31:16]; got_imag = got[15:0];
            exp_real = expected[i][31:16]; exp_imag = expected[i][15:0];
            diff_real = (got_real > exp_real) ? got_real - exp_real : exp_real - got_real;
            diff_imag = (got_imag > exp_imag) ? got_imag - exp_imag : exp_imag - got_imag;
            within_tol = (diff_real <= 16'd1) && (diff_imag <= 16'd1);
            if (!within_tol) begin
                $display("  X[%0d] = %h  EXPECTED: %h  FAIL", i, got, expected[i]);
                all_match = 0;
                test_fail = test_fail + 1;
            end else begin
                if (got !== expected[i])
                    $display("  X[%0d] = %h  OK (tol, exp %h)", i, got, expected[i]);
                else
                    $display("  X[%0d] = %h  OK", i, got);
                test_pass = test_pass + 1;
            end
        end
        if (all_match)
            $display("  >>> 4-Point FFT: ALL PASSED <<<");
        else
            $display("  >>> 4-Point FFT: SOME FAILED <<<");

        #50;

        // ==================================================================
        // Test 2: 8-point FFT  [1, 2, 3, 4, 5, 6, 7, 8]
        // ==================================================================
        $display("\n--- Test 2: 8-Point FFT ---");

        for (i = 0; i < 64; i = i + 1) begin
            samples[i] = 32'h0;
            expected[i] = 32'h0;
        end

        samples[0] = 32'h3C000000;  // 1 + 0j
        samples[1] = 32'h40000000;  // 2 + 0j
        samples[2] = 32'h42000000;  // 3 + 0j
        samples[3] = 32'h44000000;  // 4 + 0j
        samples[4] = 32'h45000000;  // 5 + 0j
        samples[5] = 32'h46000000;  // 6 + 0j
        samples[6] = 32'h47000000;  // 7 + 0j
        samples[7] = 32'h48000000;  // 8 + 0j

        expected[0] = 32'h50800000;  // 36 + 0j
        expected[1] = 32'hC40048D4;  // -4 + 9.66j
        expected[2] = 32'hC4004400;  // -4 + 4j
        expected[3] = 32'hC4003EA1;  // -4 + 1.66j
        expected[4] = 32'hC4000000;  // -4 + 0j
        expected[5] = 32'hC400BEA1;  // -4 - 1.66j
        expected[6] = 32'hC400C400;  // -4 - 4j
        expected[7] = 32'hC400C8D4;  // -4 - 9.66j

        // 1. Set FFT size
        $display("  Setting N=8");
        issue_cmd(3'b000, 32'd8, 32'h0);

        // 2. Load samples
        for (i = 0; i < 8; i = i + 1) begin
            issue_cmd(3'b001, samples[i], i);
        end
        $display("  Loaded 8 samples");

        // 3. Execute
        $display("  Executing FFT...");
        issue_cmd(3'b010, 32'h0, 32'h0);
        $display("  FFT complete!");

        // 4. Read and verify (±1 LSB tolerance per FP16 half)
        all_match = 1;
        for (i = 0; i < 8; i = i + 1) begin
            issue_cmd(3'b011, i, 32'h0);
            got = result;
            got_real = got[31:16]; got_imag = got[15:0];
            exp_real = expected[i][31:16]; exp_imag = expected[i][15:0];
            diff_real = (got_real > exp_real) ? got_real - exp_real : exp_real - got_real;
            diff_imag = (got_imag > exp_imag) ? got_imag - exp_imag : exp_imag - got_imag;
            within_tol = (diff_real <= 16'd1) && (diff_imag <= 16'd1);
            if (!within_tol) begin
                $display("  X[%0d] = %h  EXPECTED: %h  FAIL", i, got, expected[i]);
                all_match = 0;
                test_fail = test_fail + 1;
            end else begin
                if (got !== expected[i])
                    $display("  X[%0d] = %h  OK (tol, exp %h)", i, got, expected[i]);
                else
                    $display("  X[%0d] = %h  OK", i, got);
                test_pass = test_pass + 1;
            end
        end
        if (all_match)
            $display("  >>> 8-Point FFT: ALL PASSED <<<");
        else
            $display("  >>> 8-Point FFT: SOME FAILED <<<");

        #50;

        // Summary
        $display("\n=== Test Summary ===");
        $display("  PASSED: %0d", test_pass);
        $display("  FAILED: %0d", test_fail);
        if (test_fail == 0)
            $display("  >>> ALL TESTS PASSED <<<");
        else
            $display("  >>> SOME TESTS FAILED <<<");

        $finish;
    end

    // Timeout
    initial begin
        #500000;
        $display("TIMEOUT!");
        $finish;
    end

endmodule
