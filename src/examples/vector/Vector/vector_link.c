#include <stdio.h>
#include <unistd.h>
#include <stdint.h>
#include <stdlib.h>
#include <math.h>
#include "vector_link.h"
#include "goldschmidt.h"

/* linked list vector test */

volatile uint32_t *vector_mmio = (volatile uint32_t *)0xFFFFFC20;

struct vector_register_s *vr[VECTOR_REGISTERS]; // 8 vector registers

void print(char *a)
{
  printf("%s", a);
}

int vector_detect(void)
{
  return vector_mmio[4] == 0xDEBA66AA ? 1 : 0; // magic number that detects vector processor presence
}

// define some vectors and headers
// malloc the data and return pointer to header struct
// creates segments in reverse order (this is simpler for ppinter linkage)
volatile struct vector_header_s *create_segmented_vector(int n, int m)
{
  // create multi-segment randomly splitted vector of total length n
  volatile struct vector_header_s *vh = NULL, *new_vh; // vector-headers
  
  // each segment max length m
  int total_length = 0, segment_length = n;
  int i; // segment counter
  for(i = 0; total_length < n; total_length+=segment_length, i++)
  {
    if(m)
      // segment_length = m;
      segment_length = 1+(rand() % m);
    // clip segment length for total n
    if(total_length + segment_length > n)
      segment_length = n - total_length;

    new_vh = (volatile struct vector_header_s *)malloc(sizeof(struct vector_header_s)); // alloc the header
    new_vh->next = vh; // link it in front
    vh = new_vh;

    // create the data segment
    union ifloat_u *data = (union ifloat_u *)malloc(segment_length*sizeof(union ifloat_u));
    // fill it with data
    int j;
    for(j = 0; j < segment_length; j++)
      data[j].f = 0.0;

    // link the data
    vh->data = data;
    vh->length = segment_length-1; // hardware uses 1 less than actual length

    //for(int j = 0; j < segment_length; j++)
    //  printf("%e\n", vh->data[j].f);
    //printf("%d len %d\n", i, segment_length);
  }
  //printf("total %d\n", total_length);
  return vh;
}

// convert float into hex-float notation
// -876543x-21 = -0x876543 * 2^(-0x21) = -1.032986e-03
// pyhton >>> -1.0 * 0x876543 * 2**(-0x21)
void float2hex(char *hex, union ifloat_u *a)
{
  uint64_t mantissa;
  int exponent, abs_exp;
  char sign_exp;
  int i;
  uint8_t hexdigit;
  
  mantissa = a->part.mantissa | (1<<MANTISSA_BITS); // unhide MSB bit
  exponent = a->part.exponent - EXPONENT_OFFSET;
  exponent -= MANTISSA_BITS;
  // exponent = a->part.exponent;
  hex[0] = a->part.sign ? '-' : '+';
  for(i = 0; i < (MANTISSA_BITS+1)/4; i++)
  {
    hexdigit = '0' + ((mantissa >> (MANTISSA_BITS-3)) & 0xF);
    if(hexdigit > '9')
      hexdigit += 'A'-'0'-10;
    hex[1+i] = hexdigit;
    mantissa <<= 4;
  }
  hex[1+(MANTISSA_BITS+1)/4] = 'x';
  sign_exp = exponent < 0 ? '-' : '+';
  abs_exp = exponent < 0 ? -exponent : exponent;
  hex[2+(MANTISSA_BITS+1)/4] = sign_exp;
  for(i = 0; i < EXPONENT_BITS/4; i++)
  {
    hexdigit = '0' + ((abs_exp >> (EXPONENT_BITS-4)) & 0xF);
    if(hexdigit > '9')
      hexdigit += 'A'-'0'-10;
    hex[3+(MANTISSA_BITS+1)/4+i] = hexdigit;
    abs_exp <<= 4;
  }
  hex[3+(MANTISSA_BITS+1)/4+EXPONENT_BITS/4] = '\0';
}

void test_float2hex(void)
{
  union ifloat_u v[20];
  char line[100];

  v[0].part.mantissa = 0x876543 & ((1<<(MANTISSA_BITS))-1);
  v[0].part.sign = 1;
  v[0].part.exponent = 0xB7;
  float2hex(line, v);
  print(line);
  float a;
  a = -0x876543 * powf(2.0, -0x21);
  sprintf(line, "float %e\n", a);
  print(line);
}

int iabs(int a)
{
  return a > 0 ? a : -a;
}

void printvector(volatile struct vector_header_s *vh, int from, int to)
{
  int i, j, l, n = 0;
  char line[100];
  //int total = 0;
  
  for(i = 0; vh != NULL; i++, vh = vh->next)
  {
    l = vh->length;
    // printf("segment %d length %d\n", i, l);
    for(j = 0; j <= l; j++)
    {
      if(n >= from && n <= to)
      {
        printf("%d:", n);
        float2hex(line, &(vh->data[j]));
        print(line);
        if(j < l)
          print(" ");
        else
          print(",");
      }
      n++;
    }
    //total += l+1;
  }
  sprintf(line, "total %d\n", n);
  print(line);
}

void soft_alloc_vector_registers(int n)
{
 int i;
 for(i = 0; i < n; i++)
   vr[i] = (struct vector_register_s *)malloc(sizeof(struct vector_register_s));
}

// soft vector I/O operation
// load/store i-th register with data from/to RAM
// store_mode
// 0:load
// 1:store
void soft_vector_io(int i, volatile struct vector_header_s *vh, int store_mode)
{
  int e = 0;
  int j = 0;
  int sl;

  for(; vh != NULL; vh = vh->next)
  {
    sl = vh->length + 1;
    if(e + sl > VECTOR_MAXLEN)
      sl = VECTOR_MAXLEN-e;
    if(store_mode)
    {
      for(j = 0; j < sl; j++)
        vh->data[j] = vr[i]->data[e++];
    }
    else
    {
      for(j = 0; j < sl; j++)
        vr[i]->data[e++] = vh->data[j];
    }
  }
  vr[i]->length = e-1;
}

// wait for vector done
// all bits in mask must appear in order to exit this function
void wait_vector_mask(uint32_t mask)
{
  uint32_t i=0, a;
  do
  {
    a = vector_mmio[1];
  } while((a & mask) != mask && ++i < 400000);
  vector_mmio[1] = mask; // clear interrupt flag(s)
}

// wait for first interrupt flag to be set
void wait_vector(void)
{
  uint32_t i=0, a;
  do
  {
    a = vector_mmio[1];
  } while(a == 0 && ++i < 400000);
  vector_mmio[1] = a; // clear interrupt flag(s)
}

void hard_init()
{
  vector_mmio[1] = 0xFFFFFFFF; // clear all interrupts
}

void dcache_flush(volatile void *p, int len)
{
  #ifdef __F32C__
  do 
  {
    __asm __volatile__("cache 1, 0(%0)" : : "r" (p));
    p += 4;
    len -= 4;
  }
  while(len > 0);
  #endif
}

void vector_flush(volatile struct vector_header_s *vh)
{
  for(; vh != NULL; vh = vh->next)
  {
    dcache_flush(vh, sizeof(struct vector_header_s));
    dcache_flush(vh->data, (vh->length + 1) * sizeof(union ifloat_u));
  }
}

void hard_vector_range(int i, uint16_t start, uint16_t stop)
{
  vector_mmio[4] = 0xA0000000 | i | (start<<4) | (stop<<16);
}

void hard_vector_io(int i, volatile struct vector_header_s *vh, int store_mode)
{
  #if HARD_USE_SOFT
    soft_vector_io(i, vh, store_mode);
  #else
    vector_mmio[0] = (uint32_t) vh;
    if(store_mode == 0)
    {
      #if 0
      uint16_t length = -1;
      for(; vh != NULL; vh = vh->next)
        length += 1 + vh->length;
      length %= VECTOR_MAXLEN; // limit max length with bitmask
      //vector_flush(vh);
      uint16_t start = 0, stop = length;
      vector_mmio[4] = 0xA0000000 | i | (start<<4) | (stop<<16);
      #endif
      vector_mmio[4] = 0xE3000000 | i | (i<<4); // load vector
      wait_vector_mask((1<<i)|(1<<16));
    }
    else
    {
      vector_mmio[4] = 0xE381F000 | i | (i<<4); // store vector
      wait_vector_mask(1<<16);
      // for the CPU to be able to use stored vector, we must flush CPU cache
      vector_flush(vh);
    }
  #endif
}

// double value of the soft vector
void soft_vector_2x_int(int n)
{
  int i;
  for(i = 0; i <= vr[n]->length; i++)
    vr[n]->data[i].part.exponent++;
}

void soft_vector_2x_float(int n)
{
  int i;
  for(i = 0; i <= vr[n]->length; i++)
    vr[n]->data[i].f *= 2;
}

void soft_vector_random(int n)
{
  int i;
  for(i = 0; i <= vr[n]->length; i++)
    vr[n]->data[i].f = 1.0 * ( (rand()-RAND_MAX) / (1.0+i));
}

void soft_vector_incremental(int n)
{
  int i;
  for(i = 0; i <= vr[n]->length; i++)
    vr[n]->data[i].f = 1.0*(1+i);
}

// soft vector float arithmetic operation
// 0: a = b + c
// 1: a = b - c
// 2: a = b * c
// 3: a = b / c
void soft_vector_oper(int a, int b, int c, int oper)
{
  int i;
  // result length is the smallest of the both
  vr[a]->length = vr[b]->length < vr[c]->length ? vr[b]->length : vr[c]->length;
  if(oper == 0)
    for(i = 0; i <= vr[a]->length; i++)
      vr[a]->data[i].f = vr[b]->data[i].f + vr[c]->data[i].f;
  if(oper == 1)
    for(i = 0; i <= vr[a]->length; i++)
      vr[a]->data[i].f = vr[b]->data[i].f - vr[c]->data[i].f;
  if(oper == 2)
    for(i = 0; i <= vr[a]->length; i++)
      vr[a]->data[i].f = vr[b]->data[i].f * vr[c]->data[i].f;
  #if SOFT_USE_GOLDSCHMIDT
  if(oper == 3)
    for(i = 0; i <= vr[a]->length; i++)
      divide_goldschmidt(&vr[a]->data[i], &vr[b]->data[i], &vr[c]->data[i]);
  #else
  if(oper == 3)
    for(i = 0; i <= vr[a]->length; i++)
      vr[a]->data[i].f = vr[b]->data[i].f / vr[c]->data[i].f;
  #endif
}

void hard_vector_oper(int a, int b, int c, int oper)
{
  #if HARD_USE_SOFT
    int i;
    // hardware math will use software operation
    if(oper < 3)
      soft_vector_oper(a, b, c, oper);
    else
      for(i = 0; i <= vr[a]->length; i++)
        divide_goldschmidt(&vr[a]->data[i], &vr[b]->data[i], &vr[c]->data[i]);
  #else
    // hardware math will use vector processor
    if(oper == 0)
      vector_mmio[4] = 0xE0003000 | a | (b<<4) | (c<<8); // a=b+c float (selected by index)
    if(oper == 1)
      vector_mmio[4] = 0xE0403000 | a | (b<<4) | (c<<8); // a=b-c float (selected by index)
    if(oper == 2)
      vector_mmio[4] = 0xE1004000 | a | (b<<4) | (c<<8); // a=b*c float (selected by index)
    if(oper == 3)
      vector_mmio[4] = 0xE200B000 | a | (b<<4) | (c<<8); // a=b/c float (selected by index)
    if(oper == 4)
      vector_mmio[4] = 0xE4040000 | a | (b<<4); // i2f, not supported by hardware
    if(oper == 5)
      vector_mmio[4] = 0xE4050000 | a | (b<<4); // f2i, not supported by hardware
    wait_vector_mask(1<<a);
  #endif
  return;
}

void vector_dumpreg(void)
{
  int i;
  for(i = 0; i < 5; i++)
    printf("%i: %08x\n", i,  vector_mmio[i]);
}

