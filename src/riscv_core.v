// RISC-V Core Top Module
// Integrates all pipeline stages and FFT accelerator

module riscv_core (
    input wire clk,
    input wire rst_n
    
    // External memory interface (optional)
    // output wire [31:0] ext_mem_addr,
    // output wire [31:0] ext_mem_wdata,
    // output wire ext_mem_we,
    // input wire [31:0] ext_mem_rdata
);

    // Instruction memory interface
    wire [31:0] imem_addr;
    wire [31:0] imem_data;
    
    instruction_memory #(
        .MEM_SIZE(4096),
        .MEM_INIT_FILE("")
    ) imem (
        .clk(clk),
        .addr(imem_addr),
        .instruction(imem_data)
    );
    
    // Data memory interface
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire [3:0] dmem_byte_enable;
    wire dmem_read, dmem_write;
    wire [31:0] dmem_rdata;
    
    data_memory #(
        .MEM_SIZE(8192)
    ) dmem (
        .clk(clk),
        .rst_n(rst_n),
        .addr(dmem_addr),
        .write_data(dmem_wdata),
        .byte_enable(dmem_byte_enable),
        .mem_read(dmem_read),
        .mem_write(dmem_write),
        .read_data(dmem_rdata)
    );
    
    // Pipeline control signals
    wire stall_if, stall_id, stall_ex, flush_if, flush_id, flush_ex;
    wire branch_taken;
    wire [31:0] branch_target;
    
    // Fetch stage signals
    wire [31:0] if_id_pc;
    wire [31:0] if_id_instruction;
    
    fetch_stage fetch (
        .clk(clk),
        .rst_n(rst_n),
        .stall(stall_if),
        .flush(flush_if || branch_taken),
        .branch_taken(branch_taken),
        .branch_target(branch_target),
        .pc(imem_addr),
        .instruction_in(imem_data),
        .if_id_pc(if_id_pc),
        .if_id_instruction(if_id_instruction)
    );
    
    // Register file signals
    wire [4:0] rs1_addr, rs2_addr;
    wire [31:0] rs1_data, rs2_data;
    wire [4:0] wb_rd;
    wire [31:0] wb_data;
    wire wb_we;
    
    register_file regfile (
        .clk(clk),
        .rst_n(rst_n),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .we(wb_we),
        .rd_addr(wb_rd),
        .rd_data(wb_data)
    );
    
    // Decode stage signals
    wire [31:0] id_ex_pc;
    wire [31:0] id_ex_rs1_data, id_ex_rs2_data;
    wire [31:0] id_ex_immediate;
    wire [4:0] id_ex_rd, id_ex_rs1, id_ex_rs2;
    wire [3:0] id_ex_alu_op;
    wire id_ex_alu_src, id_ex_mem_read, id_ex_mem_write;
    wire id_ex_reg_write, id_ex_branch, id_ex_jump;
    wire [2:0] id_ex_funct3;
    wire id_ex_is_custom;
    
    decode_stage decode (
        .clk(clk),
        .rst_n(rst_n),
        .if_id_pc(if_id_pc),
        .if_id_instruction(if_id_instruction),
        .stall(stall_id),
        .flush(flush_id),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .id_ex_pc(id_ex_pc),
        .id_ex_rs1_data(id_ex_rs1_data),
        .id_ex_rs2_data(id_ex_rs2_data),
        .id_ex_immediate(id_ex_immediate),
        .id_ex_rd(id_ex_rd),
        .id_ex_rs1(id_ex_rs1),
        .id_ex_rs2(id_ex_rs2),
        .id_ex_alu_op(id_ex_alu_op),
        .id_ex_alu_src(id_ex_alu_src),
        .id_ex_mem_read(id_ex_mem_read),
        .id_ex_mem_write(id_ex_mem_write),
        .id_ex_reg_write(id_ex_reg_write),
        .id_ex_branch(id_ex_branch),
        .id_ex_jump(id_ex_jump),
        .id_ex_funct3(id_ex_funct3),
        .id_ex_is_custom(id_ex_is_custom)
    );
    
    // FFT accelerator interface
    wire fft_start, fft_done, fft_busy;
    wire [31:0] fft_operand_a, fft_operand_b;
    wire [2:0] fft_operation;
    wire [31:0] fft_result;
    
    fft_accelerator fft_accel (
        .clk(clk),
        .rst_n(rst_n),
        .start(fft_start),
        .operand_a(fft_operand_a),
        .operand_b(fft_operand_b),
        .operation(fft_operation),
        .result(fft_result),
        .done(fft_done),
        .busy(fft_busy)
    );
    
    // Execute stage signals
    wire [31:0] ex_mem_alu_result, ex_mem_rs2_data;
    wire [4:0] ex_mem_rd;
    wire ex_mem_mem_read, ex_mem_mem_write, ex_mem_reg_write;
    wire [2:0] ex_mem_funct3;
    wire [1:0] forward_rs1_ex, forward_rs2_ex;
    
    execute_stage execute (
        .clk(clk),
        .rst_n(rst_n),
        .id_ex_pc(id_ex_pc),
        .id_ex_rs1_data(id_ex_rs1_data),
        .id_ex_rs2_data(id_ex_rs2_data),
        .id_ex_immediate(id_ex_immediate),
        .id_ex_rd(id_ex_rd),
        .id_ex_rs1(id_ex_rs1),
        .id_ex_rs2(id_ex_rs2),
        .id_ex_alu_op(id_ex_alu_op),
        .id_ex_alu_src(id_ex_alu_src),
        .id_ex_mem_read(id_ex_mem_read),
        .id_ex_mem_write(id_ex_mem_write),
        .id_ex_reg_write(id_ex_reg_write),
        .id_ex_branch(id_ex_branch),
        .id_ex_jump(id_ex_jump),
        .id_ex_funct3(id_ex_funct3),
        .id_ex_is_custom(id_ex_is_custom),
        .stall(stall_ex),
        .flush(flush_ex),
        .forward_mem_data(ex_mem_alu_result),
        .forward_wb_data(wb_data),
        .forward_rs1_sel(forward_rs1_ex),
        .forward_rs2_sel(forward_rs2_ex),
        .fft_start(fft_start),
        .fft_operand_a(fft_operand_a),
        .fft_operand_b(fft_operand_b),
        .fft_operation(fft_operation),
        .fft_result(fft_result),
        .fft_done(fft_done),
        .branch_taken(branch_taken),
        .branch_target(branch_target),
        .ex_mem_alu_result(ex_mem_alu_result),
        .ex_mem_rs2_data(ex_mem_rs2_data),
        .ex_mem_rd(ex_mem_rd),
        .ex_mem_mem_read(ex_mem_mem_read),
        .ex_mem_mem_write(ex_mem_mem_write),
        .ex_mem_reg_write(ex_mem_reg_write),
        .ex_mem_funct3(ex_mem_funct3)
    );
    
    // Memory stage signals
    wire [31:0] mem_wb_result;
    wire [4:0] mem_wb_rd;
    wire mem_wb_reg_write;
    
    memory_stage memory (
        .clk(clk),
        .rst_n(rst_n),
        .ex_mem_alu_result(ex_mem_alu_result),
        .ex_mem_rs2_data(ex_mem_rs2_data),
        .ex_mem_rd(ex_mem_rd),
        .ex_mem_mem_read(ex_mem_mem_read),
        .ex_mem_mem_write(ex_mem_mem_write),
        .ex_mem_reg_write(ex_mem_reg_write),
        .ex_mem_funct3(ex_mem_funct3),
        .stall(1'b0),
        .flush(1'b0),
        .mem_addr(dmem_addr),
        .mem_write_data(dmem_wdata),
        .mem_byte_enable(dmem_byte_enable),
        .mem_read(dmem_read),
        .mem_write(dmem_write),
        .mem_read_data(dmem_rdata),
        .mem_wb_result(mem_wb_result),
        .mem_wb_rd(mem_wb_rd),
        .mem_wb_reg_write(mem_wb_reg_write)
    );
    
    // Writeback stage
    writeback_stage writeback (
        .mem_wb_result(mem_wb_result),
        .mem_wb_rd(mem_wb_rd),
        .mem_wb_reg_write(mem_wb_reg_write),
        .wb_data(wb_data),
        .wb_rd(wb_rd),
        .wb_we(wb_we)
    );
    
    // Hazard detection unit
    hazard_unit hazard (
        .id_rs1(rs1_addr),
        .id_rs2(rs2_addr),
        .id_ex_rd(id_ex_rd),
        .id_ex_rs1(id_ex_rs1),  // Added
        .id_ex_rs2(id_ex_rs2),  // Added
        .id_ex_reg_write(id_ex_reg_write),
        .id_ex_mem_read(id_ex_mem_read),
        .id_ex_is_custom(id_ex_is_custom),
        .ex_mem_rd(ex_mem_rd),
        .ex_mem_reg_write(ex_mem_reg_write),
        .mem_wb_rd(mem_wb_rd),
        .mem_wb_reg_write(mem_wb_reg_write),
        .fft_busy(fft_busy),
        .fft_done(fft_done), // Connected
        .stall_if(stall_if),
        .stall_id(stall_id),
        .stall_ex(stall_ex), // Connected
        .flush_ex(flush_ex),
        .forward_rs1_ex(forward_rs1_ex),
        .forward_rs2_ex(forward_rs2_ex)
    );
    
    assign flush_if = 1'b0;
    assign flush_id = 1'b0;
    
    // External memory interface (unused in this design)
    // assign ext_mem_addr = 32'h0;
    // assign ext_mem_wdata = 32'h0;
    // assign ext_mem_we = 1'b0;

endmodule
