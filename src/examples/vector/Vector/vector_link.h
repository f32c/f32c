#ifndef VECTOR_LINK_H
#define VECTOR_LINK_H
#include <stdint.h>

#define VECTOR_REGISTERS 8
#define VECTOR_MAXLEN 2048

// for soft-float vector replacement
#define EXPONENT_BITS 8
#define MANTISSA_BITS 23
// offset for 0-exponent
#define EXPONENT_OFFSET ((1<<(EXPONENT_BITS-1))-1)

// soft-math will use internal goldschmidt's
// division instead of C-library floating point division
// to exactly match hardware results
#define SOFT_USE_GOLDSCHMIDT 1

// force hardware routines to use software math
#define HARD_USE_SOFT 0

struct ifloat_s
{
  uint32_t mantissa:MANTISSA_BITS, exponent:EXPONENT_BITS, sign:1;
};

union ifloat_u
{
  float f;
  struct ifloat_s part;
};

struct vector_header_s
{
  uint16_t length; // length=0 means 1 element, length=1 means 2 elements etc. 
  uint16_t type;
  union ifloat_u *data;
  volatile struct vector_header_s *next;
};


struct vector_register_s
{
  int length; // actual number of elements
  union ifloat_u data[VECTOR_MAXLEN]; // the data array
};

extern struct vector_register_s *vr[VECTOR_REGISTERS]; // 8 vector registers

extern volatile uint32_t *vector_mmio;

void print(char *a);
volatile struct vector_header_s *create_segmented_vector(int n, int m);
void float2hex(char *hex, union ifloat_u *a);
void test_float2hex(void);
void printvector(volatile struct vector_header_s *vh, int from, int to);
void soft_alloc_vector_registers(int n);
void soft_vector_io(int i, volatile struct vector_header_s *vh, int store_mode);
void vector_flush(volatile struct vector_header_s *vh);
void hard_init(void);
void hard_vector_range(int i, uint16_t start, uint16_t stop);
void hard_vector_io(int i, volatile struct vector_header_s *vh, int store_mode);
void soft_vector_oper(int a, int b, int c, int oper);
void hard_vector_oper(int a, int b, int c, int oper);
void wait_vector_mask(uint32_t mask);
void wait_vector(void);
void soft_vector_random(int n);
void soft_vector_incremental(int n);
void vector_dumpreg(void);
int vector_detect(void);

#endif
