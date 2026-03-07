OUTPUT_ARCH( "riscv" )
ENTRY(_start)

MEMORY {
  ram (rwx) : ORIGIN = 0x00000000, LENGTH = 0x2000 /* 8KB */
}

SECTIONS {
  .text : {
    *(.text.init)
    *(.text)
  } > ram

  .data : {
    *(.rodata)
    *(.data)
    *(.sdata)
  } > ram

  .bss : {
    *(.bss)
    *(.sbss)
  } > ram

  _end = .;
}
