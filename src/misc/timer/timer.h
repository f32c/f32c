#include <stdint.h>

/* CPU clock in Hz */
// #define CLOCK 81207000L
#define CLOCK 81250000L
/* bits of the timer counter C_bits */
#define TIMER_BITS 12
/* register of size more or equal max(C_bits, C_bits+C_pres), max 32 bits */
#define R_TYPE uint32_t
/* number of prescaler bits from vhd C_pres */
#define PRESCALER_BITS 10
/* number of fractional period bits from vhd C_period_frac */
#define FRAC_BITS 0

/* timer base address in i/o space */
#define TIMADR -128

#define TC_COUNTER    0
#define TC_INCREMENT  1
#define TC_INC_MIN    2
#define TC_INC_MAX    3
#define TC_PERIOD     TC_INC_MIN
#define TC_FRACTIONAL TC_INC_MAX
#define TC_OCP1_START 4
#define TC_OCP1_STOP  5
#define TC_OCP2_START 6
#define TC_OCP2_STOP  7
#define TC_ICP1_START 10
#define TC_ICP1_STOP  11
#define TC_ICP2_START 8
#define TC_ICP2_STOP  9
#define TC_ICP1       12
#define TC_ICP2       13
#define TC_CONTROL    14
#define TC_APPLY      15

#define TCTRL_IF_OCP1 (0)
#define TCTRL_IF_OCP2 (1)
#define TCTRL_IF_ICP1 (3)
#define TCTRL_IF_ICP2 (2)
#define TCTRL_AND_OR_OCP1 (4)
#define TCTRL_AND_OR_OCP2 (5)
#define TCTRL_AND_OR_ICP1 (7)
#define TCTRL_AND_OR_ICP2 (6)
#define TCTRL_IE_OCP1 (8)
#define TCTRL_IE_OCP2 (9)
#define TCTRL_IE_ICP1 (11)
#define TCTRL_IE_ICP2 (10)
#define TCTRL_XOR_OCP1 (12)
#define TCTRL_XOR_OCP2 (13)
#define TCTRL_XOR_ICP1 (15)
#define TCTRL_XOR_ICP2 (14)
#define TCTRL_AFCEN_ICP1 (16)
#define TCTRL_AFCEN_ICP2 (18)
#define TCTRL_AFCINV_ICP1 (17)
#define TCTRL_AFCINV_ICP2 (19)

#if 0
#define T_COUNTER    (R_TYPE *)(TIMADR+4*TC_COUNTER)
#define T_PERIOD     (R_TYPE *)(TIMADR+4*TC_PERIOD)
#define T_INCREMENT  (R_TYPE *)(TIMADR+4*TC_INCREMENT)
#define T_FRACTIONAL (R_TYPE *)(TIMADR+4*TC_FRACTIONAL)
#define T_CONTROL    (R_TYPE *)(TIMADR+4*TC_CONTROL)
#define T_CONTROL_AND_OR (R_TYPE *)(TIMADR+4*TC_CONTROL+1)
#define T_APPLY      (R_TYPE *)(TIMADR+4*TC_APPLY)
#define T_OCP1_START (R_TYPE *)(TIMADR+4*TC_OCP1_START)
#define T_OCP1_STOP  (R_TYPE *)(TIMADR+4*TC_OCP1_STOP)
#define T_OCP2_START (R_TYPE *)(TIMADR+4*TC_OCP2_START)
#define T_OCP2_STOP  (R_TYPE *)(TIMADR+4*TC_OCP2_STOP)
#define T_ICP1_START (R_TYPE *)(TIMADR+4*TC_ICP1_START)
#define T_ICP1_STOP  (R_TYPE *)(TIMADR+4*TC_ICP1_STOP)
#define T_ICP2_START (R_TYPE *)(TIMADR+4*TC_ICP2_START)
#define T_ICP2_STOP  (R_TYPE *)(TIMADR+4*TC_ICP2_STOP)
#define T_ICP1       (R_TYPE *)(TIMADR+4*TC_ICP1)
#define T_ICP2       (R_TYPE *)(TIMADR+4*TC_ICP2)
#define T_INC_MIN    (R_TYPE *)(TIMADR+4*TC_INC_MIN)
#define T_INC_MAX    (R_TYPE *)(TIMADR+4*TC_INC_MAX)
#endif

volatile uint8_t  *LED = (uint8_t *)(-239);

volatile uint32_t *TIMER = (uint32_t *)(TIMADR);

#if 0
volatile R_TYPE *counter = T_COUNTER;
volatile R_TYPE *period = T_PERIOD;
volatile R_TYPE *increment = T_INCREMENT;
volatile R_TYPE *fractional = T_FRACTIONAL;
volatile R_TYPE *control = T_CONTROL;
volatile R_TYPE *control_and_or = T_CONTROL_AND_OR;
volatile R_TYPE *apply = T_APPLY;
volatile R_TYPE *ocp1_start = T_OCP1_START;
volatile R_TYPE *ocp1_stop = T_OCP1_STOP;
volatile R_TYPE *ocp2_start = T_OCP2_START;
volatile R_TYPE *ocp2_stop = T_OCP2_STOP;
volatile R_TYPE *icp1_start = T_ICP1_START;
volatile R_TYPE *icp1_stop = T_ICP1_STOP;
volatile R_TYPE *icp2_start = T_ICP2_START;
volatile R_TYPE *icp2_stop = T_ICP2_STOP;
#endif
