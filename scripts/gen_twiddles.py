#!/usr/bin/env python3
"""Generate twiddle factors W_64^k for k=0..31 in FP16 hex format.

Outputs Verilog initial block code suitable for twiddle_rom.v,
plus a human-readable table for verification.

W_N^k = cos(-2*pi*k/N) + j*sin(-2*pi*k/N)
"""

import numpy as np
import struct

N_MAX = 64
N_TWIDDLES = N_MAX // 2  # 32 unique twiddle factors


def float_to_fp16_hex(f):
    """Convert a Python float to FP16 hex string (e.g., '3C00')."""
    fp16 = np.float16(f)
    raw = struct.unpack('<H', fp16.tobytes())[0]
    return f"{raw:04X}"


def float_from_fp16_hex(hex_str):
    """Convert FP16 hex string back to float for verification."""
    raw = int(hex_str, 16)
    fp16 = np.frombuffer(struct.pack('<H', raw), dtype=np.float16)[0]
    return float(fp16)


def main():
    print(f"Twiddle Factors for N={N_MAX} (k=0..{N_TWIDDLES-1})")
    print("=" * 70)
    print(f"{'k':>3}  {'cos':>10}  {'sin':>10}  {'real_hex':>10}  {'imag_hex':>10}  {'fp16_real':>10}  {'fp16_imag':>10}")
    print("-" * 70)

    twiddles = []
    for k in range(N_TWIDDLES):
        angle = -2.0 * np.pi * k / N_MAX
        cos_val = np.cos(angle)
        sin_val = np.sin(angle)

        real_hex = float_to_fp16_hex(cos_val)
        imag_hex = float_to_fp16_hex(sin_val)

        # Verify round-trip
        real_back = float_from_fp16_hex(real_hex)
        imag_back = float_from_fp16_hex(imag_hex)

        twiddles.append((k, cos_val, sin_val, real_hex, imag_hex, real_back, imag_back))
        print(f"{k:>3}  {cos_val:>10.6f}  {sin_val:>10.6f}  {real_hex:>10}  {imag_hex:>10}  {real_back:>10.4f}  {imag_back:>10.4f}")

    # Generate Verilog code
    print("\n\n// === Verilog twiddle_rom initial block ===")
    print("// W_64^k = cos(-2*pi*k/64) + j*sin(-2*pi*k/64), k=0..31")
    print("// Format: {real[15:0], imag[15:0]} both in IEEE 754 FP16")
    print()
    for k, cos_val, sin_val, real_hex, imag_hex, _, _ in twiddles:
        print(f"        twiddle_table[{k:>2}] = 32'h{real_hex}{imag_hex};  "
              f"// W_64^{k:>2} = {cos_val:>8.4f} + j*{sin_val:>8.4f}")

    # Also generate a quick check: which indices to use for each FFT size
    print("\n\n// === Twiddle index mapping for each FFT size ===")
    for n in [2, 4, 8, 16, 32, 64]:
        stride = N_MAX // n
        indices = [k * stride for k in range(n // 2)]
        print(f"// N={n:>2}: stride={stride:>2}, indices={indices}")


if __name__ == "__main__":
    main()
