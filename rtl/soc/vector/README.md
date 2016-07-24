# Vector processor

Floating point vector processor unit
that runs parallel with f32c core, 
exchanging data over DMA.
It can be also used as video blitter.

Vector is 1-dimensional array of floats.
Vector operation applies same arithmetic
function to elements of the arrays, each-to-each.
For example 2048-element vector oparation

    a = b * c

does

    for(i = 0; i < 2048; i++)
      a[i] = b[i] * c[i];

In 2048 clock cycles.

In real code run, expect additional latency
for RAM I/O (large) and small (few cycles) to
start the functional unit pipeline.

Vector data doesn't have to be a contiguous array
but can be given in a form of linked list with pointers
to values scattered accross the whole RAM. 

Speed recommendations:

    * choose alghorithm that utilizes more full length
      vector register operations with less I/O.
    * I/O is faster for data in larger contiguous arrays
      when the RAM burst can be used.

Status of the vector processor:

    * 4 x 32-bit MMIO control and interrupt registers
    * 8 x uint32_t[2048] dual-port BRAM vector registers
    * I/O load and store using AXI RAM DMA burst
      can run parallel with arithmetic operations
    * 3 x 32-bit floating point functional units:
      6-stage (+,-)
      6-stage (*)
      13-stage (/)
    * each vector is double-aliased and can be independently
      used in 2 parallel or chained operations
    * any-to-any vector operations: a = b+c, a = b+b, a = a+b, a = a+a
      a=a+a is done in-place using double-alias
    * parallel: a = a+b, c = d*e, f = g/h
    * chaining: a = b+c, d = a*f, g = d/c
    * sub-vectors: arguments and results can be limited to index range
    * constants and halfs are special case of sub-vectors
    * interrupt flag for each vector set when done
    * works at 100 MHz clock rate on artix-7 and spartan-6
    * produces 1 result per 1 clock cycle
      after initial 6-13 clocks delay, depending on functional unit
    * theoretical maximum speed approaches 3 MFLOPs/MHz
      when 1 I/O and 3 FPU operations are running parallel
    * linked list support

Todo:

    * tighten up AXI states and reduce latency
    * connect interrupt reduction-or to MIPS CPU
