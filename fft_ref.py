import numpy as np
import struct

def float_to_fp16_hex(f):
    fp16 = np.float16(f)
    return hex(struct.unpack('<H', fp16.tobytes())[0])

inputs = [36, 22, 45, 15]
print("--- INPUTS in FP16 ---")
for i, x in enumerate(inputs):
    print(f"x[{i}] = {x} -> {float_to_fp16_hex(x)}")

print("\n--- FFT OUTPUTS (Expected) in FP16 ---")
fft_out = np.fft.fft(inputs)
for i, x in enumerate(fft_out):
    print(f"X[{i}] = {x} -> Real: {float_to_fp16_hex(np.real(x))}, Imag: {float_to_fp16_hex(np.imag(x))}")

