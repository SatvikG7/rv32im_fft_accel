#!/usr/bin/env python3
"""FFT Reference Generator
Computes N-point FFT of given inputs and outputs results in FP16 hex format.
Used to generate expected test values for simulation verification.
"""

import numpy as np
import struct
import sys


def float_to_fp16_hex(f):
    """Convert a Python float to FP16 hex string (e.g., '3C00')."""
    fp16 = np.float16(f)
    raw = struct.unpack('<H', fp16.tobytes())[0]
    return f"{raw:04X}"


def fp16_hex_to_float(hex_str):
    """Convert FP16 hex string back to float."""
    raw = int(hex_str, 16)
    fp16 = np.frombuffer(struct.pack('<H', raw), dtype=np.float16)[0]
    return float(fp16)


def complex_to_packed_hex(c):
    """Convert a complex number to packed 32-bit hex: {real_fp16, imag_fp16}."""
    real_hex = float_to_fp16_hex(np.real(c))
    imag_hex = float_to_fp16_hex(np.imag(c))
    return f"{real_hex}{imag_hex}"


def generate_fft_reference(inputs, label=""):
    """Generate FFT reference for a list of real or complex inputs."""
    N = len(inputs)
    print(f"\n{'='*60}")
    print(f"  {label}{N}-Point FFT Reference")
    print(f"{'='*60}")

    # Convert inputs to complex
    complex_inputs = [complex(x) for x in inputs]

    print(f"\n--- Inputs (FP16 packed) ---")
    for i, x in enumerate(complex_inputs):
        packed = complex_to_packed_hex(x)
        real_hex = float_to_fp16_hex(np.real(x))
        imag_hex = float_to_fp16_hex(np.imag(x))
        print(f"  x[{i:>2}] = {x:>12} -> 0x{packed}  (real=0x{real_hex}, imag=0x{imag_hex})")

    # Compute FFT
    fft_out = np.fft.fft(complex_inputs)

    print(f"\n--- FFT Outputs (Expected, FP16 packed) ---")
    for i, X in enumerate(fft_out):
        packed = complex_to_packed_hex(X)
        real_hex = float_to_fp16_hex(np.real(X))
        imag_hex = float_to_fp16_hex(np.imag(X))
        # Also show the FP16-rounded values
        real_fp16 = fp16_hex_to_float(real_hex)
        imag_fp16 = fp16_hex_to_float(imag_hex)
        print(f"  X[{i:>2}] = {X:>20} -> 0x{packed}  (fp16: {real_fp16:>8.2f} + {imag_fp16:>8.2f}j)")

    # Print in Verilog testbench format
    print(f"\n--- Verilog expected values ---")
    for i, X in enumerate(fft_out):
        packed = complex_to_packed_hex(X)
        print(f"    expected[{i:>2}] = 32'h{packed};")

    # Print assembly li format
    print(f"\n--- Assembly load format (inputs) ---")
    for i, x in enumerate(complex_inputs):
        packed = complex_to_packed_hex(x)
        print(f"    li x10, 0x{packed}    # x[{i}] = {x}")

    return fft_out


def main():
    # Test 1: Original 4-point FFT (backward compatibility check)
    generate_fft_reference([36, 22, 45, 15], label="Test 1: ")

    # Test 2: 8-point FFT with simple inputs
    generate_fft_reference([1, 2, 3, 4, 5, 6, 7, 8], label="Test 2: ")

    # Test 3: 8-point FFT with varied inputs
    generate_fft_reference([10, 20, 30, 40, 50, 60, 70, 80], label="Test 3: ")

    # Test 4: 2-point FFT
    generate_fft_reference([3, 5], label="Test 4: ")

    # Test 5: 16-point FFT
    generate_fft_reference([1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0], label="Test 5: ")

    # Custom: allow command-line inputs
    if len(sys.argv) > 1:
        try:
            inputs = [float(x) for x in sys.argv[1:]]
            generate_fft_reference(inputs, label="Custom: ")
        except ValueError:
            print(f"Usage: {sys.argv[0]} [x0 x1 x2 ... xN]")


if __name__ == "__main__":
    main()
