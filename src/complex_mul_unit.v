// Complex Multiplication Unit
// Computes (a + bi) * (c + di) = (ac - bd) + (ad + bc)i
// Uses FP16 arithmetic

module complex_mul_unit (
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // Input: two complex numbers in FP16
    // a_real + a_imag*i
    input wire [15:0] a_real,
    input wire [15:0] a_imag,
    // b_real + b_imag*i
    input wire [15:0] b_real,
    input wire [15:0] b_imag,
    
    // Output: result complex number
    output reg [15:0] result_real,
    output reg [15:0] result_imag,
    output reg done
);

    // State machine
    localparam IDLE = 2'b00;
    localparam COMPUTE = 2'b01;
    localparam FINISH = 2'b10;
    
    reg [1:0] state;
    
    // Intermediate products
    wire [15:0] ac, bd, ad, bc;
    
    // Instantiate multipliers
    fp16_mul mul_ac (.a(a_real), .b(b_real), .result(ac));
    fp16_mul mul_bd (.a(a_imag), .b(b_imag), .result(bd));
    fp16_mul mul_ad (.a(a_real), .b(b_imag), .result(ad));
    fp16_mul mul_bc (.a(a_imag), .b(b_real), .result(bc));
    
    // Instantiate adders/subtractors
    wire [15:0] real_part, imag_part;
    
    fp16_add add_real (.a(ac), .b(bd), .sub(1'b1), .result(real_part));  // ac - bd
    fp16_add add_imag (.a(ad), .b(bc), .sub(1'b0), .result(imag_part));  // ad + bc
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_real <= 16'h0;
            result_imag <= 16'h0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    // Computation happens combinationally
                    result_real <= real_part;
                    result_imag <= imag_part;
                    state <= FINISH;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
