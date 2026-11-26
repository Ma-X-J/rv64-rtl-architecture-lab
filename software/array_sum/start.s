.section .text.start, "ax", @progbits
.globl _start
.type _start, @function

_start:
    lui sp, 1
    addi sp, sp, -2048    # sp = 0x800
    call main

halt:
    j halt

.size _start, .-_start
