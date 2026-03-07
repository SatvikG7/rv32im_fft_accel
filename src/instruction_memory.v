// Instruction Memory (ROM)
// Single-cycle read access

module instruction_memory #(
    parameter MEM_SIZE = 4096,  // 4KB instruction memory
    parameter MEM_INIT_FILE = ""
) (
    input wire clk,
    input wire [31:0] addr,
    output reg [31:0] instruction
);

    // Memory array (word-addressed)
    reg [31:0] mem [0:MEM_SIZE/4-1];
    
    // Initialize memory
    integer i;
    initial begin
        if (MEM_INIT_FILE != "") begin
            $readmemh(MEM_INIT_FILE, mem);
        end else begin
            // Default: fill with NOPs (addi x0, x0, 0)
            for (i = 0; i < MEM_SIZE/4; i = i + 1) begin
                mem[i] = 32'h00000013;
            end
        end
    end
    
    // Read instruction (word-aligned)
    always @(posedge clk) begin
        instruction <= mem[addr[31:2]];
    end

endmodule
