// Execute Stage
// Performs ALU operations, branch resolution
// Dispatches custom FFT instructions to accelerator

module execute_stage (
    input wire clk,
    input wire rst_n,
    
    // Input from decode stage
    input wire [31:0] id_ex_pc,
    input wire [31:0] id_ex_rs1_data,
    input wire [31:0] id_ex_rs2_data,
    input wire [31:0] id_ex_immediate,
    input wire [4:0] id_ex_rd,
    input wire [4:0] id_ex_rs1,
    input wire [4:0] id_ex_rs2,
    input wire [3:0] id_ex_alu_op,
    input wire id_ex_alu_src,
    input wire id_ex_mem_read,
    input wire id_ex_mem_write,
    input wire id_ex_reg_write,
    input wire id_ex_branch,
    input wire id_ex_jump,
    input wire [2:0] id_ex_funct3,
    input wire id_ex_is_custom,
    
    // Control signals
    input wire stall,
    input wire flush,
    
    // Forwarding inputs
    input wire [31:0] forward_mem_data,
    input wire [31:0] forward_wb_data,
    input wire [1:0] forward_rs1_sel,
    input wire [1:0] forward_rs2_sel,
    
    // FFT accelerator interface
    output reg fft_start,
    output reg [31:0] fft_operand_a,
    output reg [31:0] fft_operand_b,
    output reg [2:0] fft_operation,
    input wire [31:0] fft_result,
    input wire fft_done,
    
    // Branch control output
    output reg branch_taken,
    output reg [31:0] branch_target,
    
    // Output to memory stage
    output reg [31:0] ex_mem_alu_result,
    output reg [31:0] ex_mem_rs2_data,
    output reg [4:0] ex_mem_rd,
    output reg ex_mem_mem_read,
    output reg ex_mem_mem_write,
    output reg ex_mem_reg_write,
    output reg [2:0] ex_mem_funct3
);

    // Forwarding multiplexers
    reg [31:0] rs1_forwarded;
    reg [31:0] rs2_forwarded;
    
    always @(*) begin
        case (forward_rs1_sel)
            2'b00: rs1_forwarded = id_ex_rs1_data;
            2'b01: rs1_forwarded = forward_mem_data;
            2'b10: rs1_forwarded = forward_wb_data;
            default: rs1_forwarded = id_ex_rs1_data;
        endcase
        
        case (forward_rs2_sel)
            2'b00: rs2_forwarded = id_ex_rs2_data;
            2'b01: rs2_forwarded = forward_mem_data;
            2'b10: rs2_forwarded = forward_wb_data;
            default: rs2_forwarded = id_ex_rs2_data;
        endcase
    end
    
    // ALU operand selection
    wire [31:0] alu_operand_a;
    wire [31:0] alu_operand_b;
    
    assign alu_operand_a = rs1_forwarded;
    assign alu_operand_b = id_ex_alu_src ? id_ex_immediate : rs2_forwarded;
    
    // ALU instantiation
    wire [31:0] alu_result;
    wire alu_zero, alu_negative;
    
    alu alu_inst (
        .operand_a(alu_operand_a),
        .operand_b(alu_operand_b),
        .alu_op(id_ex_alu_op),
        .result(alu_result),
        .zero(alu_zero),
        .negative(alu_negative)
    );
    
    // Branch decision logic
    reg branch_condition;
    
    always @(*) begin
        case (id_ex_funct3)
            3'b000: branch_condition = alu_zero;                    // BEQ
            3'b001: branch_condition = !alu_zero;                   // BNE
            3'b100: branch_condition = alu_negative;                // BLT
            3'b101: branch_condition = !alu_negative && !alu_zero;  // BGE
            3'b110: branch_condition = alu_result[0];               // BLTU
            3'b111: branch_condition = !alu_result[0];              // BGEU
            default: branch_condition = 1'b0;
        endcase
    end
    
    always @(*) begin
        branch_taken = (id_ex_branch && branch_condition) || id_ex_jump;
        if (id_ex_jump && id_ex_alu_src) begin
            // JALR: target = (rs1 + imm) & ~1
            branch_target = {alu_result[31:1], 1'b0};
        end else if (id_ex_jump || id_ex_branch) begin
            // JAL or branch: target = PC + imm
            branch_target = id_ex_pc + id_ex_immediate;
        end else begin
            branch_target = 32'h0;
        end
    end
    
    // Custom FFT instruction handling
    // Only pulse fft_start once per instruction (when entering execute stage)
    reg fft_started;  // Track if we've already started FFT for this instruction
    
    always @(posedge clk) begin
        if (!rst_n) begin
            fft_started <= 1'b0;
        end else if (!id_ex_is_custom) begin
            fft_started <= 1'b0;  // Reset when no custom instruction
        end else if (fft_done) begin
            fft_started <= 1'b0;  // Reset when operation completes
        end else if (id_ex_is_custom && !fft_started) begin
            fft_started <= 1'b1;  // Mark as started
        end
    end
    
    always @(*) begin
        fft_operand_a = 32'h0;
        fft_operand_b = 32'h0;
        fft_operation = 3'h0;
        fft_start = 1'b0;
        
        if (id_ex_is_custom) begin
            fft_operand_a = rs1_forwarded;
            fft_operand_b = rs2_forwarded;
            fft_operation = id_ex_funct3;
            // Only pulse start when we haven't started yet
            fft_start = !fft_started;
        end
    end
    
    // FFT result capture - latch result when done
    reg [31:0] fft_result_latched;
    reg fft_result_valid;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            fft_result_latched <= 32'h0;
            fft_result_valid <= 1'b0;
        end else if (fft_done) begin
            fft_result_latched <= fft_result;
            fft_result_valid <= 1'b1;
        end else if (!stall && fft_result_valid) begin
            // Clear valid flag when result is consumed
            fft_result_valid <= 1'b0;
        end
    end
    
    // Result selection
    reg [31:0] execute_result;
    
    always @(*) begin
        if (id_ex_is_custom && (fft_done || fft_result_valid)) begin
            execute_result = fft_done ? fft_result : fft_result_latched;
        end else if (id_ex_jump) begin
            execute_result = id_ex_pc + 4;  // Return address for JAL/JALR
        end else begin
            execute_result = alu_result;
        end
    end
    
    // Debug (comment out for production)
    // always @(posedge clk) begin
    //     if (id_ex_is_custom) 
    //         $display("EXEC: Custom=%b Done=%b Stall=%b Valid=%b Started=%b Result=%h fft_result=%h Latched=%h", 
    //                  id_ex_is_custom, fft_done, stall, fft_result_valid, fft_started, execute_result, fft_result, fft_result_latched);
    // end
    
    // EX/MEM pipeline register
    always @(posedge clk) begin
        if (!rst_n || flush) begin
            ex_mem_alu_result <= 32'h0;
            ex_mem_rs2_data <= 32'h0;
            ex_mem_rd <= 5'h0;
            ex_mem_mem_read <= 1'b0;
            ex_mem_mem_write <= 1'b0;
            ex_mem_reg_write <= 1'b0;
            ex_mem_funct3 <= 3'h0;
        end else if (!stall) begin
            ex_mem_alu_result <= execute_result;
            ex_mem_rs2_data <= rs2_forwarded;
            ex_mem_rd <= id_ex_rd;
            ex_mem_mem_read <= id_ex_mem_read;
            ex_mem_mem_write <= id_ex_mem_write;
            ex_mem_reg_write <= id_ex_reg_write;
            ex_mem_funct3 <= id_ex_funct3;
        end
    end

endmodule
