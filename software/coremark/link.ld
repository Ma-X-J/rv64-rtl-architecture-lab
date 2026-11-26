OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
    IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 16K
    DMEM (rw)  : ORIGIN = 0x00004000, LENGTH = 8K
}

SECTIONS
{
    .text : ALIGN(4)
    {
        __text_start = .;
        KEEP(*(.text.start))
        *(.text)
        *(.text.*)
        __text_end = .;
    } > IMEM

    /*
     * Constants must live in DMEM: this is a Harvard implementation and an
     * ordinary C load cannot read the instruction backing array.
     */
    .dmem : ALIGN(8)
    {
        __dmem_start = .;
        KEEP(*(.coremark_mailbox))
        *(.srodata)
        *(.srodata.*)
        *(.rodata)
        *(.rodata.*)
        *(.sdata)
        *(.sdata.*)
        *(.data)
        *(.data.*)
        __dmem_init_end = .;
    } > DMEM

    .bss (NOLOAD) : ALIGN(8)
    {
        __bss_start = .;
        *(.sbss)
        *(.sbss.*)
        *(.bss)
        *(.bss.*)
        *(COMMON)
        . = ALIGN(8);
        __bss_end = .;
    } > DMEM

    /* Reserve the upper 2 KiB for the downward-growing stack. */
    __stack_limit = ORIGIN(DMEM) + LENGTH(DMEM) - 2K;
    __stack_top = ORIGIN(DMEM) + LENGTH(DMEM);

    ASSERT(__text_end <= ORIGIN(IMEM) + LENGTH(IMEM),
           "CoreMark text does not fit in 16 KiB IMEM")
    ASSERT(__bss_end <= __stack_limit,
           "CoreMark static data leaves less than 2 KiB for stack")

    /DISCARD/ :
    {
        *(.comment)
        *(.note*)
        *(.eh_frame*)
        *(.riscv.attributes)
    }
}
