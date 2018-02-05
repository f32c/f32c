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
    * 8 x float[2048] dual-port BRAM vector registers
    * I/O load and store using AXI RAM DMA burst
      can run parallel with arithmetic operations
    * 3 x 32-bit floating point functional units:
      5-stage (+,-)
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

    * MMIO constants to report hardware capabilities
      number of vectors
      maximum vector size
      bitmap of functional units enabled

# Architecture

Each vector register is made of one BRAM block
Each BRAM block has two ports which can read or write content
independenty and parallel from 2 different functional units.

Functional unit does elementary arithmetic operation taking
2 arguments as input and providing one result as output, or does
I/O to RAM. There are 4 functional units:

    unit 0: A+B or A-B addition or subtraction
    unit 1: A*B multiplication
    unit 2: A/B division
    unit 3: I/O move to RAM

From MMIO command interface vector registers are accessed 
by number of the vector register port, having 2 ports for the same
register.

Vector register ports are numbered from 0 to 2*number_of_registers-1
Adjacent even and odd numbers represent 2 different ports, actually
2 aliases of the same vector. For example both port 0 and port 1
access the first vector, port 2 and port 3 the second etc.

Each alias can independently address a "from-to" range of elements
of the same vector. Ranges can be any: identical, disjunct, overlapping
or single-element, when "from" = "to".

This makes it possible to combine independed functional units
for example: parallel run, chaining, or using 2 different ranges 
of the same vector as arguments.

Range is set to a vector port by MMIO command.
Range is internal property of a vector port, once set, vector port 
keeps "from-to" value in internal memory, until new value is set.
Range can be only written (set) but can't be read.

Each arithmetic vector operation is a form of binary operation on
vector ports, processing each-to-each element in the range:
V[0] = V[2] + V[4]

If result vector has more elements (is longer) than one (or both) of the argument vectors,
then the LAST ELEMENT in the range of the short argument will be REPEATED.
Thus a constant-to-vector operation is possible by setting one of the
vector range as single element: "from"="to"
