CC = riscv64-unknown-elf-gcc
OBJCOPY = riscv64-unknown-elf-objcopy
OBJDUMP = riscv64-unknown-elf-objdump

CFLAGS = -march=rv32im -mabi=ilp32 -O0 -nostartfiles -nostdlib -T link.ld

SRCS = main.s
OBJS = $(SRCS:.s=.o)

all: firmware.hex firmware.dump

firmware.elf: $(SRCS)
	$(CC) $(CFLAGS) $^ -o $@

firmware.bin: firmware.elf
	$(OBJCOPY) -O binary $< $@

firmware.hex: firmware.bin
	hexdump -v -e '1/4 "%08x\n"' $< > $@

firmware.dump: firmware.elf
	$(OBJDUMP) -D $< > $@

clean:
	rm -f *.o *.elf *.bin *.hex *.dump
