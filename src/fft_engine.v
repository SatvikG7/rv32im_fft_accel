// FFT Engine - Modular N-Point Radix-2 DIT FFT
// Supports N = 2, 4, 8, 16, 32, 64
// Uses a single butterfly unit (time-multiplexed) and twiddle ROM
// In-place computation with hardware bit-reversal during LOAD
//
// Commands (active when cmd_valid=1):
//   CMD_SETN (3'b000): Set FFT size from data_in[6:0]
//   CMD_LOAD (3'b001): Write data_in to buffer at bit-reversed index
//   CMD_EXEC (3'b010): Start FFT computation
//   CMD_READ (3'b011): Read buffer[index] to data_out

module fft_engine (
    input  wire        clk,
    input  wire        rst_n,

    // Command interface
    input  wire        cmd_valid,
    input  wire [2:0]  cmd,
    input  wire [5:0]  index,      // Sample index for LOAD/READ (0..63)
    input  wire [31:0] data_in,    // Complex sample {real[15:0], imag[15:0]}

    output reg  [31:0] data_out,   // Complex result for READ
    output reg         busy,       // High during FFT computation
    output reg         done        // Pulses high for 1 cycle when operation completes
);

    // Command encoding
    localparam CMD_SETN = 3'b000;
    localparam CMD_LOAD = 3'b001;
    localparam CMD_EXEC = 3'b010;
    localparam CMD_READ = 3'b011;

    // FSM states
    localparam S_IDLE           = 3'd0;
    localparam S_COMPUTE_INIT   = 3'd1;
    localparam S_BUTTERFLY_START = 3'd2;
    localparam S_BUTTERFLY_WAIT = 3'd3;
    localparam S_BUTTERFLY_DONE = 3'd4;
    localparam S_FFT_DONE       = 3'd5;

    reg [2:0] state;

    // FFT configuration
    reg [6:0] fft_n;           // FFT size (2,4,8,16,32,64)
    reg [2:0] log2_n;          // log2(fft_n): 1..6

    // Internal sample buffer: 64 complex samples, each 32-bit {real, imag}
    reg [31:0] sample_buf [0:63];

    // Computation counters
    reg [2:0] stage;           // Current FFT stage (0..log2_n-1)
    reg [5:0] butterfly_idx;   // Current butterfly index within stage (0..N/2-1)
    reg [2:0] total_stages;    // = log2_n

    // Butterfly pair indices
    reg [5:0] idx_p, idx_q;
    reg [4:0] tw_index;        // Twiddle factor index into ROM
    reg wait_cycle;            // Used to sequence butterfly start pulse

    // Butterfly unit interface
    reg        butterfly_start;
    wire [15:0] bfly_out1_real, bfly_out1_imag;
    wire [15:0] bfly_out2_real, bfly_out2_imag;
    wire       butterfly_done;

    // Twiddle ROM interface
    reg  [4:0] twiddle_addr;
    wire [15:0] tw_real, tw_imag;

    // Signals for butterfly inputs (from buffer)
    reg [15:0] buf_p_real, buf_p_imag;
    reg [15:0] buf_q_real, buf_q_imag;

    // Intermediate registers for buffer access (iverilog compatibility)
    reg [5:0] load_addr;       // Bit-reversed address for LOAD
    reg [31:0] buf_p_word;     // Full 32-bit word read from buffer[idx_p]
    reg [31:0] buf_q_word;     // Full 32-bit word read from buffer[idx_q]

    // =========================================================================
    // Twiddle ROM instantiation (combinational)
    // =========================================================================
    twiddle_rom tw_rom (
        .index(twiddle_addr),
        .twiddle_real(tw_real),
        .twiddle_imag(tw_imag)
    );

    // =========================================================================
    // Butterfly unit instantiation
    // =========================================================================
    butterfly_unit bfly (
        .clk(clk),
        .rst_n(rst_n),
        .start(butterfly_start),
        .a_real(buf_p_real),
        .a_imag(buf_p_imag),
        .b_real(buf_q_real),
        .b_imag(buf_q_imag),
        .w_real(tw_real),
        .w_imag(tw_imag),
        .out1_real(bfly_out1_real),
        .out1_imag(bfly_out1_imag),
        .out2_real(bfly_out2_real),
        .out2_imag(bfly_out2_imag),
        .done(butterfly_done)
    );

    // =========================================================================
    // Bit-reversal function
    // Reverses the lower log2_n bits of the input address
    // Uses explicit cases to avoid variable bit-indexing (not synthesizable)
    // =========================================================================
    function [5:0] bit_reverse;
        input [5:0] addr;
        input [2:0] nbits;  // log2(N): 1..6
        begin
            case (nbits)
                3'd1: bit_reverse = {5'b0, addr[0]};
                3'd2: bit_reverse = {4'b0, addr[0], addr[1]};
                3'd3: bit_reverse = {3'b0, addr[0], addr[1], addr[2]};
                3'd4: bit_reverse = {2'b0, addr[0], addr[1], addr[2], addr[3]};
                3'd5: bit_reverse = {1'b0, addr[0], addr[1], addr[2], addr[3], addr[4]};
                3'd6: bit_reverse = {addr[0], addr[1], addr[2], addr[3], addr[4], addr[5]};
                default: bit_reverse = addr;
            endcase
        end
    endfunction

    // =========================================================================
    // log2 computation (combinational helper)
    // =========================================================================
    function [2:0] compute_log2;
        input [6:0] n;
        begin
            case (n)
                7'd2:    compute_log2 = 3'd1;
                7'd4:    compute_log2 = 3'd2;
                7'd8:    compute_log2 = 3'd3;
                7'd16:   compute_log2 = 3'd4;
                7'd32:   compute_log2 = 3'd5;
                7'd64:   compute_log2 = 3'd6;
                default: compute_log2 = 3'd0;  // invalid
            endcase
        end
    endfunction

    // =========================================================================
    // Butterfly index computation (Cooley-Tukey DIT)
    //
    // For stage s (0-indexed), butterfly b (0..N/2-1):
    //   half_block = 1 << s
    //   block_size = 1 << (s+1)
    //   block_num  = b / half_block    (equivalently b >> s)
    //   offset     = b % half_block    (equivalently b & (half_block-1))
    //   p = block_num * block_size + offset
    //   q = p + half_block
    //   twiddle_index = offset * (64 / block_size)
    //                 = offset * (32 >> s)
    //                 = offset << (5 - s)
    // =========================================================================
    reg [5:0] half_block;
    reg [6:0] block_size;
    reg [5:0] block_num;
    reg [5:0] offset;

    always @(*) begin
        half_block = 6'd1 << stage;
        block_size = 7'd1 << (stage + 1);
        block_num  = butterfly_idx >> stage;
        offset     = butterfly_idx & (half_block - 6'd1);

        idx_p = block_num * block_size[5:0] + offset;
        idx_q = idx_p + half_block;

        // Twiddle index: offset * (32 >> stage) = offset << (5 - stage)
        // Stage 0: <<5 (offset always 0, so tw=0)
        // Stage 1: <<4
        // Stage 2: <<3
        // Stage 3: <<2
        // Stage 4: <<1
        // Stage 5: <<0
        case (stage)
            3'd0: tw_index = 5'd0;                   // offset=0 always (half_block=1)
            3'd1: tw_index = {offset[0],   4'b0};    // offset << 4
            3'd2: tw_index = {offset[1:0], 3'b0};    // offset << 3
            3'd3: tw_index = {offset[2:0], 2'b0};    // offset << 2
            3'd4: tw_index = {offset[3:0], 1'b0};    // offset << 1
            3'd5: tw_index = offset[4:0];             // offset << 0
            default: tw_index = 5'd0;
        endcase
    end

    // =========================================================================
    // Main FSM
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            fft_n <= 7'd4;         // Default FFT size
            log2_n <= 3'd2;
            total_stages <= 3'd2;
            stage <= 3'd0;
            butterfly_idx <= 6'd0;
            butterfly_start <= 1'b0;
            busy <= 1'b0;
            done <= 1'b0;
            data_out <= 32'h0;
            buf_p_real <= 16'h0;
            buf_p_imag <= 16'h0;
            buf_q_real <= 16'h0;
            buf_q_imag <= 16'h0;
            twiddle_addr <= 5'd0;
            wait_cycle <= 1'b0;
            load_addr <= 6'd0;
        end else begin
            // Default: clear single-cycle signals
            butterfly_start <= 1'b0;
            done <= 1'b0;

            case (state)
                // =============================================================
                // IDLE: Accept commands
                // =============================================================
                S_IDLE: begin
                    if (cmd_valid) begin
                        case (cmd)
                            CMD_SETN: begin
                                fft_n <= data_in[6:0];
                                log2_n <= compute_log2(data_in[6:0]);
                                total_stages <= compute_log2(data_in[6:0]);
                                done <= 1'b1;
                            end

                            CMD_LOAD: begin
                                // Write data_in to buffer at bit-reversed address
                                load_addr = bit_reverse(index, log2_n);
                                sample_buf[load_addr] <= data_in;
                                done <= 1'b1;
                            end

                            CMD_EXEC: begin
                                busy <= 1'b1;
                                state <= S_COMPUTE_INIT;
                            end

                            CMD_READ: begin
                                data_out <= sample_buf[index];
                                done <= 1'b1;
                            end

                            default: begin
                                done <= 1'b1;
                            end
                        endcase
                    end
                end

                // =============================================================
                // COMPUTE_INIT: Initialize stage/butterfly counters
                // =============================================================
                S_COMPUTE_INIT: begin
                    stage <= 3'd0;
                    butterfly_idx <= 6'd0;
                    state <= S_BUTTERFLY_START;
                end

                // =============================================================
                // BUTTERFLY_START: Read operands, set twiddle, start butterfly
                // =============================================================
                S_BUTTERFLY_START: begin
                    // Read buffer elements for this butterfly pair
                    // Use intermediate words to avoid part-select of array element
                    buf_p_word = sample_buf[idx_p];
                    buf_q_word = sample_buf[idx_q];
                    buf_p_real <= buf_p_word[31:16];
                    buf_p_imag <= buf_p_word[15:0];
                    buf_q_real <= buf_q_word[31:16];
                    buf_q_imag <= buf_q_word[15:0];

                    // Set twiddle address
                    twiddle_addr <= tw_index;

                    // Start butterfly unit on NEXT cycle (inputs need to settle)
                    state <= S_BUTTERFLY_WAIT;
                    wait_cycle <= 1'b0;
                end

                // =============================================================
                // BUTTERFLY_WAIT: Start butterfly, then wait for completion
                // =============================================================
                S_BUTTERFLY_WAIT: begin
                    if (!wait_cycle) begin
                        // First cycle: pulse start (inputs are now registered)
                        butterfly_start <= 1'b1;
                        wait_cycle <= 1'b1;
                    end else if (butterfly_done) begin
                        // Butterfly has completed
                        state <= S_BUTTERFLY_DONE;
                    end
                    // Otherwise: waiting for butterfly to complete
                end

                // =============================================================
                // BUTTERFLY_DONE: Write results, advance counters
                // =============================================================
                S_BUTTERFLY_DONE: begin
                    // Write butterfly results back to buffer
                    sample_buf[idx_p] <= {bfly_out1_real, bfly_out1_imag};
                    sample_buf[idx_q] <= {bfly_out2_real, bfly_out2_imag};

                    // Advance butterfly counter
                    if (butterfly_idx == (fft_n[5:0] >> 1) - 6'd1) begin
                        // All butterflies in this stage done
                        butterfly_idx <= 6'd0;
                        if (stage == total_stages - 3'd1) begin
                            // All stages done
                            state <= S_FFT_DONE;
                        end else begin
                            // Next stage
                            stage <= stage + 3'd1;
                            state <= S_BUTTERFLY_START;
                        end
                    end else begin
                        // Next butterfly in same stage
                        butterfly_idx <= butterfly_idx + 6'd1;
                        state <= S_BUTTERFLY_START;
                    end
                end

                // =============================================================
                // FFT_DONE: Signal completion
                // =============================================================
                S_FFT_DONE: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    state <= S_IDLE;
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
