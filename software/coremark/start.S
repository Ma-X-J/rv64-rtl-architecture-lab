    .section .text.start, "ax", @progbits
    .globl _start
    .type _start, @function

_start:
    /* The data memory occupies 0x4000..0x5fff. */
    la      sp, __stack_top

    /* The simulator preloads only initialized data, so clear .bss here. */
    la      t0, __bss_start
    la      t1, __bss_end
.Lclear_bss:
    bgeu    t0, t1, .Lcall_main
    sd      zero, 0(t0)
    addi    t0, t0, 8
    j       .Lclear_bss

.Lcall_main:
    call    main

    /* Preserve main's return value in mailbox word 5. */
    la      t0, coremark_mailbox
    sd      a0, 40(t0)

    .globl coremark_halt
coremark_halt:
    j       coremark_halt

    .size _start, .-_start
