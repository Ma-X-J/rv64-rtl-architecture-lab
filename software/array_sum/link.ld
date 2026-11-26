OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 2K
}

SECTIONS
{
    .text :
    {
        KEEP(*(.text.start))
        *(.text)
        *(.text.*)
    } > RAM

    .rodata : ALIGN(8)
    {
        *(.rodata)
        *(.rodata.*)
    } > RAM

    .data : ALIGN(8)
    {
        *(.data)
        *(.data.*)
    } > RAM

    .bss (NOLOAD) : ALIGN(8)
    {
        *(.bss)
        *(.bss.*)
        *(COMMON)
    } > RAM
}
