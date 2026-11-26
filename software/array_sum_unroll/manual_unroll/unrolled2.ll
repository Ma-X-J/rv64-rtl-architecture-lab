; ModuleID = 'software\array_sum_unroll\prepared.ll'
source_filename = "software/array_sum/main.c"
target datalayout = "e-m:e-p:64:64-i64:64-i128:128-n32:64-S128"
target triple = "riscv64-unknown-unknown-elf"

@values = internal global [8 x i32] [i32 3, i32 1, i32 4, i32 1, i32 5, i32 9, i32 2, i32 6], align 4

; Function Attrs: noinline nounwind
define dso_local signext i32 @sum_array(ptr noundef %0, i32 noundef signext %1) #0 {
  br label %3

3:                                                ; preds = %12, %2
  %.01 = phi i32 [ 0, %2 ], [ %16, %12 ]
  %.0 = phi i32 [ 0, %2 ], [ %17, %12 ]
  %4 = icmp slt i32 %.0, %1
  br i1 %4, label %5, label %18

5:                                                ; preds = %3
  %6 = sext i32 %.0 to i64
  %7 = getelementptr inbounds i32, ptr %0, i64 %6
  %8 = load volatile i32, ptr %7, align 4
  %9 = add nsw i32 %.01, %8
  %10 = add nuw nsw i32 %.0, 1
  %11 = icmp slt i32 %10, %1
  br i1 %11, label %12, label %18

12:                                               ; preds = %5
  %13 = sext i32 %10 to i64
  %14 = getelementptr inbounds i32, ptr %0, i64 %13
  %15 = load volatile i32, ptr %14, align 4
  %16 = add nsw i32 %9, %15
  %17 = add nsw i32 %.0, 2
  br label %3, !llvm.loop !6

18:                                               ; preds = %5, %3
  %.01.lcssa = phi i32 [ %.01, %3 ], [ %9, %5 ]
  ret i32 %.01.lcssa
}

; Function Attrs: noinline nounwind
define dso_local signext i32 @main() #0 {
  %1 = call signext i32 @sum_array(ptr noundef @values, i32 noundef signext 8) #1
  ret i32 %1
}

attributes #0 = { noinline nounwind "frame-pointer"="all" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="generic-rv64" "target-features"="+64bit,+i,+relax,-a,-b,-c,-d,-e,-experimental-p,-experimental-smpmpmt,-experimental-svukte,-experimental-xqccmt,-experimental-xsfmclic,-experimental-xsfsclic,-experimental-y,-experimental-zibi,-experimental-zicfilp,-experimental-zicfiss,-experimental-zvabd,-experimental-zvbc32e,-experimental-zvdot4a8i,-experimental-zvfbdota32f,-experimental-zvfbfa,-experimental-zvfofp8min,-experimental-zvfqwbdota8f,-experimental-zvfqwdota8f,-experimental-zvfwbdota16bf,-experimental-zvfwdota16bf,-experimental-zvkgs,-experimental-zvqwbdota16i,-experimental-zvqwbdota8i,-experimental-zvqwdota16i,-experimental-zvqwdota8i,-experimental-zvvfmm,-experimental-zvvmm,-experimental-zvvmtls,-experimental-zvvmttls,-experimental-zvzip,-f,-h,-m,-q,-sdext,-sdtrig,-sha,-shcounterenw,-shgatpa,-shlcofideleg,-shtvala,-shvsatpa,-shvstvala,-shvstvecd,-smaia,-smcdeleg,-smcntrpmf,-smcsrind,-smctr,-smdbltrp,-smepmp,-smmpm,-smnpm,-smrnmi,-smstateen,-ssaia,-ssccfg,-ssccptr,-sscofpmf,-sscounterenw,-sscsrind,-ssctr,-ssdbltrp,-ssnpm,-sspm,-ssqosid,-ssstateen,-ssstrict,-sstc,-sstvala,-sstvecd,-ssu64xl,-supm,-svade,-svadu,-svbare,-svinval,-svnapot,-svpbmt,-svrsw60t59b,-svvptc,-v,-xaifet,-xandesbfhcvt,-xandesperf,-xandesvbfhcvt,-xandesvdot,-xandesvpackfph,-xandesvsinth,-xandesvsintload,-xcheriot,-xcvalu,-xcvbi,-xcvbitmanip,-xcvelw,-xcvmac,-xcvmem,-xcvsimd,-xmipscbop,-xmipscmov,-xmipsexectl,-xmipslsp,-xqccmp,-xqci,-xqcia,-xqciac,-xqcibi,-xqcibm,-xqcicli,-xqcicm,-xqcics,-xqcicsr,-xqciint,-xqciio,-xqcilb,-xqcili,-xqcilia,-xqcilo,-xqcilsm,-xqcisim,-xqcisls,-xqcisync,-xsfcease,-xsfmm128t,-xsfmm16t,-xsfmm32a,-xsfmm32a16f,-xsfmm32a32f,-xsfmm32a8f,-xsfmm32a8i,-xsfmm32t,-xsfmm64a64f,-xsfmm64t,-xsfmmbase,-xsfvcp,-xsfvfbfexp16e,-xsfvfexp16e,-xsfvfexp32e,-xsfvfexpa,-xsfvfexpa64e,-xsfvfnrclipxfqf,-xsfvfwmaccqqq,-xsfvqmaccdod,-xsfvqmaccqoq,-xsifivecdiscarddlone,-xsifivecflushdlone,-xsmtvdot,-xsmtvdotii,-xtheadba,-xtheadbb,-xtheadbs,-xtheadcmo,-xtheadcondmov,-xtheadfmemidx,-xtheadmac,-xtheadmemidx,-xtheadmempair,-xtheadsync,-xtheadvdot,-xventanacondops,-xwchc,-za128rs,-za64rs,-zaamo,-zabha,-zacas,-zalasr,-zalrsc,-zama16b,-zawrs,-zba,-zbb,-zbc,-zbkb,-zbkc,-zbkx,-zbs,-zca,-zcb,-zcd,-zce,-zcf,-zclsd,-zcmop,-zcmp,-zcmt,-zdinx,-zfa,-zfbfmin,-zfh,-zfhmin,-zfinx,-zhinx,-zhinxmin,-zic64b,-zicbom,-zicbop,-zicboz,-ziccamoa,-ziccamoc,-ziccid,-ziccif,-zicclsm,-ziccrse,-zicntr,-zicond,-zicsr,-zifencei,-zihintntl,-zihintpause,-zihpm,-zilsd,-zimop,-zk,-zkn,-zknd,-zkne,-zknh,-zkr,-zks,-zksed,-zksh,-zkt,-zmmul,-ztso,-zvbb,-zvbc,-zve32f,-zve32x,-zve64d,-zve64f,-zve64x,-zvfbfmin,-zvfbfwma,-zvfh,-zvfhmin,-zvkb,-zvkg,-zvkn,-zvknc,-zvkned,-zvkng,-zvknha,-zvknhb,-zvks,-zvksc,-zvksed,-zvksg,-zvksh,-zvkt,-zvl1024b,-zvl128b,-zvl16384b,-zvl2048b,-zvl256b,-zvl32768b,-zvl32b,-zvl4096b,-zvl512b,-zvl64b,-zvl65536b,-zvl8192b" }
attributes #1 = { nobuiltin "no-builtins" }

!llvm.module.flags = !{!0, !1, !3, !4}
!llvm.ident = !{!5}

!0 = !{i32 1, !"target-abi", !"lp64"}
!1 = !{i32 6, !"riscv-isa", !2}
!2 = !{!"rv64i2p1"}
!3 = !{i32 7, !"frame-pointer", i32 2}
!4 = !{i32 8, !"SmallDataLimit", i32 0}
!5 = !{!"clang version 23.1.5 (https://github.com/llvm/llvm-project 392dfff97d29b59d77e5cac6d4b6ef2585fe7117)"}
!6 = distinct !{!6, !7, !8}
!7 = !{!"llvm.loop.mustprogress"}
!8 = !{!"llvm.loop.unroll.disable"}
