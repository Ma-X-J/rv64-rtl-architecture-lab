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

    /* Keep the benchmark array within one 32-byte D-Cache line in every
       code-size variant so instruction layout does not change data misses. */
    .data : ALIGN(32)
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
