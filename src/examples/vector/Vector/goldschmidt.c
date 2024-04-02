#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <math.h>
#include "vector_link.h"
#include "goldschmidt.h"

#define PRECISION_BITS 27
#define ITERATION_STEPS 6

#define REVEAL_MSB(x) ( (1<<MANTISSA_BITS) | x )

struct goldschmit_s
{
  uint64_t a:PRECISION_BITS;
  uint64_t not_a:PRECISION_BITS;
  uint64_t next_a:PRECISION_BITS;
  uint64_t b:(PRECISION_BITS+1);
  uint64_t c:(PRECISION_BITS+1);
  uint64_t next_b:(PRECISION_BITS+1);
  uint64_t ac:(2*PRECISION_BITS+1);
  uint64_t bc:(2*PRECISION_BITS+2);
  uint64_t expfix:(EXPONENT_BITS);
  uint64_t next_expfix:(EXPONENT_BITS);
};

void divide_goldschmidt(union ifloat_u *result, union ifloat_u *x, union ifloat_u *y)
{
  union ifloat_u a,b;

  struct goldschmit_s g;
  int i;
  int n=ITERATION_STEPS;
  
  a = *y;
  b = *x;
  #if 0
  char line[20];
  print("\n");
  float2hex(line, &b);
  print(line);
  print("\n");
  float2hex(line, &a);
  print(line);
  print("\n");
  #endif
  g.a = REVEAL_MSB(a.part.mantissa) << (PRECISION_BITS-MANTISSA_BITS-1);
  g.b = REVEAL_MSB(b.part.mantissa) << (PRECISION_BITS-MANTISSA_BITS-1);
  g.expfix=0;
  g.next_expfix=0;
  for(i = 0; i < n; i++)
  {
    g.not_a = ~g.a;
    //g.c = (1<<PRECISION_BITS) | ((g.not_a + 1) & ((1<<PRECISION_BITS)-1));
    g.c = (1<<PRECISION_BITS) | (g.not_a & ((1<<PRECISION_BITS)-1));
    g.ac = (uint64_t)g.a * g.c;
    g.bc = (uint64_t)g.b * g.c;
    g.next_a = g.ac >> PRECISION_BITS;
    // renormalization test
    if( (g.bc & ((uint64_t)1<<(2*PRECISION_BITS+0))) == 0)
    {
      g.next_b = g.bc >> PRECISION_BITS;
    }
    else
    {
      // mantissa MSB bit becomes 1
      // shift it down and fix the exponent
      g.next_b = g.bc >> (PRECISION_BITS+1);
      g.next_expfix++;
    }
    if(i == 0)
    {
      #if 1
      // this may be omitted, initialized before for()-loop
      g.a = REVEAL_MSB(a.part.mantissa) << (PRECISION_BITS-MANTISSA_BITS-1);
      g.b = REVEAL_MSB(b.part.mantissa) << (PRECISION_BITS-MANTISSA_BITS-1);
      g.expfix=0;
      g.next_expfix=0;
      #endif
    }
    if(i > 0)
    {
      #if 0
      printf("g.a = %08x, g.b=%08x, g.c=%08x\n", g.a, g.b, g.c);
      uint32_t gacl, gach, gbcl, gbch;
      gach = (g.ac>>32)&0xFFFFFFFF;
      gacl = g.ac&0xFFFFFFFF;
      gbch = (g.bc>>32)&0xFFFFFFFF;
      gbcl = g.bc&0xFFFFFFFF;
      printf("g.ac %08x%08x g.bc %08x%08x\n", gach, gacl, gbch, gbcl);
      printf("g.next_a = %08x, g.next_b=%08x expfix=%d\n", g.next_a, g.next_b, g.next_expfix);
      #endif
      g.a = g.next_a;
      g.b = g.next_b;
      g.expfix = g.next_expfix;
    }
  }

  result->part.sign = a.part.sign ^ b.part.sign;
  result->part.exponent = b.part.exponent - a.part.exponent + ((1<<(EXPONENT_BITS-1))-2) + g.expfix;
  result->part.mantissa = g.b >> (PRECISION_BITS-MANTISSA_BITS-1);
  
  return;
}

