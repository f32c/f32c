#ifndef VECTOR_H
#define VECTOR_H

#include <inttypes.h>
#include "Vector_RAM.h"
#include "Vector_REG.h"

extern "C"
{
  #include "vector_link.h"
}

class Vector
{
  private:
    uint8_t vector_present;

  public:
    Vector();
    void dumpreg();
    volatile struct vector_header_s *create(int n);
    volatile struct vector_header_s *create(int n,int seglen);
    void print(struct vector_header_s *v);
    void io(int i, struct vector_header_s *vh, int store_mode);
    void oper(int a, int b, int c, int oper);
    void range(int i, uint16_t start, uint16_t stop);
    void load(int i, struct vector_header_s *vh);
    void store(struct vector_header_s *vh, int i);
    void add(int a, int b, int c);
    void sub(int a, int b, int c);
    void mul(int a, int b, int c);
    void div(int a, int b, int c);
    void f2i(int a, int b);
    void i2f(int a, int b);
};

#endif
