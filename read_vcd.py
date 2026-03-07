import sys

lines = []
with open('build/tb_riscv_core.vcd', 'r') as f:
    for line in f:
        if line.startswith('$var wire 32'):
             lines.append(line.strip())
print('\n'.join(lines[:10]))
