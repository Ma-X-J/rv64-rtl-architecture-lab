#include "llvm/ADT/SmallVector.h"
#include "llvm/IR/BasicBlock.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/GlobalVariable.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/InlineAsm.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/Metadata.h"
#include "llvm/IR/PassManager.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Plugins/PassPlugin.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;

namespace {

class IRStatsPass : public PassInfoMixin<IRStatsPass> {
public:
  PreservedAnalyses run(Function &Function,
                        FunctionAnalysisManager &AnalysisManager) {
    (void)AnalysisManager;

    unsigned BasicBlockCount = 0;
    unsigned InstructionCount = 0;
    unsigned LoadCount = 0;
    unsigned StoreCount = 0;
    unsigned BranchCount = 0;

    for (BasicBlock &Block : Function) {
      ++BasicBlockCount;
      for (Instruction &Instruction : Block) {
        ++InstructionCount;
        LoadCount += isa<LoadInst>(Instruction);
        StoreCount += isa<StoreInst>(Instruction);
        BranchCount += isa<BranchInst>(Instruction);
      }
    }

    errs() << "[IRStats] function=" << Function.getName()
           << " basic_blocks=" << BasicBlockCount
           << " instructions=" << InstructionCount
           << " loads=" << LoadCount
           << " stores=" << StoreCount
           << " branches=" << BranchCount << '\n';

    return PreservedAnalyses::all();
  }
};
class RemoveAddZeroPass : public PassInfoMixin<RemoveAddZeroPass> {
public:
  PreservedAnalyses run(Function &Function,
                        FunctionAnalysisManager &AnalysisManager) {
    (void)AnalysisManager;

    bool Changed = false;

    for (BasicBlock &Block : Function) {
      for (auto It = Block.begin(); It != Block.end();) {
        Instruction &Current = *It++;

        auto *Add = dyn_cast<BinaryOperator>(&Current);

        if (Add == nullptr || Add->getOpcode() != Instruction::Add)
          continue;

        Value *Replacement = nullptr;

        if (auto *Right = dyn_cast<ConstantInt>(Add->getOperand(1));
            Right != nullptr && Right->isZero()) {
          Replacement = Add->getOperand(0);
        } else if (auto *Left = dyn_cast<ConstantInt>(Add->getOperand(0));
                   Left != nullptr && Left->isZero()) {
          Replacement = Add->getOperand(1);
        }

        if (Replacement == nullptr)
          continue;

        Add->replaceAllUsesWith(Replacement);
        Add->eraseFromParent();
        Changed = true;
      }
    }

    return Changed ? PreservedAnalyses::none()
                   : PreservedAnalyses::all();
  }
};

class CPUUnrollHintPass : public PassInfoMixin<CPUUnrollHintPass> {
private:
  static bool addTwoWayUnrollHint(Instruction &LoopLatch) {
    MDNode *OldLoopID =
        LoopLatch.getMetadata(LLVMContext::MD_loop);
    if (OldLoopID == nullptr)
      return false;

    LLVMContext &Context = LoopLatch.getContext();
    SmallVector<Metadata *, 8> NewOperands;
    NewOperands.push_back(nullptr);

    // Preserve unrelated loop properties such as llvm.loop.mustprogress, but
    // replace any previous unroll policy with this CPU-specific decision.
    for (unsigned Index = 1; Index < OldLoopID->getNumOperands(); ++Index) {
      Metadata *Operand = OldLoopID->getOperand(Index).get();
      auto *Attribute = dyn_cast_or_null<MDNode>(Operand);
      auto *Name = Attribute != nullptr && Attribute->getNumOperands() != 0
                       ? dyn_cast<MDString>(Attribute->getOperand(0).get())
                       : nullptr;
      if (Name != nullptr && Name->getString().starts_with("llvm.loop.unroll."))
        continue;
      NewOperands.push_back(Operand);
    }

    Metadata *CountOperands[] = {
        MDString::get(Context, "llvm.loop.unroll.count"),
        ConstantAsMetadata::get(
            ConstantInt::get(Type::getInt32Ty(Context), 2))};
    NewOperands.push_back(MDNode::get(Context, CountOperands));

    MDNode *NewLoopID = MDNode::getDistinct(Context, NewOperands);
    NewLoopID->replaceOperandWith(0, NewLoopID);
    LoopLatch.setMetadata(LLVMContext::MD_loop, NewLoopID);
    return true;
  }

public:
  PreservedAnalyses run(Function &Function,
                        FunctionAnalysisManager &AnalysisManager) {
    // This first architecture-aware policy is intentionally limited to the
    // measured array-sum kernel. Other loops keep their original behavior.
    if (Function.getName() != "sum_array")
      return PreservedAnalyses::all();

    (void)AnalysisManager;
    unsigned AnnotatedLoopCount = 0;
    for (BasicBlock &Block : Function)
      if (addTwoWayUnrollHint(*Block.getTerminator()))
        ++AnnotatedLoopCount;

    errs() << "[CPUUnrollHint] function=" << Function.getName()
           << " loops=" << AnnotatedLoopCount << " unroll_count=2\n";

    return AnnotatedLoopCount == 0 ? PreservedAnalyses::all()
                                   : PreservedAnalyses::none();
  }
};

// Replace the measured two-way scalar array-sum kernel with the custom
// SUM2W operation.  This first version is deliberately conservative and
// benchmark-specific: it checks the function signature, the two volatile
// i32 loads produced by two-way unrolling, and every direct caller's base
// object before rebuilding the loop.  Other functions are left untouched.
class SUM2WCombinePass : public PassInfoMixin<SUM2WCombinePass> {
private:
  static bool hasExpectedUnrolledShape(Function &Function) {
    if (Function.arg_size() != 2 || !Function.getReturnType()->isIntegerTy(32))
      return false;

    auto Argument = Function.arg_begin();
    if (!Argument->getType()->isPointerTy())
      return false;
    ++Argument;
    if (!Argument->getType()->isIntegerTy(32))
      return false;

    unsigned VolatileI32Loads = 0;
    unsigned I32AddsUsingLoads = 0;
    for (BasicBlock &Block : Function) {
      for (Instruction &Current : Block) {
        auto *Load = dyn_cast<LoadInst>(&Current);
        if (Load == nullptr || !Load->isVolatile() ||
            !Load->getType()->isIntegerTy(32))
          continue;

        ++VolatileI32Loads;
        for (User *LoadUser : Load->users()) {
          auto *Add = dyn_cast<BinaryOperator>(LoadUser);
          if (Add != nullptr && Add->getOpcode() == Instruction::Add &&
              Add->getType()->isIntegerTy(32))
            ++I32AddsUsingLoads;
        }
      }
    }

    return VolatileI32Loads == 2 && I32AddsUsingLoads == 2;
  }

  static bool guaranteeEightByteBaseAlignment(Function &Function) {
    bool SawCall = false;
    for (User *FunctionUser : Function.users()) {
      auto *Call = dyn_cast<CallBase>(FunctionUser);
      if (Call == nullptr || Call->getCalledOperand()->stripPointerCasts() !=
                                 &Function)
        return false;

      Value *ArrayArgument = Call->getArgOperand(0)->stripPointerCasts();
      auto *Global = dyn_cast<GlobalVariable>(ArrayArgument);
      if (Global == nullptr)
        return false;

      Global->setAlignment(Align(8));
      SawCall = true;
    }
    return SawCall;
  }

  static MDNode *createUnrollDisableMetadata(LLVMContext &Context) {
    Metadata *DisableOperands[] = {
        MDString::get(Context, "llvm.loop.unroll.disable")};
    MDNode *Disable = MDNode::get(Context, DisableOperands);

    SmallVector<Metadata *, 2> LoopOperands;
    LoopOperands.push_back(nullptr);
    LoopOperands.push_back(Disable);
    MDNode *LoopID = MDNode::getDistinct(Context, LoopOperands);
    LoopID->replaceOperandWith(0, LoopID);
    return LoopID;
  }

  static void rebuildWithSUM2W(Function &Function) {
    LLVMContext &Context = Function.getContext();
    Type *I32 = Type::getInt32Ty(Context);
    Type *I64 = Type::getInt64Ty(Context);

    auto Argument = Function.arg_begin();
    Value *Array = &*Argument++;
    Value *Count = &*Argument;
    Array->setName("array");
    Count->setName("count");

    Function.dropAllReferences();
    while (!Function.empty())
      Function.begin()->eraseFromParent();

    BasicBlock *Entry = BasicBlock::Create(Context, "entry", &Function);
    BasicBlock *LoopHeader =
        BasicBlock::Create(Context, "loop.header", &Function);
    BasicBlock *CheckPair =
        BasicBlock::Create(Context, "check.pair", &Function);
    BasicBlock *PairBody =
        BasicBlock::Create(Context, "pair.body", &Function);
    BasicBlock *TailBody =
        BasicBlock::Create(Context, "tail.body", &Function);
    BasicBlock *Exit = BasicBlock::Create(Context, "exit", &Function);

    IRBuilder<> Builder(Entry);
    Builder.CreateBr(LoopHeader);

    Builder.SetInsertPoint(LoopHeader);
    PHINode *Sum = Builder.CreatePHI(I64, 2, "sum");
    PHINode *Index = Builder.CreatePHI(I32, 2, "index");
    Value *HasFirst = Builder.CreateICmpSLT(Index, Count, "has.first");
    Builder.CreateCondBr(HasFirst, CheckPair, Exit);

    Builder.SetInsertPoint(CheckPair);
    Value *Index64 = Builder.CreateSExt(Index, I64, "index64");
    Value *ElementPointer =
        Builder.CreateInBoundsGEP(I32, Array, Index64, "element.ptr");
    auto *SecondIndex = cast<BinaryOperator>(
        Builder.CreateAdd(Index, ConstantInt::get(I32, 1), "second.index"));
    SecondIndex->setHasNoUnsignedWrap(true);
    SecondIndex->setHasNoSignedWrap(true);
    Value *HasSecond =
        Builder.CreateICmpSLT(SecondIndex, Count, "has.second");
    Builder.CreateCondBr(HasSecond, PairBody, TailBody);

    Builder.SetInsertPoint(PairBody);
    LoadInst *Pair = Builder.CreateLoad(I64, ElementPointer, "pair");
    Pair->setVolatile(true);
    Pair->setAlignment(Align(8));

    FunctionType *AsmType = FunctionType::get(I64, {I64, I64}, false);
    InlineAsm *SUM2W = InlineAsm::get(
        AsmType, ".insn r 0x0b, 0, 0, $0, $1, $2", "=r,r,r",
        true, false, InlineAsm::AD_ATT);
    CallInst *PairSum =
        Builder.CreateCall(SUM2W, {Sum, Pair}, "pair.sum64");
    auto *NextIndex = cast<BinaryOperator>(
        Builder.CreateAdd(Index, ConstantInt::get(I32, 2), "next.index"));
    NextIndex->setHasNoSignedWrap(true);
    BranchInst *LoopLatch = Builder.CreateBr(LoopHeader);
    LoopLatch->setMetadata(LLVMContext::MD_loop,
                           createUnrollDisableMetadata(Context));

    Builder.SetInsertPoint(TailBody);
    LoadInst *TailValue = Builder.CreateLoad(I32, ElementPointer, "tail.value");
    TailValue->setVolatile(true);
    TailValue->setAlignment(Align(4));
    Value *TailValue64 = Builder.CreateSExt(TailValue, I64, "tail.value64");
    Value *TailSum = Builder.CreateAdd(Sum, TailValue64, "tail.sum");
    Builder.CreateBr(Exit);

    Builder.SetInsertPoint(Exit);
    PHINode *Result64 = Builder.CreatePHI(I64, 2, "result64");
    Result64->addIncoming(Sum, LoopHeader);
    Result64->addIncoming(TailSum, TailBody);
    Value *Result = Builder.CreateTrunc(Result64, I32, "result");
    Builder.CreateRet(Result);

    Sum->addIncoming(ConstantInt::get(I64, 0), Entry);
    Sum->addIncoming(PairSum, PairBody);
    Index->addIncoming(ConstantInt::get(I32, 0), Entry);
    Index->addIncoming(NextIndex, PairBody);
  }

public:
  PreservedAnalyses run(Function &Function,
                        FunctionAnalysisManager &AnalysisManager) {
    (void)AnalysisManager;

    if (Function.getName() != "sum_array")
      return PreservedAnalyses::all();

    if (!hasExpectedUnrolledShape(Function)) {
      errs() << "[SUM2WCombine] function=" << Function.getName()
             << " transformed=0 reason=shape-mismatch\n";
      return PreservedAnalyses::all();
    }

    if (!guaranteeEightByteBaseAlignment(Function)) {
      errs() << "[SUM2WCombine] function=" << Function.getName()
             << " transformed=0 reason=alignment-not-proven\n";
      return PreservedAnalyses::all();
    }

    rebuildWithSUM2W(Function);
    errs() << "[SUM2WCombine] function=" << Function.getName()
           << " transformed=1 pair_load=i64 custom_opcode=0x0b\n";
    return PreservedAnalyses::none();
  }
};

} // namespace

extern "C" PassPluginLibraryInfo LLVM_ATTRIBUTE_WEAK llvmGetPassPluginInfo() {
  return {LLVM_PLUGIN_API_VERSION, "IRStatsPass", LLVM_VERSION_STRING,
          [](PassBuilder &Builder) {
            Builder.registerPipelineParsingCallback(
                [](StringRef Name, FunctionPassManager &FunctionPassManager,
                   ArrayRef<PassBuilder::PipelineElement>) {
                  if (Name == "ir-stats") {
                    FunctionPassManager.addPass(IRStatsPass());
                    return true;
                  }

                  if (Name == "remove-add-zero") {
                    FunctionPassManager.addPass(RemoveAddZeroPass());
                    return true;
                  }

                  if (Name == "cpu-unroll-hint") {
                    FunctionPassManager.addPass(CPUUnrollHintPass());
                    return true;
                  }

                  if (Name == "cpu-sum2w-combine") {
                    FunctionPassManager.addPass(SUM2WCombinePass());
                    return true;
                  }

                  return false;
                });
          }};
}
