// Twiddle Factor ROM
// Pre-computed twiddle factors for FFT up to N=256
// W_N^k = exp(-2*pi*j*k/N) in FP16 format

module twiddle_rom (
    input wire clk,
    input wire [7:0] index,  // Twiddle factor index
    input wire [7:0] n,      // FFT size
    output reg [15:0] twiddle_real,
    output reg [15:0] twiddle_imag
);

    // Twiddle factor table for N=256
    // Format: {real, imag} both in FP16
    // This is a simplified version - in practice, you'd compute these offline
    
    reg [31:0] twiddle_table [0:255];
    integer i;

    initial begin
        // Initialize with some common twiddle factors
        // W_256^0 = 1 + 0i
        twiddle_table[0] = {16'h3C00, 16'h0000};  // 1.0 + 0.0i
        
        // W_256^1 = cos(-2π/256) + i*sin(-2π/256)
        // Approximately 0.9997 - 0.0245i
        twiddle_table[1] = {16'h3BFF, 16'hA320};
        
        // W_256^2 = cos(-4π/256) + i*sin(-4π/256)
        twiddle_table[2] = {16'h3BFE, 16'hA640};
        
        // For a complete implementation, generate all 256 twiddle factors
        // Using Python or MATLAB and convert to FP16
        // For now, fill rest with zeros (placeholder)
        for (i = 3; i < 256; i = i + 1) begin
            twiddle_table[i] = 32'h3C000000;  // Default to 1.0 + 0.0i
        end
    end
    
    // Read twiddle factor
    always @(posedge clk) begin
        twiddle_real <= twiddle_table[index][31:16];
        twiddle_imag <= twiddle_table[index][15:0];
    end

endmodule
