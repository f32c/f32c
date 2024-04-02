#ifndef VECTOR_RAM_H
#define VECTOR_RAM_H

#include <inttypes.h>
#include "Vector_REG.h"

extern "C"
{
  #include "vector_link.h"
}

class Vector_RAM
{
  public:
    volatile struct vector_header_s *vh;
    Vector_RAM(int length) // create RAM-based vector
    {
      vh = create_segmented_vector(length, 0);
    }
    // vector store to RAM
    Vector_RAM& operator = (const class Vector_REG& rhs);
};

#endif
