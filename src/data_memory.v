// Data Memory (RAM)
// Single-cycle read/write access
// Supports byte, halfword, and word accesses

module data_memory #(
    parameter MEM_SIZE = 8192  // 8KB data memory
) (
    input wire clk,
    input wire rst_n,
    
    // Memory interface
    input wire [31:0] addr,
    input wire [31:0] write_data,
    input wire [3:0] byte_enable,  // Byte write enable
    input wire mem_read,
    input wire mem_write,
    output reg [31:0] read_data
);

    // Memory array (byte-addressed)
    reg [7:0] mem [0:MEM_SIZE-1];
    
    integer i;
    
    // Reset memory
    initial begin
        for (i = 0; i < MEM_SIZE; i = i + 1) begin
            mem[i] = 8'h0;
        end
    end
    
    // Write logic
    always @(posedge clk) begin
        if (mem_write) begin
            if (byte_enable[0]) mem[addr]     <= write_data[7:0];
            if (byte_enable[1]) mem[addr + 1] <= write_data[15:8];
            if (byte_enable[2]) mem[addr + 2] <= write_data[23:16];
            if (byte_enable[3]) mem[addr + 3] <= write_data[31:24];
        end
    end
    
    // Read logic
    always @(*) begin
        if (mem_read) begin
            read_data = {mem[addr + 3], mem[addr + 2], mem[addr + 1], mem[addr]};
        end else begin
            read_data = 32'h0;
        end
    end

endmodule
