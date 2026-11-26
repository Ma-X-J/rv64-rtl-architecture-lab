/*
 * Branch-predictor benchmark for the RV64I teaching CPU.
 *
 * The program deliberately contains two different branch populations:
 *
 *   1. correlated_phase(): two branches read the same volatile condition.
 *      The condition is pseudo-random across iterations, so a bimodal BHT
 *      cannot predict it well, while a global-history predictor can learn
 *      that the second branch follows the first branch.
 *
 *   2. bimodal_phase(): a target branch changes direction in runs.  Two
 *      unrelated pseudo-random branches execute immediately before it,
 *      making a short GHR noisy.  A bimodal counter can follow the long runs
 *      with only a few transition misses.
 *
 * All arithmetic is shifts, XORs, adds and subtracts.  The build targets
 * rv64i explicitly and the generated disassembly is checked separately.
 */

typedef unsigned long u64;
typedef long          s64;

static volatile u64 result_guard;

/*
 * Give a non-speculative GHR, updated when a branch reaches MEM, enough time
 * to contain the preceding branch before the next measured branch is fetched.
 * These are real RV64I instructions and cannot be removed by the compiler.
 */
#define GHR_GAP()                                                           \
    __asm__ volatile (                                                      \
        "addi x0, x0, 0\n\t"                                                \
        "addi x0, x0, 0\n\t"                                                \
        "addi x0, x0, 0\n\t"                                                \
        "addi x0, x0, 0\n\t"                                                \
        "addi x0, x0, 0\n\t"                                                \
        "addi x0, x0, 0\n\t"                                                \
        ::: "memory")

/*
 * Clang can legally turn a small C if/else into SLTU plus arithmetic, which
 * would remove the very branch this benchmark is meant to measure.  This
 * RV64I-only fragment implements:
 *
 *     value += base;
 *     if (condition != 0)
 *         value += extra;
 *
 * with exactly one conditional branch and no unconditional control transfer.
 */
#define MEASURED_CONDITIONAL_ADD(value, condition, base, extra)             \
    __asm__ volatile (                                                      \
        "addi %0, %0, " #base "\n\t"                                        \
        "beq %1, x0, 1f\n\t"                                               \
        "addi %0, %0, " #extra "\n\t"                                       \
        "1:\n\t"                                                           \
        : "+r" (value)                                                      \
        : "r" (condition)                                                   \
        : "memory")

/* Toggle a register-held run state every eight iterations with one branch. */
#define UPDATE_RUN_STATE(remaining, run_value)                              \
    __asm__ volatile (                                                      \
        "addi %0, %0, -1\n\t"                                               \
        "bne %0, x0, 1f\n\t"                                               \
        "addi %0, x0, 8\n\t"                                               \
        "xori %1, %1, 1\n\t"                                               \
        "1:\n\t"                                                           \
        : "+r" (remaining), "+r" (run_value)                              \
        :                                                                    \
        : "memory")

static __attribute__((always_inline)) inline u64 rv64i_mix(u64 value)
{
    /*
     * The CPU currently implements SLLI but not SRLI.  An odd additive step
     * changes the low bit, while the left-shift/XOR steps spread changes into
     * higher bits without using RV64M or an unsupported right shift.
     */
    value += 0x9e3779b97f4a7c15UL;
    value ^= value << 7;
    value += value << 3;
    return value;
}

static __attribute__((noinline)) u64 correlated_phase(s64 iterations)
{
    u64 state = 0x9e3779b97f4a7c15UL;
    u64 score = 0x13579bdfUL;

    for (s64 i = 0; i < iterations; ++i) {
        u64 condition;

        state = rv64i_mix(state);
        condition = state & 1UL;

        /* Branch A: alternating and therefore hostile to a 2-bit BHT. */
        MEASURED_CONDITIONAL_ADD(score, condition, 1, 2);

        GHR_GAP();

        /* Branch B: always has the same result as the preceding branch A. */
        MEASURED_CONDITIONAL_ADD(score, condition, 2, 3);
    }

    result_guard = state;
    return score ^ state;
}

static __attribute__((noinline)) u64 bimodal_phase(s64 iterations)
{
    u64 state = 0xd1b54a32d192ed03UL;
    u64 score = 0x2468ace0UL;
    s64 run_remaining = 8;
    u64 run_value = 0;

    for (s64 i = 0; i < iterations; ++i) {
        u64 noise_0;
        u64 noise_1;

        UPDATE_RUN_STATE(run_remaining, run_value);

        /* Two unrelated branches deliberately make the 2-bit GHR noisy. */
        state = rv64i_mix(state);
        noise_0 = state & 1UL;
        MEASURED_CONDITIONAL_ADD(score, noise_0, 1, 6);

        GHR_GAP();

        state = rv64i_mix(state);
        noise_1 = state & 8UL;
        MEASURED_CONDITIONAL_ADD(score, noise_1, 2, 5);

        GHR_GAP();

        /*
         * This measured branch has runs of eight N outcomes followed by
         * eight T outcomes.  A bimodal counter follows each run, while the
         * global predictor sees four sparse/noisy GHR contexts.
         */
        MEASURED_CONDITIONAL_ADD(score, run_value, -19, 68);
    }

    result_guard = state ^ score;
    return score ^ state;
}

int main(void)
{
    u64 correlated_result = correlated_phase(512);
    u64 bimodal_result = bimodal_phase(512);

    /* Preserve both phases and return a deterministic self-check value. */
    result_guard ^= correlated_result;
    return (int)((correlated_result ^ bimodal_result ^ result_guard) & 0x7fUL);
}
