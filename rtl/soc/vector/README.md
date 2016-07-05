# Vector processor

Integer and floating point vector processor unit
that runs parallel with f32c core, exchanging data over DMA.
It can be also used as video blitter.

Vector is 1-dimensional array of integers or floats.
Vector operation applies same arithmetic function
to elements of the arrays, each-to-each.
For example 2048-element vector oparation

    a = b * c

does

    for(i = 0; i < 2048; i++)
      a[i] = b[i] * c[i];

In 2048 clock cycles.

In real code run, there will be added latency 
for RAM I/O, command and pipeline clock cycles 
before a vector operation starts.

Vector data doesn't have to be a contiguous array
but can be given in a form of linked list with pointers
to values scattered accross the whole RAM. 

Speed recommendations:

    * choose alghorithm that utilizes more full length register
      vector operations with less I/O.
    * I/O is faster for data in larger contiguous arrays
      when the RAM burst can be used.

Status of the vector processor:

    * 4 x 32-bit MMIO control and interrupt registers
    * 8 x uint32_t[2048] BRAM based vector registers
    * I/O load and store using AXI RAM DMA burst
      can run parallel with arithmetic operations,
      multiple registers load with the same content at the same time
    * 4 parallel pipeline functional units
    * 32-bit 2 integer arithmetic pielines: 1-stage (+,-) and 1-stage (*)
    * 32-bit 2 floating point pipelines: 5-stage (+,-,*) and 7-stage (/)
      (+,-,*) pipeline can optinallny convert integer to/from float
      (/) division pipeline can optionally approximate 23-bit integers division
    * any-to-any vector operation of type: a = b+c, a = b+b
      except: a = a+b which will not work
    * multiple operations can run parallel
      provided they use different registers and different pipeline functional units
      example: a = b+c, d = e*f can run parallel
    * interrupt flag for each vector set when done
    * works at 100 MHz clock rate on artix-7
    * produces 1 result per 1 clock cycle
      after initial 1-7 clocks delay, depending on pipeline
    * theoretical maximum speed approaches 2 MFLOPs/MHz
      when 1 I/O and 2 FPU operations are running parallel
    * linked list support

Todo:

    * chaining: explore possibility of parallel a = b+c, d = a*e
    * floating point comparation pipeline
    * use both BRAM vector ports in crossbar multiplexer
