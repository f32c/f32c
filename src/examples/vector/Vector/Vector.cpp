#include "Vector.h"

extern "C"
{
  #include "vector_link.h"
}

Vector::Vector()
{
  // todo: autodetection of the vector unit
  vector_present = vector_detect();
  //soft_alloc_vector_registers(); // allocate regs for vector emulation
  // clear any interrupts
  hard_init();
}
 
void Vector::dumpreg()
{
  vector_dumpreg();
  return;
}

volatile struct vector_header_s *Vector::create(int n)
{
  return create_segmented_vector(n, 0);
}

volatile struct vector_header_s *Vector::create(int n, int seglen)
{
  return create_segmented_vector(n, seglen);
}

void Vector::print(struct vector_header_s *v)
{
  printvector(v, 0, 2048);
}

void Vector::io(int i, struct vector_header_s *vh, int store_mode)
{
  if(vector_present)
    hard_vector_io(i, vh, store_mode);
  else
    soft_vector_io(i, vh, store_mode);
}

void Vector::range(int i, uint16_t start, uint16_t stop)
{
  vector_mmio[4] = 0xA0000000 | i | (start<<4) | (stop<<16);
}

void Vector::load(int i, struct vector_header_s *vh)
{
  if(vector_present)
  {
    vector_mmio[0] = (uint32_t) vh;
    #if 0
    // vector load command must also pass vector
    // length, better this way than to waste LUTs
    // CPU will travel thru vector headers, sum the vector length
    uint16_t length = -1;
    for(; vh != NULL; vh = vh->next)
      length += 1 + vh->length;
    length %= VECTOR_MAXLEN; // limit max length with bitmask
    uint16_t start = 0, stop = length;
    vector_mmio[4] = 0xA0000000 | i | (start<<4) | (stop<<16);
    #endif
    vector_mmio[4] = 0xE3000000 | i | (i<<4); // execute load vector, no increment delay
    wait_vector_mask((1<<i)|(1<<16));
  }
  else
    soft_vector_io(i, vh, 0);
}

void Vector::store(struct vector_header_s *vh, int i)
{
  if(vector_present)
  {
    vector_mmio[0] = (uint32_t) vh;
    // vector_mmio[4] = 0x01800000 | i; // store vector (selected by index)
    vector_mmio[4] = 0xE381F000 | i | (i<<4); // execute store vector
    wait_vector_mask(1<<16);
    vector_flush(vh);
  }
  else
    soft_vector_io(i, vh, 1);
}

void Vector::oper(int a, int b, int c, int op)
{
  if(vector_present)
    hard_vector_oper(a,b,c,op);
  else
    soft_vector_oper(a,b,c,op);
}

// a = b + c
void Vector::add(int a, int b, int c)
{
  if(vector_present)
  {
    vector_mmio[4] = 0xE0003000 | a | (b<<4) | (c<<8); // a=b+c float (selected by index)
    wait_vector_mask(1<<a);
  }
  else
    soft_vector_oper(a,b,c,0);
}

// a = b - c
void Vector::sub(int a, int b, int c)
{
  if(vector_present)
  {
    vector_mmio[4] = 0xE0403000 | a | (b<<4) | (c<<8); // a=b-c float (selected by index)
    wait_vector_mask(1<<a);
  }
  else
    soft_vector_oper(a,b,c,1);
}

// a = b * c
void Vector::mul(int a, int b, int c)
{
  if(vector_present)
  {
    vector_mmio[4] = 0xE1004000 | a | (b<<4) | (c<<8); // a=b*c float (selected by index)
    wait_vector_mask(1<<a);
  }
  else
    soft_vector_oper(a,b,c,2);
}

// a = b / c
void Vector::div(int a, int b, int c)
{
  if(vector_present)
  {
    vector_mmio[4] = 0xE200B000 | a | (b<<4) | (c<<8); // a=b/c float (selected by index)
    wait_vector_mask(1<<a);
  }
  else
    soft_vector_oper(a,b,c,3);
}

// a = i2f(b) integer to float (not supported by hardware)
void Vector::i2f(int a, int b)
{
  if(vector_present)
  {
    vector_mmio[4] = 0xE0040000 | a | (b<<4); // a=i2f(b) integer to float (selected by index)
    wait_vector_mask(1<<a);
  }
  else
    soft_vector_oper(a,b,0,4);
}

// a = f2i(b) float to integer (not supported by hardware)
void Vector::f2i(int a, int b)
{
  if(vector_present)
  {
    vector_mmio[4] = 0xE0050000 | a | (b<<4); // a=f2i(b) float to integer (selected by index)
    wait_vector_mask(1<<a);
  }
  else
    soft_vector_oper(a,b,0,5);
}

Vector_REG operator + (Vector_REG& lhs, const Vector_REG& rhs)
{
  return lhs += rhs;
}

Vector_REG operator - (Vector_REG& lhs, const Vector_REG& rhs)
{
  return lhs -= rhs;
}

Vector_REG operator * (Vector_REG& lhs, const Vector_REG& rhs)
{
  return lhs *= rhs;
}

Vector_REG operator / (Vector_REG& lhs, const Vector_REG& rhs)
{
  return lhs /= rhs;
}

// vector load from RAM
Vector_REG& Vector_REG::operator = (const class Vector_RAM& rhs)
{
  vector_mmio[0] = (uint32_t)rhs.vh;
  #if 0
  volatile struct vector_header_s *vh = rhs.vh;
  // vector load command must also pass vector
  // length, better this way than to waste LUTs
  // CPU will travel thru vector headers, sum the vector length
  uint16_t length = -1;
  for(; vh != NULL; vh = vh->next)
    length += 1 + vh->length;
  length %= VECTOR_MAXLEN; // limit max length with bitmask
  uint16_t start = 0, stop = length;
  vector_mmio[4] = 0xA0000000 | number | (start<<4) | (stop<<16);
  #endif
  vector_mmio[4] = 0xE3000000 | number | (number<<4);
  wait_vector_mask((1<<number)|(1<<16));
  return *this;
}

// vector store to RAM
Vector_RAM& Vector_RAM::operator = (const class Vector_REG& rhs)
{
  vector_mmio[0] = (uint32_t)vh;
  vector_mmio[4] = 0xE381F000 | rhs.number | (rhs.number<<4);
  wait_vector_mask(1<<16);
  vector_flush(vh);
  return *this;
}
