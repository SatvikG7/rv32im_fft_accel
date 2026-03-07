// Writeback Stage
// Writes results back to register file

module writeback_stage (
    // Input from memory stage
    input wire [31:0] mem_wb_result,
    input wire [4:0] mem_wb_rd,
    input wire mem_wb_reg_write,
    
    // Output to register file
    output wire [31:0] wb_data,
    output wire [4:0] wb_rd,
    output wire wb_we
);

    assign wb_data = mem_wb_result;
    assign wb_rd = mem_wb_rd;
    assign wb_we = mem_wb_reg_write;

endmodule
