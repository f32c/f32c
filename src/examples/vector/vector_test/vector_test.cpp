extern "C"
{
#include <stdio.h> // printf
#include <stdlib.h>
#include <string.h>
#include <math.h>
}

/*
Elementary vector processor test.
Compares results of hardware Vector FPU
with software float arithmetic from C library.

Test result will appear on serial port
Open "Tools->Serial Monitor"
Successful test result looks like this:

test 0
+ total len:2048 errors:0
- total len:2048 errors:0
* total len:2048 errors:0
/ total len:2048 errors:0
test 1
+ total len:2048 errors:0
...

*/
#include "Vector/Vector.h"


/* linked list vector test */
// the vector values 2 input argumnets, 4 results for soft and hard
volatile struct vector_header_s *arg[2], *soft_result, *hard_result;

// returns
// -1  no error
// >=0 index of first error occurrence
int vector_difference(volatile struct vector_header_s *a, volatile struct vector_header_s *b)
{
  int ai = 0, bi = 0;
  int err_count = 0;
  int i;
  int first_error = -1;
  for(i = 0; i < VECTOR_MAXLEN; i++)
  {
    if(     a->data[ai].part.sign     != b->data[bi].part.sign
    ||      a->data[ai].part.exponent != b->data[bi].part.exponent
    ||  abs(a->data[ai].part.mantissa -  b->data[bi].part.mantissa) > 1 )
       err_count++;
    if(first_error < 0 && err_count == 1)
      first_error = i;
    if(ai++ >= a->length)
    {
      if(a->next == NULL)
        continue; // exit for-loop
      a = a->next;
      ai = 0;
    }
    if(bi++ >= b->length)
    {
      if(b->next == NULL)
        continue; // exit for-loop
      b = b->next;
      bi = 0;
    }
  }
  printf("total len:%d errors:%d\n", i, err_count);
  return first_error;
}

// run test n times
void run_test(int n)
{
  int i;
  int t;
  char operation[] = "+-*/"; 

  soft_alloc_vector_registers(3); // for software-float comparison test

  // create vectors in RAM for the arguments
  for(i = 0; i < 2; i++)
    arg[i] = create_segmented_vector(VECTOR_MAXLEN,VECTOR_MAXLEN/4);
  // create vectors in RAM for the results
  soft_result = create_segmented_vector(VECTOR_MAXLEN,VECTOR_MAXLEN/4);
  hard_result = create_segmented_vector(VECTOR_MAXLEN,VECTOR_MAXLEN/4);
  // first load vectors from RAM into soft registers
  // to get correct length, those registers will be used for random
  // generation
  soft_vector_io(0, arg[0], 0); // load vector reg vr[0] with value arg[0]
  soft_vector_io(1, arg[1], 0); // load vector reg vr[2] with value arg[1]

  for(t = 0; t < n; t++)
  {
    printf("test %d\n", t);
    soft_vector_random(0);
    soft_vector_random(1);
    soft_vector_io(0, arg[0], 1); // soft store random to arg[0]
    soft_vector_io(1, arg[1], 1); // soft store random to arg[1]
    hard_vector_range(0, 0, VECTOR_MAXLEN-1);
    hard_vector_io(0, arg[0], 0); // hard load vector reg vr[0] with value arg[0]
    hard_vector_range(2, 0, VECTOR_MAXLEN-1);
    hard_vector_io(2, arg[1], 0); // hard load vector reg vr[0] with value arg[1]
    hard_vector_range(4, 0, VECTOR_MAXLEN-1);
    for(i = 0; i < 4; i++)
    {
      int erri;
      printf("%c ", operation[i]);
      soft_vector_oper(2, 0, 1, i);   // compute vr[4] = vr[0] <oper> vr[2]
      soft_vector_io(2, soft_result, 1); // store to result
      hard_vector_oper(4, 0, 2, i);
      hard_vector_io(4, hard_result, 1);
      erri = vector_difference(hard_result, soft_result);
      if(erri >= 0)
      { // erri = index of 1st error occurence
        // print arguments and the results around the error occurence
        int around = 15;
        printf("arg[0]         ");
        printvector(arg[0], erri-around, erri+around);
        printf("arg[1]         ");
        printvector(arg[1], erri-around, erri+around);
        printf("soft_result[%i] ", i);
        printvector(soft_result, erri-around, erri+around);
        printf("hard_result[%i] ", i);
        printvector(hard_result, erri-around, erri+around);
      }
    }
  }
}

void setup()
{
  run_test(3); // run test N times
#if 0
  int i, j;
  // Elementary vector store test.
  // If run_test doesn't pass, this test should be used
  // to locate the problem.
  // Usual problems:

  // 1. Vector store writes almost all correct data,
  //    but some elements are repeated, skipped or position-shifted 
  //    (first check Vector DMA I/O module: bram_next signaling, FIFO, burst signaling)

  // 2. Arithmetic results are correct but position-shifted 
  //    (first check arduino Vector library, pipeline delay compensation,
  //     nibble "C" in vector execute command 0xE...C...)

  // Vectors "a" and "b" of total length "vlen" will be created in continuous RAM
  // segment for vector load.
  // For vector store stress test, vector "c" will have vlen total length but will
  // be subdivied in RAM into random length segments.
  // Each segment of vector "c" will have vlen_subdivide or less elements.
  // In hex vector print look for the colon "," - it delimits segments and
  // some of vector store problems may be related to segment dicontinuation.
  // Some store problems can be related to discontinuation by the RAM burst.
  // Xilinx 7-series AXI RAM burst is 64 elements long.

  int vlen = 70, vlen_subdivide = 10;
  struct vector_header_s *vh;
  Vector V;
  struct vector_header_s *a, *b, *c;

  a = V.create(vlen); // create vector of vlen elements
  b = V.create(vlen);
  c = V.create(vlen,10);
  for(i = 0, vh = a; vh != NULL; vh = vh->next)
    for(j = 0; j <= vh->length; j++, i++)
      vh->data[j].f = 5.1 + (3+i);
  for(i = 0, vh = b; vh != NULL; vh = vh->next)
    for(j = 0; j <= vh->length; j++, i++)
      vh->data[j].f = 1.0 / (1+i);
  for(i = 0, vh = c; vh != NULL; vh = vh->next)
    for(j = 0; j <= vh->length; j++, i++)
      vh->data[j].f = -6.6;
  for(i = 0; i < 3; i++)
    V.range(i, 0, vlen-1);
  V.load(0, a); // load v(0)=a
  V.load(1, a); // load v(1)=a, just to initialize size, v(1) has same data as v(0)
  V.load(2, b); // load v(2)=b
  //V.add(0, 1, 2); // v(0) = v(1)+v(2), actually does v(0) += v(2)
  V.store(c, 1);
  V.dumpreg();
  V.print(a); // print the vector
  V.print(b); // print the vector
  V.print(c); // print the vector
#endif
}

void main(void)
{
  run_test(10); // run test N times
}
