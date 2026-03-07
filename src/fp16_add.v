// FP16 Addition/Subtraction Unit
// Simplified IEEE 754 half-precision (1 sign, 5 exp, 10 mantissa)
// Does not handle denormals, NaN, or infinity

module fp16_add (
    input wire [15:0] a,
    input wire [15:0] b,
    input wire sub,  // 0: add, 1: subtract
    output reg [15:0] result
);

    // Extract fields
    wire [14:0] abs_a = a[14:0];
    wire [14:0] abs_b = b[14:0];
    wire a_zero = (abs_a == 15'h0);
    wire b_zero = (abs_b == 15'h0);
    
    wire sign_a = a[15];
    wire sign_b = sub ? ~b[15] : b[15];  // Flip sign for subtraction
    wire [4:0] exp_a = a[14:10];
    wire [4:0] exp_b = b[14:10];
    wire [9:0] mant_a = a[9:0];
    wire [9:0] mant_b = b[9:0];
    
    // Add implicit leading 1 (normalized numbers only)
    wire [10:0] frac_a = {1'b1, mant_a};
    wire [10:0] frac_b = {1'b1, mant_b};
    
    // Determine larger operand
    wire a_larger = (exp_a > exp_b) || ((exp_a == exp_b) && (mant_a >= mant_b));
    
    // Align exponents
    wire [4:0] exp_large = a_larger ? exp_a : exp_b;
    wire [4:0] exp_small = a_larger ? exp_b : exp_a;
    wire [4:0] exp_diff = exp_large - exp_small;
    
    wire [10:0] frac_large = a_larger ? frac_a : frac_b;
    wire [10:0] frac_small = a_larger ? frac_b : frac_a;
    wire sign_large = a_larger ? sign_a : sign_b;
    wire sign_small = a_larger ? sign_b : sign_a;
    
    // Shift smaller fraction
    wire [10:0] frac_small_shifted = frac_small >> exp_diff;
    
    // Add or subtract based on signs
    reg [11:0] frac_sum;
    reg sign_result;
    
    always @(*) begin
        if (sign_large == sign_small) begin
            // Same sign: add
            frac_sum = frac_large + frac_small_shifted;
            sign_result = sign_large;
        end else begin
            // Different signs: subtract
            frac_sum = frac_large - frac_small_shifted;
            sign_result = sign_large;
        end
    end
    
    // Normalize result
    reg [4:0] exp_result;
    reg [9:0] mant_result;
    
    always @(*) begin
        if (a_zero && b_zero) begin
            result = 16'h0;
        end else if (a_zero) begin
            result = {sign_b, exp_b, mant_b};
        end else if (b_zero) begin
            result = {sign_a, exp_a, mant_a};
        end else if (frac_sum == 12'h0) begin
            // Result is zero
            result = 16'h0;
        end else if (frac_sum[11]) begin
            // Overflow: shift right
            exp_result = exp_large + 1;
            mant_result = frac_sum[10:1];
            result = {sign_result, exp_result, mant_result};
        end else if (frac_sum[10]) begin
            // Already normalized
            exp_result = exp_large;
            mant_result = frac_sum[9:0];
            result = {sign_result, exp_result, mant_result};
        end else begin
            // Need to normalize left (simplified: shift by 1)
            exp_result = exp_large - 1;
            mant_result = frac_sum[9:0] << 1;
            result = {sign_result, exp_result, mant_result};
        end
    end

endmodule
