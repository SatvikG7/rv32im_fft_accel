// RISC-V Register File
// 32 general-purpose registers (x0-x31)
// x0 is hardwired to 0
// Dual read ports, single write port

module register_file (
    input wire clk,
    input wire rst_n,
    
    // Read ports
    input wire [4:0] rs1_addr,
    input wire [4:0] rs2_addr,
    output wire [31:0] rs1_data,
    output wire [31:0] rs2_data,
    
    // Write port
    input wire we,
    input wire [4:0] rd_addr,
    input wire [31:0] rd_data
);

    // Register array (x1-x31, x0 is always 0)
    reg [31:0] registers [1:31];
    
    integer i;
    
    // Reset logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 1; i < 32; i = i + 1) begin
                registers[i] <= 32'h0;
            end
        end else if (we && rd_addr != 5'h0) begin
            // Write to register (skip x0)
            registers[rd_addr] <= rd_data;
        end
    end
    
    // Read logic (combinational)
    // x0 always reads as 0. Implement write-through internal forwarding
    assign rs1_data = (rs1_addr == 5'h0) ? 32'h0 : 
                      (we && (rd_addr == rs1_addr)) ? rd_data : 
                      registers[rs1_addr];
    assign rs2_data = (rs2_addr == 5'h0) ? 32'h0 : 
                      (we && (rd_addr == rs2_addr)) ? rd_data : 
                      registers[rs2_addr];

endmodule
