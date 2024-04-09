/*************************************************** 
  An example how to do ordinary bitmap as a
  special case of compositing2 sprites
 ****************************************************/

extern "C" {
#include <stdlib.h>
#include <math.h>
}

#include "Compositing/Compositing.h"

Compositing c2;

#define RESOLUTION_X VGA_X_MAX
#define RESOLUTION_Y VGA_Y_MAX

// number of sprites
#define SPRITE_MAX 4 // >= 2

// sprite size
#define BLOCK_X 256 // divisible by 4
#define BLOCK_Y 256 // divisible by 4

// xy rotation center and radius
#define CX ((RESOLUTION_X-BLOCK_X)/2)
#define CY ((RESOLUTION_Y-BLOCK_Y)/2)

#define RX CX
#define RY CY

void setup() 
{
  int i;
  uint8_t r,g,b;
  c2.init();
  c2.alloc_sprites(SPRITE_MAX);

  // sprite 0
  pixel_t *green_blue = (pixel_t *)malloc(BLOCK_X*BLOCK_Y*sizeof(pixel_t));
  i = 0;
  for(int y = 0; y < BLOCK_Y; y++)
    for(int x = 0; x < BLOCK_X; x++)
    {
      g = x*256/BLOCK_X;
      b = y*512/BLOCK_Y;
      green_blue[i++] = RGB2PIXEL((g<<8)|b);
    }
  c2.sprite_from_bitmap(BLOCK_X, BLOCK_Y, green_blue);

  // sprite 1
  pixel_t *red_green = (pixel_t *)malloc(BLOCK_X*BLOCK_Y*sizeof(pixel_t));
  i = 0;
  for(int y = 0; y < BLOCK_Y; y++)
    for(int x = 0; x < BLOCK_X; x++)
    {
      g = x*256/BLOCK_X;
      r = y*256/BLOCK_Y;
      red_green[i++] = RGB2PIXEL((r<<16)|(g<<8));
    }
  c2.sprite_from_bitmap(BLOCK_X, BLOCK_Y, red_green);

  for(int j = 2; j < SPRITE_MAX; j++)
    c2.sprite_clone(j & 1);

  // draw them all
  c2.sprite_refresh();
  *c2.cntrl_reg = 0b11000000; // enable video, yes bitmap, no text mode, no cursor
}

void loop()
{
  int i;
  static uint8_t a; // rotation angle

  for(i = 0; i < SPRITE_MAX; i++)
  {
    c2.Sprite[i]->x = CX + RX * cos(2*M_PI/256*(a+256/SPRITE_MAX*i));
    c2.Sprite[i]->y = CY + RY * sin(2*M_PI/256*(a+256/SPRITE_MAX*i));
  }
  a++; // rotate one step by incrementing the angle

  while((*c2.vblank_reg & 0x80) == 0);
  c2.sprite_refresh();
  while((*c2.vblank_reg & 0x80) != 0);
}

void main(void)
{
  setup();
  while(1)
    loop();
}
