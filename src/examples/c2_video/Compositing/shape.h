#ifndef SHAPE_H
#define SHAPE_H
#include "compositing_line.h" // pixel_t only

struct charcolors
{
  const char c; // letter indicating the color (0 to end of list)
  const pixel_t color; // color value bits: RRRGGGBB if 8bpp
};

// struct used to draw sprite in C
struct shape
{
  const struct charcolors *colors; // array of colors
  const char **bmp; // the bitmap, NULL-terminated
  const uint8_t w,h; // width x-size, height y-size
};

// extern struct shape Shape[];

#endif // SHAPE_H
