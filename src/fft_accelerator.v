// FFT Accelerator Top Module
// Thin wrapper around fft_engine — interfaces with the RISC-V processor pipeline
//
// Custom instruction encoding (opcode 0x0B, funct3 selects operation):
//   funct3=000 (FFT.SETN): Set FFT size.  rs1 = N (2,4,8,16,32,64)
//   funct3=001 (FFT.LOAD): Load sample.   rs1 = data {real,imag}, rs2 = index
//   funct3=010 (FFT.EXEC): Execute FFT.   Stalls pipeline until done.
//   funct3=011 (FFT.READ): Read result.   rs1 = index, result -> rd

module fft_accelerator (
    input wire clk,
    input wire rst_n,

    // Processor interface
    input wire start,
    input wire [31:0] operand_a,  // rs1 data (forwarded)
    input wire [31:0] operand_b,  // rs2 data (forwarded)
    input wire [2:0] operation,   // funct3 from instruction

    output wire [31:0] result,    // Result to write back to rd
    output wire done,
    output wire busy
);

    // Map processor signals to engine command interface
    //
    // operation[2:0] maps directly to engine cmd[2:0]:
    //   000 = SETN  -> engine CMD_SETN, data_in = operand_a (contains N)
    //   001 = LOAD  -> engine CMD_LOAD, data_in = operand_a (sample), index = operand_b[5:0]
    //   010 = EXEC  -> engine CMD_EXEC
    //   011 = READ  -> engine CMD_READ, index = operand_a[5:0]

    wire [5:0] engine_index;
    wire [31:0] engine_data_in;

    // Index comes from:
    //   LOAD: operand_b[5:0] (rs2 = index)
    //   READ: operand_a[5:0] (rs1 = index)
    assign engine_index = (operation == 3'b011) ? operand_a[5:0] : operand_b[5:0];

    // Data input:
    //   SETN: operand_a (N value in lower bits)
    //   LOAD: operand_a (complex sample {real, imag})
    //   EXEC: don't care
    //   READ: don't care
    assign engine_data_in = operand_a;

    // Instantiate FFT engine
    fft_engine engine (
        .clk(clk),
        .rst_n(rst_n),
        .cmd_valid(start),
        .cmd(operation),
        .index(engine_index),
        .data_in(engine_data_in),
        .data_out(result),
        .busy(busy),
        .done(done)
    );

endmodule
