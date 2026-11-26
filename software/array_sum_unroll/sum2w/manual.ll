; SUM2W experiment derived from unroll2_cpu_pass/cpu_unrolled2.ll.
; The pair path uses one 64-bit load and one custom SUM2W instruction.
; The scalar tail path preserves correctness when the element count is odd.

source_filename = "software/array_sum/main.c"
target datalayout = "e-m:e-p:64:64-i64:64-i128:128-n32:64-S128"
target triple = "riscv64-unknown-unknown-elf"

@values = internal global [8 x i32] [i32 3, i32 1, i32 4, i32 1, i32 5, i32 9, i32 2, i32 6], align 4

; Function Attrs: noinline nounwind
define dso_local signext i32 @sum_array(ptr noundef %array,
                                        i32 noundef signext %count) #0 {
entry:
  br label %loop.header

loop.header:
  %sum = phi i64 [ 0, %entry ], [ %pair.sum64, %pair.body ]
  %index = phi i32 [ 0, %entry ], [ %next.index, %pair.body ]
  %has.first = icmp slt i32 %index, %count
  br i1 %has.first, label %check.pair, label %exit

check.pair:
  %index64 = sext i32 %index to i64
  %element.ptr = getelementptr inbounds i32, ptr %array, i64 %index64
  %second.index = add nuw nsw i32 %index, 1
  %has.second = icmp slt i32 %second.index, %count
  br i1 %has.second, label %pair.body, label %tail.body

pair.body:
  ; Little-endian LD packs array[index] into bits 31:0 and
  ; array[index + 1] into bits 63:32.
  %pair = load volatile i64, ptr %element.ptr, align 8
  %pair.sum64 = call i64 asm sideeffect
      ".insn r 0x0b, 0, 0, $0, $1, $2",
      "=r,r,r"(i64 %sum, i64 %pair)
  %next.index = add nsw i32 %index, 2
  br label %loop.header, !llvm.loop !6

tail.body:
  %tail.value = load volatile i32, ptr %element.ptr, align 4
  %tail.value64 = sext i32 %tail.value to i64
  %tail.sum = add i64 %sum, %tail.value64
  br label %exit

exit:
  %result64 = phi i64 [ %sum, %loop.header ], [ %tail.sum, %tail.body ]
  %result = trunc i64 %result64 to i32
  ret i32 %result
}

; Function Attrs: noinline nounwind
define dso_local signext i32 @main() #0 {
entry:
  %result = call signext i32 @sum_array(ptr noundef @values,
                                        i32 noundef signext 8) #1
  ret i32 %result
}

attributes #0 = { noinline nounwind "frame-pointer"="all" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="generic-rv64" "target-features"="+64bit,+i,+relax" }
attributes #1 = { nobuiltin "no-builtins" }

!llvm.module.flags = !{!0, !1, !3, !4}
!llvm.ident = !{!5}

!0 = !{i32 1, !"target-abi", !"lp64"}
!1 = !{i32 6, !"riscv-isa", !2}
!2 = !{!"rv64i2p1"}
!3 = !{i32 7, !"frame-pointer", i32 2}
!4 = !{i32 8, !"SmallDataLimit", i32 0}
!5 = !{!"SUM2W manual LLVM IR experiment"}
!6 = distinct !{!6, !7, !8}
!7 = !{!"llvm.loop.mustprogress"}
!8 = !{!"llvm.loop.unroll.disable"}
