// FFT Butterfly Unit
// Computes radix-2 butterfly: 
//   out1 = A + W*B
//   out2 = A - W*B
// Where W is the twiddle factor

module butterfly_unit (
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // Input: two complex numbers A and B, and twiddle W
    input wire [15:0] a_real,
    input wire [15:0] a_imag,
    input wire [15:0] b_real,
    input wire [15:0] b_imag,
    input wire [15:0] w_real,
    input wire [15:0] w_imag,
    
    // Output: two complex numbers
    output reg [15:0] out1_real,
    output reg [15:0] out1_imag,
    output reg [15:0] out2_real,
    output reg [15:0] out2_imag,
    output reg done
);

    // State machine
    localparam IDLE = 2'b00;
    localparam MULTIPLY = 2'b01;
    localparam ADD_SUB = 2'b10;
    localparam FINISH = 2'b11;
    
    reg [1:0] state;
    reg [1:0] cycle_count;
    
    // W * B computation
    wire [15:0] wb_real, wb_imag;
    wire cmul_done;
    reg cmul_start;
    
    complex_mul_unit cmul (
        .clk(clk),
        .rst_n(rst_n),
        .start(cmul_start),
        .a_real(w_real),
        .a_imag(w_imag),
        .b_real(b_real),
        .b_imag(b_imag),
        .result_real(wb_real),
        .result_imag(wb_imag),
        .done(cmul_done)
    );
    
    // A + WB and A - WB
    wire [15:0] add_real, add_imag, sub_real, sub_imag;
    
    fp16_add add_r (.a(a_real), .b(wb_real), .sub(1'b0), .result(add_real));
    fp16_add add_i (.a(a_imag), .b(wb_imag), .sub(1'b0), .result(add_imag));
    fp16_add sub_r (.a(a_real), .b(wb_real), .sub(1'b1), .result(sub_real));
    fp16_add sub_i (.a(a_imag), .b(wb_imag), .sub(1'b1), .result(sub_imag));
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 2'h0;
            cmul_start <= 1'b0;
            done <= 1'b0;
            out1_real <= 16'h0;
            out1_imag <= 16'h0;
            out2_real <= 16'h0;
            out2_imag <= 16'h0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cmul_start <= 1'b0;
                    if (start) begin
                        cmul_start <= 1'b1;
                        state <= MULTIPLY;
                        cycle_count <= 2'h0;
                    end
                end
                
                MULTIPLY: begin
                    cmul_start <= 1'b0;
                    if (cmul_done) begin
                        state <= ADD_SUB;
                    end
                end
                
                ADD_SUB: begin
                    // Compute A + WB and A - WB
                    out1_real <= add_real;
                    out1_imag <= add_imag;
                    out2_real <= sub_real;
                    out2_imag <= sub_imag;
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
