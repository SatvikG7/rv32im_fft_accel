// FFT Accelerator Top Module
// Interfaces with processor and coordinates FFT operations

module fft_accelerator (
    input wire clk,
    input wire rst_n,
    
    // Processor interface
    input wire start,
    input wire [31:0] operand_a,  // Contains two FP16 values
    input wire [31:0] operand_b,  // Contains two FP16 values or twiddle
    input wire [2:0] operation,   // 000: butterfly, 001: complex mul
    
    output reg [31:0] result,     // Two FP16 results (now combinational)
    output reg done,
    output reg busy
);

    // Debug (comment out for production)
    // always @(posedge clk) begin
    //     if (start)
    //         $display("FFT_ACCEL: Start! opA=%h opB=%h operation=%b", operand_a, operand_b, operation);
    // end

    // Extract FP16 values from 32-bit operands
    wire [15:0] a_real = operand_a[31:16];
    wire [15:0] a_imag = operand_a[15:0];
    wire [15:0] b_real = operand_b[31:16];
    wire [15:0] b_imag = operand_b[15:0];
    
    // Butterfly unit signals
    reg butterfly_start;
    wire [15:0] butterfly_out1_real, butterfly_out1_imag;
    wire [15:0] butterfly_out2_real, butterfly_out2_imag;
    wire butterfly_done;
    
    // For butterfly, we need twiddle factors
    // Simplified: use operand_b as twiddle for now
    wire [15:0] w_real = b_real;
    wire [15:0] w_imag = b_imag;
    
    butterfly_unit butterfly (
        .clk(clk),
        .rst_n(rst_n),
        .start(butterfly_start),
        .a_real(a_real),
        .a_imag(a_imag),
        .b_real(16'h3C00),  // Simplified: B = 1.0 for now
        .b_imag(16'h0000),
        .w_real(w_real),
        .w_imag(w_imag),
        .out1_real(butterfly_out1_real),
        .out1_imag(butterfly_out1_imag),
        .out2_real(butterfly_out2_real),
        .out2_imag(butterfly_out2_imag),
        .done(butterfly_done)
    );
    
    // Complex multiply unit signals
    reg cmul_start;
    wire [15:0] cmul_result_real, cmul_result_imag;
    wire cmul_done;
    
    complex_mul_unit cmul (
        .clk(clk),
        .rst_n(rst_n),
        .start(cmul_start),
        .a_real(a_real),
        .a_imag(a_imag),
        .b_real(b_real),
        .b_imag(b_imag),
        .result_real(cmul_result_real),
        .result_imag(cmul_result_imag),
        .done(cmul_done)
    );
    
    // Control logic
    reg [31:0] result_latched;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            butterfly_start <= 1'b0;
            cmul_start <= 1'b0;
            busy <= 1'b0;
            result_latched <= 32'h0;
        end else begin
            if (start && !busy) begin
                busy <= 1'b1;
                
                case (operation)
                    3'b000: begin  // Butterfly operation (Add)
                        butterfly_start <= 1'b1;
                    end
                    3'b010: begin  // Butterfly operation (Sub)
                        butterfly_start <= 1'b1;
                    end
                    3'b001: begin  // Complex multiply
                        cmul_start <= 1'b1;
                    end
                    default: begin
                        busy <= 1'b0;
                        done <= 1'b1;
                    end
                endcase
            end else begin
                butterfly_start <= 1'b0;
                cmul_start <= 1'b0;
            end
            
    // Check for completion and latch result
            if (butterfly_done) begin
                if (operation[1])
                    result_latched <= {butterfly_out2_real, butterfly_out2_imag};
                else
                    result_latched <= {butterfly_out1_real, butterfly_out1_imag};
                busy <= 1'b0;
            end else if (cmul_done) begin
                result_latched <= {cmul_result_real, cmul_result_imag};
                busy <= 1'b0;
            end
        end
    end
    
    // Output result - combinational from latched value, with priority to fresh results
    always @(*) begin
        done = butterfly_done || cmul_done;
        
        if (butterfly_done) begin
            if (operation[1]) // operation == 3'b010 (sub)
                result = {butterfly_out2_real, butterfly_out2_imag};
            else              // operation == 3'b000 (add)
                result = {butterfly_out1_real, butterfly_out1_imag};
        end else if (cmul_done) begin
            result = {cmul_result_real, cmul_result_imag};
        end else begin
            result = result_latched;
        end
    end

endmodule
