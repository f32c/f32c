#ifndef VECTOR_REG_H
#define VECTOR_REG_H

#include <inttypes.h>
#include "Vector_RAM.h"

extern "C"
{
  #include "vector_link.h"
}

enum vector_operation { VECTOR_ADD=0, VECTOR_SUB=1, VECTOR_MUL=2, VECTOR_DIV=3 };

class Vector_REG
{
  public:
    uint32_t number, number_lhs, number_rhs, operation; // hardware vector register number, usually 0-7
    Vector_REG(uint8_t n):number(n){}; // constructor sets register number
    void range(uint16_t start, uint16_t stop)
    { // set range of the vector (inclusive)
      // if data beyond last element are needed as argument to produce result,
      // then the last element of the argument will be constantly repeated.
      vector_mmio[4] = 0xA0000000 | number | (start << 4) | (stop << 16);
    }
    Vector_REG& operator += (const Vector_REG& rhs)
    { // memorize lhs, rhs and operator type to use at assignment
      number_lhs = number;
      number_rhs = rhs.number;
      operation = VECTOR_ADD;
      return *this;
    }
    Vector_REG& operator -= (const Vector_REG& rhs)
    { // memorize lhs, rhs and operator type to use at assignment
      number_lhs = number;
      number_rhs = rhs.number;
      operation = VECTOR_SUB;
      return *this;
    }
    Vector_REG& operator *= (const Vector_REG& rhs)
    { // memorize lhs, rhs and operator type to use at assignment
      number_lhs = number;
      number_rhs = rhs.number;
      operation = VECTOR_MUL;
      return *this;
    }
    Vector_REG& operator /= (const Vector_REG& rhs)
    { // memorize lhs, rhs and operator type to use at assignment
      number_lhs = number;
      number_rhs = rhs.number;
      operation = VECTOR_DIV;
      return *this;
    }
    Vector_REG& operator = (const Vector_REG& rhs) // assignment performs actual vector hardware operation
    {
      uint32_t vector_opcode[4] = 
      {
        0xE0003000, // VECTOR_ADD
        0xE0403000, // VECTOR_SUB
        0xE1004000, // VECTOR_MUL
        0xE200B000, // VECTOR_DIV
      };
      vector_mmio[4] = vector_opcode[rhs.operation] | number | (rhs.number_lhs<<4) | (rhs.number_rhs<<8); // a=b+c float (selected by index)
      wait_vector_mask(1<<number);
      return *this;
    }
    // vector load from RAM
    Vector_REG& operator = (const class Vector_RAM& rhs);
};

Vector_REG operator + (Vector_REG&, const Vector_REG&);
Vector_REG operator - (Vector_REG&, const Vector_REG&);
Vector_REG operator * (Vector_REG&, const Vector_REG&);
Vector_REG operator / (Vector_REG&, const Vector_REG&);

#endif
