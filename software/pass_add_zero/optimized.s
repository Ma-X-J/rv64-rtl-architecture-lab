	.attribute	4, 16
	.attribute	5, "rv64i2p1"
	.file	"main.c"
	.text
	.globl	add_zero                        # -- Begin function add_zero
	.p2align	2
	.type	add_zero,@function
add_zero:                               # @add_zero
# %bb.0:                                # %entry
	addi	sp, sp, -32
	sd	ra, 24(sp)                      # 8-byte Folded Spill
	sd	s0, 16(sp)                      # 8-byte Folded Spill
	addi	s0, sp, 32
	sw	a0, 12(sp)
	lw	a0, 12(sp)
	ld	ra, 24(sp)                      # 8-byte Folded Reload
	ld	s0, 16(sp)                      # 8-byte Folded Reload
	addi	sp, sp, 32
	ret
.Lfunc_end0:
	.size	add_zero, .Lfunc_end0-add_zero
                                        # -- End function
	.globl	main                            # -- Begin function main
	.p2align	2
	.type	main,@function
main:                                   # @main
# %bb.0:                                # %entry
	addi	sp, sp, -16
	sd	ra, 8(sp)                       # 8-byte Folded Spill
	sd	s0, 0(sp)                       # 8-byte Folded Spill
	addi	s0, sp, 16
	li	a0, 42
	call	add_zero
	ld	ra, 8(sp)                       # 8-byte Folded Reload
	ld	s0, 0(sp)                       # 8-byte Folded Reload
	addi	sp, sp, 16
	ret
.Lfunc_end1:
	.size	main, .Lfunc_end1-main
                                        # -- End function
	.ident	"clang version 23.1.5 (https://github.com/llvm/llvm-project 392dfff97d29b59d77e5cac6d4b6ef2585fe7117)"
	.section	".note.GNU-stack","",@progbits
