// FP16 Multiplication Unit
// Simplified IEEE 754 half-precision (1 sign, 5 exp, 10 mantissa)
// Does not handle denormals, NaN, or infinity

module fp16_mul (
    input wire [15:0] a,
    input wire [15:0] b,
    output reg [15:0] result
);

    // Extract fields
    wire sign_a = a[15];
    wire sign_b = b[15];
    wire [4:0] exp_a = a[14:10];
    wire [4:0] exp_b = b[14:10];
    wire [9:0] mant_a = a[9:0];
    wire [9:0] mant_b = b[9:0];
    
    // Check for zero
    wire a_zero = (a[14:0] == 15'h0);
    wire b_zero = (b[14:0] == 15'h0);
    
    // Result sign
    wire sign_result = sign_a ^ sign_b;
    
    // Add implicit leading 1
    wire [10:0] frac_a = {1'b1, mant_a};
    wire [10:0] frac_b = {1'b1, mant_b};
    
    // Multiply fractions (11 bits * 11 bits = 22 bits)
    wire [21:0] frac_product = frac_a * frac_b;
    
    // Add exponents (subtract bias)
    // Bias for FP16 is 15
    wire [5:0] exp_sum = exp_a + exp_b - 5'd15;
    
    // Normalize result
    reg [4:0] exp_result;
    reg [9:0] mant_result;
    
    always @(*) begin
        if (a_zero || b_zero) begin
            // Result is zero
            result = 16'h0;
        end else if (frac_product[21]) begin
            // Product is >= 2.0, need to shift right
            exp_result = exp_sum + 1;
            mant_result = frac_product[20:11];
            result = {sign_result, exp_result, mant_result};
        end else begin
            // Product is in [1.0, 2.0), already normalized
            exp_result = exp_sum[4:0];
            mant_result = frac_product[19:10];
            result = {sign_result, exp_result, mant_result};
        end
    end

endmodule
