#ifndef SPRITE_H
#define SPRITE_H
#include "compositing_line.h"
#include "shape.h"

// if using existing content, only 2K of video cache is sufficient
// 1-USE 0-DON'T USE
#define USE_EXISTING_CONTENT 1

#define REMOVE_LEADING_TRANSPARENT 1

// struct used to draw sprite in C
struct sprite
{
  int16_t x,y; // current position on the screen
  uint16_t h; // h: current height y-size (number of lines)
  uint16_t ha; // height allocated (absolute max of lines)
  struct compositing_line *line; // content: array of lines - NULL to terminate
  int16_t *lxo; // array of line x-offsets, removing leading transparent pixels and x-center adjustment
};

#endif // SPRITE_H
