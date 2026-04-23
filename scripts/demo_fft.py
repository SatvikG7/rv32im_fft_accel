#!/usr/bin/env python3
"""FFT Accelerator Demo Script
Takes N real numbers (N = 2,4,8,16,32,64), generates a testbench,
runs it through the hardware FFT engine, and verifies against numpy.

Usage:
    python3 scripts/demo_fft.py 10 20 30 40 50 60 70 80 90 100 110 120 130 140 150 160
    python3 scripts/demo_fft.py 1 2 3 4 5 6 7 8
    python3 scripts/demo_fft.py 3 5   # 2-point FFT
"""

import sys
import os
import struct
import subprocess
import shutil
import numpy as np

# ===========================================================================
# Find iverilog/vvp binaries (may be in oss-cad-suite, not on default PATH)
# ===========================================================================

def find_tool(name):
    """Find a tool binary, checking common locations."""
    # Check PATH first
    path = shutil.which(name)
    if path:
        return path
    # Check oss-cad-suite (common install location)
    home = os.path.expanduser("~")
    for candidate in [
        os.path.join(home, "CORE", "oss-cad-suite", "bin", name),
        os.path.join(home, "oss-cad-suite", "bin", name),
        f"/opt/oss-cad-suite/bin/{name}",
    ]:
        if os.path.isfile(candidate) and os.access(candidate, os.X_OK):
            return candidate
    return name  # fallback: hope it's on PATH at runtime

IVERILOG = find_tool("iverilog")
VVP = find_tool("vvp")

# ===========================================================================
# FP16 conversion utilities
# ===========================================================================

def float_to_fp16_hex(f):
    """Convert float to FP16 hex (4 chars)."""
    fp16 = np.float16(f)
    raw = struct.unpack('<H', fp16.tobytes())[0]
    return f"{raw:04X}"

def fp16_hex_to_float(h):
    """Convert FP16 hex string to float."""
    raw = int(h, 16)
    return float(np.frombuffer(struct.pack('<H', raw), dtype=np.float16)[0])

def packed_hex_to_complex(h):
    """Convert 32-bit packed hex (8 chars) to complex: {real_fp16, imag_fp16}."""
    real_hex = h[0:4]
    imag_hex = h[4:8]
    return complex(fp16_hex_to_float(real_hex), fp16_hex_to_float(imag_hex))

def complex_to_packed_hex(c):
    """Convert complex to packed 32-bit hex."""
    return float_to_fp16_hex(np.real(c)) + float_to_fp16_hex(np.imag(c))


# ===========================================================================
# Generate testbench
# ===========================================================================

def generate_testbench(inputs, tb_path):
    N = len(inputs)
    lines = []
    lines.append('`timescale 1ns/1ps')
    lines.append('module tb_demo;')
    lines.append('    reg clk, rst_n, start;')
    lines.append('    reg [31:0] operand_a, operand_b;')
    lines.append('    reg [2:0] operation;')
    lines.append('    wire [31:0] result;')
    lines.append('    wire done, busy;')
    lines.append('')
    lines.append('    fft_accelerator dut (')
    lines.append('        .clk(clk), .rst_n(rst_n), .start(start),')
    lines.append('        .operand_a(operand_a), .operand_b(operand_b),')
    lines.append('        .operation(operation), .result(result),')
    lines.append('        .done(done), .busy(busy)')
    lines.append('    );')
    lines.append('')
    lines.append('    initial begin clk = 0; forever #5 clk = ~clk; end')
    lines.append('')
    lines.append('    task issue_cmd;')
    lines.append('        input [2:0] op;')
    lines.append('        input [31:0] op_a, op_b;')
    lines.append('        begin')
    lines.append('            @(negedge clk);')
    lines.append('            operation = op; operand_a = op_a; operand_b = op_b; start = 1;')
    lines.append('            @(posedge clk); #1; start = 0;')
    lines.append('            repeat (8000) begin')
    lines.append('                if (done) disable issue_cmd;')
    lines.append('                @(posedge clk); #1;')
    lines.append('            end')
    lines.append('        end')
    lines.append('    endtask')
    lines.append('')
    lines.append('    initial begin')
    lines.append('        rst_n = 0; start = 0; operand_a = 0; operand_b = 0; operation = 0;')
    lines.append('        #20; rst_n = 1; #10;')
    lines.append('')
    lines.append(f'        // Set FFT size = {N}')
    lines.append(f'        issue_cmd(3\'b000, 32\'d{N}, 32\'h0);')
    lines.append('')
    lines.append(f'        // Load {N} samples')

    for i, x in enumerate(inputs):
        packed = complex_to_packed_hex(complex(x, 0))
        lines.append(f'        issue_cmd(3\'b001, 32\'h{packed}, 32\'d{i});  // x[{i}] = {x}')

    lines.append('')
    lines.append('        // Execute FFT')
    lines.append('        issue_cmd(3\'b010, 32\'h0, 32\'h0);')
    lines.append('')
    lines.append(f'        // Read {N} results')
    for i in range(N):
        lines.append(f'        issue_cmd(3\'b011, 32\'d{i}, 32\'h0);')
        lines.append(f'        $display("RESULT X[{i}] = %h", result);')

    lines.append('')
    lines.append('        $finish;')
    lines.append('    end')
    lines.append('')
    lines.append('    initial begin #5000000; $display("TIMEOUT"); $finish; end')
    lines.append('endmodule')

    with open(tb_path, 'w') as f:
        f.write('\n'.join(lines) + '\n')


# ===========================================================================
# Main
# ===========================================================================

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 scripts/demo_fft.py <x0> <x1> ... <xN-1>")
        print("  N must be a power of 2 (2, 4, 8, 16, 32, 64)")
        print("\nExamples:")
        print("  python3 scripts/demo_fft.py 1 2 3 4 5 6 7 8")
        print("  python3 scripts/demo_fft.py 10 20 30 40 50 60 70 80 90 100 110 120 130 140 150 160")
        sys.exit(1)

    inputs = [float(x) for x in sys.argv[1:]]
    N = len(inputs)

    if N not in [2, 4, 8, 16, 32, 64]:
        print(f"ERROR: N={N} is not a supported FFT size. Must be 2, 4, 8, 16, 32, or 64.")
        sys.exit(1)

    # -----------------------------------------------------------------------
    # Step 1: Compute reference FFT using numpy
    # -----------------------------------------------------------------------
    print("=" * 70)
    print(f"  FFT Accelerator Demo — {N}-Point FFT")
    print("=" * 70)

    print(f"\n📥 INPUT ({N} samples):")
    for i, x in enumerate(inputs):
        fp16_val = float(np.float16(x))
        packed = complex_to_packed_hex(complex(x, 0))
        print(f"   x[{i:>2}] = {x:>10}  (FP16: {fp16_val:>10})  packed: 0x{packed}")

    # Compute reference using FP16-rounded inputs (to match hardware)
    fp16_inputs = [float(np.float16(x)) for x in inputs]
    fft_ref = np.fft.fft(fp16_inputs)

    print(f"\n🔬 REFERENCE FFT (numpy, from FP16 inputs):")
    for i, X in enumerate(fft_ref):
        real_fp16 = float(np.float16(np.real(X)))
        imag_fp16 = float(np.float16(np.imag(X)))
        packed = complex_to_packed_hex(X)
        print(f"   X[{i:>2}] = {real_fp16:>10.4f} + {imag_fp16:>10.4f}j   packed: 0x{packed}")

    # -----------------------------------------------------------------------
    # Step 2: Generate and run hardware testbench
    # -----------------------------------------------------------------------
    proj_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    build_dir = os.path.join(proj_dir, "build")
    os.makedirs(build_dir, exist_ok=True)

    tb_path = os.path.join(build_dir, "tb_demo.v")
    vvp_path = os.path.join(build_dir, "tb_demo.vvp")

    generate_testbench(inputs, tb_path)

    src_files = [
        "src/fp16_add.v", "src/fp16_mul.v", "src/complex_mul_unit.v",
        "src/butterfly_unit.v", "src/twiddle_rom.v", "src/fft_engine.v",
        "src/fft_accelerator.v"
    ]
    src_paths = [os.path.join(proj_dir, f) for f in src_files]

    print(f"\n⚙️  RUNNING HARDWARE FFT...")

    # Compile
    compile_cmd = [IVERILOG, "-o", vvp_path, "-I", os.path.join(proj_dir, "src")] + src_paths + [tb_path]
    result = subprocess.run(compile_cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"   COMPILE ERROR:\n{result.stderr}")
        sys.exit(1)

    # Run
    run_result = subprocess.run([VVP, vvp_path], capture_output=True, text=True)
    if run_result.returncode != 0 and "TIMEOUT" in run_result.stdout:
        print(f"   SIMULATION TIMEOUT!")
        sys.exit(1)

    # -----------------------------------------------------------------------
    # Step 3: Parse hardware results
    # -----------------------------------------------------------------------
    hw_results = []
    for line in run_result.stdout.strip().split('\n'):
        if line.startswith("RESULT X["):
            # Parse: "RESULT X[0] = 57600000"
            hex_val = line.split('=')[1].strip()
            hw_results.append(hex_val)

    if len(hw_results) != N:
        print(f"   ERROR: Expected {N} results, got {len(hw_results)}")
        print(f"   Simulation output:\n{run_result.stdout}")
        sys.exit(1)

    # -----------------------------------------------------------------------
    # Step 4: Compare hardware vs reference
    # -----------------------------------------------------------------------
    print(f"\n{'─' * 70}")
    print(f"  {'Bin':>4}  {'Hardware (FP16)':>25}  {'Reference (FP16)':>25}  {'Match':>7}")
    print(f"{'─' * 70}")

    all_pass = True
    for i in range(N):
        hw_hex = hw_results[i]
        hw_complex = packed_hex_to_complex(hw_hex)
        hw_real = float(np.real(hw_complex))
        hw_imag = float(np.imag(hw_complex))

        ref_real = float(np.float16(np.real(fft_ref[i])))
        ref_imag = float(np.float16(np.imag(fft_ref[i])))
        ref_packed = complex_to_packed_hex(fft_ref[i])

        # Use relative error tolerance (FP16 has ~0.1% precision per operation,
        # compounds across log2(N) stages)
        def rel_ok(hw_val, ref_val, tol_pct=2.0):
            if ref_val == 0:
                return abs(hw_val) < 0.5  # near-zero check
            return abs(hw_val - ref_val) / max(abs(ref_val), 1e-6) * 100 <= tol_pct

        ok = rel_ok(hw_real, ref_real) and rel_ok(hw_imag, ref_imag)

        status = "  ✅" if ok else "  ❌"
        if not ok:
            all_pass = False

        hw_str = f"{hw_real:>10.4f} + {hw_imag:>8.4f}j"
        ref_str = f"{ref_real:>10.4f} + {ref_imag:>8.4f}j"
        print(f"  X[{i:>2}]  {hw_str}  {ref_str}  {status}")

    print(f"{'─' * 70}")
    if all_pass:
        print(f"\n  🎉 ALL {N} BINS MATCH — Hardware FFT verified successfully!")
    else:
        print(f"\n  ⚠️  SOME BINS DIFFER beyond 2% relative tolerance")

    print(f"\n  Hardware: {N}-point radix-2 DIT FFT, FP16 (half-precision)")
    print(f"  Tolerance: 2% relative error per component ({int(np.log2(N))} butterfly stages)")
    print()


if __name__ == "__main__":
    main()
