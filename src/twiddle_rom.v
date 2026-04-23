// Twiddle Factor ROM
// Pre-computed twiddle factors for FFT up to N=64
// W_64^k = cos(-2*pi*k/64) + j*sin(-2*pi*k/64), k=0..31
// Format: {real[15:0], imag[15:0]} both in IEEE 754 FP16
//
// For an N-point FFT, use stride = 64/N:
//   W_N^k = twiddle_table[k * stride]
//
// Combinational read (no clock needed for lookup)

module twiddle_rom (
    input  wire [4:0]  index,       // Twiddle factor index (0..31)
    output wire [15:0] twiddle_real,
    output wire [15:0] twiddle_imag
);

    reg [31:0] twiddle_table [0:31];

    initial begin
        twiddle_table[ 0] = 32'h3C000000;  // W_64^ 0 =  1.0000 + j*  0.0000
        twiddle_table[ 1] = 32'h3BF6AE46;  // W_64^ 1 =  0.9951 + j* -0.0980
        twiddle_table[ 2] = 32'h3BD9B23E;  // W_64^ 2 =  0.9810 + j* -0.1951
        twiddle_table[ 3] = 32'h3BA8B4A5;  // W_64^ 3 =  0.9570 + j* -0.2903
        twiddle_table[ 4] = 32'h3B64B61F;  // W_64^ 4 =  0.9238 + j* -0.3826
        twiddle_table[ 5] = 32'h3B0EB78B;  // W_64^ 5 =  0.8818 + j* -0.4714
        twiddle_table[ 6] = 32'h3AA7B872;  // W_64^ 6 =  0.8315 + j* -0.5557
        twiddle_table[ 7] = 32'h3A2FB913;  // W_64^ 7 =  0.7729 + j* -0.6343
        twiddle_table[ 8] = 32'h39A8B9A8;  // W_64^ 8 =  0.7070 + j* -0.7070
        twiddle_table[ 9] = 32'h3913BA2F;  // W_64^ 9 =  0.6343 + j* -0.7729
        twiddle_table[10] = 32'h3872BAA7;  // W_64^10 =  0.5557 + j* -0.8315
        twiddle_table[11] = 32'h378BBB0E;  // W_64^11 =  0.4714 + j* -0.8818
        twiddle_table[12] = 32'h361FBB64;  // W_64^12 =  0.3826 + j* -0.9238
        twiddle_table[13] = 32'h34A5BBA8;  // W_64^13 =  0.2903 + j* -0.9570
        twiddle_table[14] = 32'h323EBBD9;  // W_64^14 =  0.1951 + j* -0.9810
        twiddle_table[15] = 32'h2E46BBF6;  // W_64^15 =  0.0980 + j* -0.9951
        twiddle_table[16] = 32'h0000BC00;  // W_64^16 =  0.0000 + j* -1.0000
        twiddle_table[17] = 32'hAE46BBF6;  // W_64^17 = -0.0980 + j* -0.9951
        twiddle_table[18] = 32'hB23EBBD9;  // W_64^18 = -0.1951 + j* -0.9810
        twiddle_table[19] = 32'hB4A5BBA8;  // W_64^19 = -0.2903 + j* -0.9570
        twiddle_table[20] = 32'hB61FBB64;  // W_64^20 = -0.3826 + j* -0.9238
        twiddle_table[21] = 32'hB78BBB0E;  // W_64^21 = -0.4714 + j* -0.8818
        twiddle_table[22] = 32'hB872BAA7;  // W_64^22 = -0.5557 + j* -0.8315
        twiddle_table[23] = 32'hB913BA2F;  // W_64^23 = -0.6343 + j* -0.7729
        twiddle_table[24] = 32'hB9A8B9A8;  // W_64^24 = -0.7070 + j* -0.7070
        twiddle_table[25] = 32'hBA2FB913;  // W_64^25 = -0.7729 + j* -0.6343
        twiddle_table[26] = 32'hBAA7B872;  // W_64^26 = -0.8315 + j* -0.5557
        twiddle_table[27] = 32'hBB0EB78B;  // W_64^27 = -0.8818 + j* -0.4714
        twiddle_table[28] = 32'hBB64B61F;  // W_64^28 = -0.9238 + j* -0.3826
        twiddle_table[29] = 32'hBBA8B4A5;  // W_64^29 = -0.9570 + j* -0.2903
        twiddle_table[30] = 32'hBBD9B23E;  // W_64^30 = -0.9810 + j* -0.1951
        twiddle_table[31] = 32'hBBF6AE46;  // W_64^31 = -0.9951 + j* -0.0980
    end

    // Combinational read
    assign twiddle_real = twiddle_table[index][31:16];
    assign twiddle_imag = twiddle_table[index][15:0];

endmodule
