// Instruction Fetch Stage
// Fetches instructions from instruction memory
// Manages PC (Program Counter)

module fetch_stage (
    input wire clk,
    input wire rst_n,
    
    // Control signals
    input wire stall,
    input wire flush,
    
    // Branch/Jump control
    input wire branch_taken,
    input wire [31:0] branch_target,
    
    // Instruction memory interface
    output reg [31:0] pc,
    input wire [31:0] instruction_in,
    
    // Output to decode stage
    output reg [31:0] if_id_pc,
    output reg [31:0] if_id_instruction
);

    reg [31:0] pc_next;
    
    // PC update logic
    always @(*) begin
        if (branch_taken) begin
            pc_next = branch_target;
        end else if (!stall) begin
            pc_next = pc + 4;
        end else begin
            pc_next = pc;
        end
    end
    
    // PC register
    always @(posedge clk) begin
        if (!rst_n) begin
            pc <= 32'h0;
        end else begin
            pc <= pc_next;
        end
    end
    
    // IF/ID pipeline register
    always @(posedge clk) begin
        if (!rst_n || flush) begin
            if_id_pc <= 32'h0;
            if_id_instruction <= 32'h00000013;  // NOP
        end else if (!stall) begin
            if_id_pc <= pc;
            if_id_instruction <= instruction_in;
        end
    end

endmodule
