#include "coremark.h"
#include "core_portme.h"

enum
{
    COREMARK_STATUS_BOOT = 0,
    COREMARK_STATUS_RUNNING = 1,
    COREMARK_STATUS_PASS = 2,
    COREMARK_STATUS_FAIL = 3,
    COREMARK_STATUS_FINISHED_NO_RESULT = 4
};

typedef struct
{
    unsigned long magic;
    unsigned long status;
    unsigned long clock_value;
    unsigned long printf_count;
    unsigned long reserved;
    unsigned long exit_code;
} coremark_mailbox_t;

/* Fixed at the first 48 bytes of DMEM by link.ld. */
__attribute__((section(".coremark_mailbox"), aligned(8)))
volatile coremark_mailbox_t coremark_mailbox = {
    0x434f52454d41524bUL, /* "COREMARK" */
    COREMARK_STATUS_BOOT,
    0,
    0,
    0,
    0
};

#if VALIDATION_RUN
volatile ee_s32 seed1_volatile = 0x3415;
volatile ee_s32 seed2_volatile = 0x3415;
volatile ee_s32 seed3_volatile = 0x66;
#endif
#if PERFORMANCE_RUN
volatile ee_s32 seed1_volatile = 0x0;
volatile ee_s32 seed2_volatile = 0x0;
volatile ee_s32 seed3_volatile = 0x66;
#endif
#if PROFILE_RUN
volatile ee_s32 seed1_volatile = 0x8;
volatile ee_s32 seed2_volatile = 0x8;
volatile ee_s32 seed3_volatile = 0x8;
#endif
volatile ee_s32 seed4_volatile = ITERATIONS;
volatile ee_s32 seed5_volatile = 0;

static CORETIMETYPE start_time_val;
static CORETIMETYPE stop_time_val;

static int
starts_with(const char *text, const char *prefix)
{
    while (*prefix != '\0')
    {
        if (*text != *prefix)
            return 0;
        text++;
        prefix++;
    }
    return 1;
}

/*
 * This clock is deliberately a functional-simulation placeholder.  It makes
 * a one-iteration CRC run pass CoreMark's minimum-time check, but it is not a
 * hardware performance counter and must not be used to report a score.
 */
CORETIMETYPE
barebones_clock(void)
{
    coremark_mailbox.clock_value += 10;
    return (CORETIMETYPE)coremark_mailbox.clock_value;
}

void
start_time(void)
{
    start_time_val = barebones_clock();
}

void
stop_time(void)
{
    stop_time_val = barebones_clock();
}

CORE_TICKS
get_time(void)
{
    return (CORE_TICKS)(stop_time_val - start_time_val);
}

secs_ret
time_in_secs(CORE_TICKS ticks)
{
    return (secs_ret)ticks;
}

ee_u32 default_num_contexts = 1;

void
portable_init(core_portable *p, int *argc, char *argv[])
{
    (void)argc;
    (void)argv;
    coremark_mailbox.status = COREMARK_STATUS_RUNNING;
    coremark_mailbox.clock_value = 0;
    coremark_mailbox.printf_count = 0;
    coremark_mailbox.exit_code = 0;
    p->portable_id = 1;
}

void
portable_fini(core_portable *p)
{
    if (coremark_mailbox.status == COREMARK_STATUS_RUNNING)
        coremark_mailbox.status = COREMARK_STATUS_FINISHED_NO_RESULT;
    p->portable_id = 0;
}

int
ee_printf(const char *fmt, ...)
{
    coremark_mailbox.printf_count++;

    if (starts_with(fmt, "Correct operation validated."))
        coremark_mailbox.status = COREMARK_STATUS_PASS;
    else if (starts_with(fmt, "Errors detected") ||
             starts_with(fmt, "Cannot validate operation"))
        coremark_mailbox.status = COREMARK_STATUS_FAIL;

    return 0;
}
