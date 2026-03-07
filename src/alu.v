// RISC-V ALU
// Supports all RV32I arithmetic and logic operations

module alu (
    input wire [31:0] operand_a,
    input wire [31:0] operand_b,
    input wire [3:0] alu_op,
    output reg [31:0] result,
    output wire zero,
    output wire negative
);

    // ALU operation codes
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_SLL  = 4'b0010;  // Shift left logical
    localparam ALU_SLT  = 4'b0011;  // Set less than (signed)
    localparam ALU_SLTU = 4'b0100;  // Set less than unsigned
    localparam ALU_XOR  = 4'b0101;
    localparam ALU_SRL  = 4'b0110;  // Shift right logical
    localparam ALU_SRA  = 4'b0111;  // Shift right arithmetic
    localparam ALU_OR   = 4'b1000;
    localparam ALU_AND  = 4'b1001;
    
    // ALU operation
    always @(*) begin
        case (alu_op)
            ALU_ADD:  result = operand_a + operand_b;
            ALU_SUB:  result = operand_a - operand_b;
            ALU_SLL:  result = operand_a << operand_b[4:0];
            ALU_SLT:  result = ($signed(operand_a) < $signed(operand_b)) ? 32'h1 : 32'h0;
            ALU_SLTU: result = (operand_a < operand_b) ? 32'h1 : 32'h0;
            ALU_XOR:  result = operand_a ^ operand_b;
            ALU_SRL:  result = operand_a >> operand_b[4:0];
            ALU_SRA:  result = $signed(operand_a) >>> operand_b[4:0];
            ALU_OR:   result = operand_a | operand_b;
            ALU_AND:  result = operand_a & operand_b;
            default:  result = 32'h0;
        endcase
    end
    
    // Status flags
    assign zero = (result == 32'h0);
    assign negative = result[31];

endmodule
