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

It is recommended to choose alghorithm that utilizes 
more full length register vector operations with less I/O.

Status of the vector processor:

    * 4 x 32-bit MMIO control and interrupt registers
    * 8 x uint32_t[2048] BRAM based vector registers
    * I/O load and store using AXI RAM DMA burst
      can run parallel with arithmetic operations,
      multiple registers load with the same content at the same time
    * 32-bit integer arithmetic +, -, * 1 clock delay
    * 32-bit floating point unit: 5 clocks delay (multiply)
    * any-to-any vector operation of type: a = b+c, a = b+b
      except: a = a+b which will not work
    * multiple operations can run parallel
      provided they use different registers and different functional units
    * multiple parallel functional untis can be instantiated
      example: a = b+c, d = e*f can run parallel
    * interrupt flag for each vector set when done
    * works at 100 MHz clock rate on artix-7
    * produces 1 result per 1 clock cycle
      after initial 1-10 clocks delay, depending on function
    * theoretical maximum speed approaches 2 MFLOPs/MHz
      when 1 I/O and 2 FPU operations are running parallel

Todo:

    * linked list I/O
    * handling short vectors
    * chaining: explore possibility of parallel a = b+c, d = a*e
