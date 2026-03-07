// Memory Stage
// Handles memory read/write operations
// Formats data based on access size (byte, halfword, word)

module memory_stage (
    input wire clk,
    input wire rst_n,
    
    // Input from execute stage
    input wire [31:0] ex_mem_alu_result,
    input wire [31:0] ex_mem_rs2_data,
    input wire [4:0] ex_mem_rd,
    input wire ex_mem_mem_read,
    input wire ex_mem_mem_write,
    input wire ex_mem_reg_write,
    input wire [2:0] ex_mem_funct3,
    
    // Control signals
    input wire stall,
    input wire flush,
    
    // Data memory interface
    output wire [31:0] mem_addr,
    output reg [31:0] mem_write_data,
    output reg [3:0] mem_byte_enable,
    output wire mem_read,
    output wire mem_write,
    input wire [31:0] mem_read_data,
    
    // Output to writeback stage
    output reg [31:0] mem_wb_result,
    output reg [4:0] mem_wb_rd,
    output reg mem_wb_reg_write
);

    assign mem_addr = ex_mem_alu_result;
    assign mem_read = ex_mem_mem_read;
    assign mem_write = ex_mem_mem_write;
    
    // Memory write data formatting
    always @(*) begin
        case (ex_mem_funct3[1:0])
            2'b00: begin  // Byte
                mem_write_data = {4{ex_mem_rs2_data[7:0]}};
                case (ex_mem_alu_result[1:0])
                    2'b00: mem_byte_enable = 4'b0001;
                    2'b01: mem_byte_enable = 4'b0010;
                    2'b10: mem_byte_enable = 4'b0100;
                    2'b11: mem_byte_enable = 4'b1000;
                endcase
            end
            2'b01: begin  // Halfword
                mem_write_data = {2{ex_mem_rs2_data[15:0]}};
                mem_byte_enable = ex_mem_alu_result[1] ? 4'b1100 : 4'b0011;
            end
            default: begin  // Word
                mem_write_data = ex_mem_rs2_data;
                mem_byte_enable = 4'b1111;
            end
        endcase
    end
    
    // Memory read data formatting
    reg [31:0] formatted_read_data;
    
    always @(*) begin
        case (ex_mem_funct3)
            3'b000: begin  // LB (load byte signed)
                case (ex_mem_alu_result[1:0])
                    2'b00: formatted_read_data = {{24{mem_read_data[7]}}, mem_read_data[7:0]};
                    2'b01: formatted_read_data = {{24{mem_read_data[15]}}, mem_read_data[15:8]};
                    2'b10: formatted_read_data = {{24{mem_read_data[23]}}, mem_read_data[23:16]};
                    2'b11: formatted_read_data = {{24{mem_read_data[31]}}, mem_read_data[31:24]};
                endcase
            end
            3'b001: begin  // LH (load halfword signed)
                formatted_read_data = ex_mem_alu_result[1] ? 
                    {{16{mem_read_data[31]}}, mem_read_data[31:16]} :
                    {{16{mem_read_data[15]}}, mem_read_data[15:0]};
            end
            3'b010: begin  // LW (load word)
                formatted_read_data = mem_read_data;
            end
            3'b100: begin  // LBU (load byte unsigned)
                case (ex_mem_alu_result[1:0])
                    2'b00: formatted_read_data = {24'h0, mem_read_data[7:0]};
                    2'b01: formatted_read_data = {24'h0, mem_read_data[15:8]};
                    2'b10: formatted_read_data = {24'h0, mem_read_data[23:16]};
                    2'b11: formatted_read_data = {24'h0, mem_read_data[31:24]};
                endcase
            end
            3'b101: begin  // LHU (load halfword unsigned)
                formatted_read_data = ex_mem_alu_result[1] ? 
                    {16'h0, mem_read_data[31:16]} :
                    {16'h0, mem_read_data[15:0]};
            end
            default: formatted_read_data = mem_read_data;
        endcase
    end
    
    // Result selection
    reg [31:0] memory_result;
    
    always @(*) begin
        if (ex_mem_mem_read) begin
            memory_result = formatted_read_data;
        end else begin
            memory_result = ex_mem_alu_result;
        end
    end
    
    // MEM/WB pipeline register (synchronous reset for synthesis compatibility)
    always @(posedge clk) begin
        if (!rst_n || flush) begin
            mem_wb_result <= 32'h0;
            mem_wb_rd <= 5'h0;
            mem_wb_reg_write <= 1'b0;
        end else if (!stall) begin
            mem_wb_result <= memory_result;
            mem_wb_rd <= ex_mem_rd;
            mem_wb_reg_write <= ex_mem_reg_write;
        end
    end

endmodule
