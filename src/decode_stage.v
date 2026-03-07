// Instruction Decode Stage
// Decodes instructions, generates control signals
// Reads from register file
// Generates immediates

module decode_stage (
    input wire clk,
    input wire rst_n,
    
    // Input from fetch stage
    input wire [31:0] if_id_pc,
    input wire [31:0] if_id_instruction,
    
    // Control signals
    input wire stall,
    input wire flush,
    
    // Register file interface
    output wire [4:0] rs1_addr,
    output wire [4:0] rs2_addr,
    input wire [31:0] rs1_data,
    input wire [31:0] rs2_data,
    
    // Output to execute stage
    output reg [31:0] id_ex_pc,
    output reg [31:0] id_ex_rs1_data,
    output reg [31:0] id_ex_rs2_data,
    output reg [31:0] id_ex_immediate,
    output reg [4:0] id_ex_rd,
    output reg [4:0] id_ex_rs1,
    output reg [4:0] id_ex_rs2,
    output reg [3:0] id_ex_alu_op,
    output reg id_ex_alu_src,      // 0: rs2, 1: immediate
    output reg id_ex_mem_read,
    output reg id_ex_mem_write,
    output reg id_ex_reg_write,
    output reg id_ex_branch,
    output reg id_ex_jump,
    output reg [2:0] id_ex_funct3,
    output reg id_ex_is_custom     // Custom FFT instruction
);

    // Instruction fields
    wire [6:0] opcode = if_id_instruction[6:0];
    wire [4:0] rd = if_id_instruction[11:7];
    wire [2:0] funct3 = if_id_instruction[14:12];
    wire [4:0] rs1 = if_id_instruction[19:15];
    wire [4:0] rs2 = if_id_instruction[24:20];
    wire [6:0] funct7 = if_id_instruction[31:25];
    
    assign rs1_addr = rs1;
    assign rs2_addr = rs2;
    
    // Immediate generation
    reg [31:0] immediate;
    
    always @(*) begin
        case (opcode)
            7'b0010011, 7'b0000011, 7'b1100111: begin  // I-type
                immediate = {{20{if_id_instruction[31]}}, if_id_instruction[31:20]};
            end
            7'b0100011: begin  // S-type
                immediate = {{20{if_id_instruction[31]}}, if_id_instruction[31:25], if_id_instruction[11:7]};
            end
            7'b1100011: begin  // B-type
                immediate = {{19{if_id_instruction[31]}}, if_id_instruction[31], if_id_instruction[7], 
                             if_id_instruction[30:25], if_id_instruction[11:8], 1'b0};
            end
            7'b0110111, 7'b0010111: begin  // U-type
                immediate = {if_id_instruction[31:12], 12'h0};
            end
            7'b1101111: begin  // J-type
                immediate = {{11{if_id_instruction[31]}}, if_id_instruction[31], if_id_instruction[19:12],
                             if_id_instruction[20], if_id_instruction[30:21], 1'b0};
            end
            default: immediate = 32'h0;
        endcase
    end
    
    // Control signal generation
    reg [3:0] alu_op;
    reg alu_src, mem_read, mem_write, reg_write, branch, jump, is_custom;
    
    always @(*) begin
        // Defaults
        alu_op = 4'b0000;
        alu_src = 1'b0;
        mem_read = 1'b0;
        mem_write = 1'b0;
        reg_write = 1'b0;
        branch = 1'b0;
        jump = 1'b0;
        is_custom = 1'b0;
        
        case (opcode)
            7'b0110011: begin  // R-type
                reg_write = 1'b1;
                alu_src = 1'b0;
                case (funct3)
                    3'b000: alu_op = (funct7[5]) ? 4'b0001 : 4'b0000;  // SUB : ADD
                    3'b001: alu_op = 4'b0010;  // SLL
                    3'b010: alu_op = 4'b0011;  // SLT
                    3'b011: alu_op = 4'b0100;  // SLTU
                    3'b100: alu_op = 4'b0101;  // XOR
                    3'b101: alu_op = (funct7[5]) ? 4'b0111 : 4'b0110;  // SRA : SRL
                    3'b110: alu_op = 4'b1000;  // OR
                    3'b111: alu_op = 4'b1001;  // AND
                endcase
            end
            7'b0010011: begin  // I-type (arithmetic)
                reg_write = 1'b1;
                alu_src = 1'b1;
                case (funct3)
                    3'b000: alu_op = 4'b0000;  // ADDI
                    3'b010: alu_op = 4'b0011;  // SLTI
                    3'b011: alu_op = 4'b0100;  // SLTIU
                    3'b100: alu_op = 4'b0101;  // XORI
                    3'b110: alu_op = 4'b1000;  // ORI
                    3'b111: alu_op = 4'b1001;  // ANDI
                    3'b001: alu_op = 4'b0010;  // SLLI
                    3'b101: alu_op = (funct7[5]) ? 4'b0111 : 4'b0110;  // SRAI : SRLI
                endcase
            end
            7'b0000011: begin  // Load
                reg_write = 1'b1;
                alu_src = 1'b1;
                alu_op = 4'b0000;  // ADD for address calculation
                mem_read = 1'b1;
            end
            7'b0100011: begin  // Store
                alu_src = 1'b1;
                alu_op = 4'b0000;  // ADD for address calculation
                mem_write = 1'b1;
            end
            7'b1100011: begin  // Branch
                alu_src = 1'b0;
                alu_op = 4'b0001;  // SUB for comparison
                branch = 1'b1;
            end
            7'b1101111: begin  // JAL
                reg_write = 1'b1;
                jump = 1'b1;
            end
            7'b1100111: begin  // JALR
                reg_write = 1'b1;
                alu_src = 1'b1;
                alu_op = 4'b0000;
                jump = 1'b1;
            end
            7'b0110111: begin  // LUI
                reg_write = 1'b1;
                alu_src = 1'b1;
                alu_op = 4'b0000;
            end
            7'b0010111: begin  // AUIPC
                reg_write = 1'b1;
                alu_src = 1'b1;
                alu_op = 4'b0000;
            end
            7'b0001011: begin  // Custom-0 (FFT instructions)
                reg_write = 1'b1;
                is_custom = 1'b1;
            end
        endcase
    end
    
    // ID/EX pipeline register
    always @(posedge clk) begin
        if (!rst_n || flush) begin
            id_ex_pc <= 32'h0;
            id_ex_rs1_data <= 32'h0;
            id_ex_rs2_data <= 32'h0;
            id_ex_immediate <= 32'h0;
            id_ex_rd <= 5'h0;
            id_ex_rs1 <= 5'h0;
            id_ex_rs2 <= 5'h0;
            id_ex_alu_op <= 4'h0;
            id_ex_alu_src <= 1'b0;
            id_ex_mem_read <= 1'b0;
            id_ex_mem_write <= 1'b0;
            id_ex_reg_write <= 1'b0;
            id_ex_branch <= 1'b0;
            id_ex_jump <= 1'b0;
            id_ex_funct3 <= 3'h0;
            id_ex_is_custom <= 1'b0;
        end else if (!stall) begin
            id_ex_pc <= if_id_pc;
            id_ex_rs1_data <= rs1_data;
            id_ex_rs2_data <= rs2_data;
            id_ex_immediate <= immediate;
            id_ex_rd <= rd;
            id_ex_rs1 <= rs1;
            id_ex_rs2 <= rs2;
            id_ex_alu_op <= alu_op;
            id_ex_alu_src <= alu_src;
            id_ex_mem_read <= mem_read;
            id_ex_mem_write <= mem_write;
            id_ex_reg_write <= reg_write;
            id_ex_branch <= branch;
            id_ex_jump <= jump;
            id_ex_funct3 <= funct3;
            id_ex_is_custom <= is_custom;
        end
    end

endmodule
