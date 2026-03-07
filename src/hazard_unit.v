// Hazard Detection and Forwarding Unit
// Detects data hazards and generates forwarding/stall signals

module hazard_unit (
    // Decode stage
    input wire [4:0] id_rs1,
    input wire [4:0] id_rs2,
    
    // Execute stage
    input wire [4:0] id_ex_rd,
    input wire [4:0] id_ex_rs1,  // Added
    input wire [4:0] id_ex_rs2,  // Added
    input wire id_ex_reg_write,
    input wire id_ex_mem_read,
    input wire id_ex_is_custom,
    
    // Memory stage
    input wire [4:0] ex_mem_rd,
    input wire ex_mem_reg_write,
    
    // Writeback stage
    input wire [4:0] mem_wb_rd,
    input wire mem_wb_reg_write,
    
    // FFT accelerator status
    input wire fft_busy,
    input wire fft_done,  // Added
    
    // Control outputs
    output reg stall_if,
    output reg stall_id,
    output reg stall_ex,  // Added
    output reg flush_ex,
    output reg [1:0] forward_rs1_ex,
    output reg [1:0] forward_rs2_ex
);

    // Forwarding logic (same as before)
    // ...
    
    always @(*) begin
        // Default: no forwarding
        forward_rs1_ex = 2'b00;
        forward_rs2_ex = 2'b00;
        
        // Forward from MEM stage (higher priority)
        if (ex_mem_reg_write && (ex_mem_rd != 5'h0)) begin
            if (ex_mem_rd == id_ex_rs1) forward_rs1_ex = 2'b01;
            if (ex_mem_rd == id_ex_rs2) forward_rs2_ex = 2'b01;
        end
        
        // Forward from WB stage (lower priority)
        if (mem_wb_reg_write && (mem_wb_rd != 5'h0)) begin
            if ((mem_wb_rd == id_ex_rs1) && (forward_rs1_ex == 2'b00))
                forward_rs1_ex = 2'b10;
            if ((mem_wb_rd == id_ex_rs2) && (forward_rs2_ex == 2'b00))
                forward_rs2_ex = 2'b10;
        end
    end
    
    // Load-use hazard detection
    wire load_use_hazard;
    assign load_use_hazard = id_ex_mem_read && 
                             ((id_ex_rd == id_rs1) || (id_ex_rd == id_rs2)) &&
                             (id_ex_rd != 5'h0);
    
    // Custom instruction hazard (wait for FFT done)
    wire custom_stall;
    assign custom_stall = id_ex_is_custom && !fft_done;
    
    // Stall and flush control
    always @(*) begin
        if (custom_stall) begin
            stall_if = 1'b1;
            stall_id = 1'b1;
            stall_ex = 1'b1;
            flush_ex = 1'b0; // Don't flush EX, simply hold it
        end else if (load_use_hazard) begin
            stall_if = 1'b1;
            stall_id = 1'b1;
            stall_ex = 1'b0;
            flush_ex = 1'b1;
        end else begin
            stall_if = 1'b0;
            stall_id = 1'b0;
            stall_ex = 1'b0;
            flush_ex = 1'b0;
        end
    end

endmodule
