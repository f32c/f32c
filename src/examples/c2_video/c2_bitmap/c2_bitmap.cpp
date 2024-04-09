/*************************************************** 
  An example how to do ordinary bitmap as a
  special case of compositing2 sprites
 ****************************************************/

extern "C" {
#include <stdlib.h>
#include <math.h>
}

#include "Compositing/Compositing.h"
#define SPRITE_MAX 4

Compositing c2;

//                            RRGGBB
#define C2_WHITE  RGB2PIXEL(0xFFFFFF)
#define C2_GREEN  RGB2PIXEL(0x002200)
#define C2_ORANGE RGB2PIXEL(0xFF7F00)
#define C2_BLUE   RGB2PIXEL(0x4080FF)

#define RESOLUTION_X VGA_X_MAX
#define RESOLUTION_Y VGA_Y_MAX

#define BLOCK_X 256
#define BLOCK_Y 256

// xy rotation center and radius
#define CX ((RESOLUTION_X-BLOCK_X)/2)
#define CY ((RESOLUTION_Y-BLOCK_Y)/2)

#define RX CX
#define RY CY

void setup() 
{
  c2.init();
  c2.alloc_sprites(SPRITE_MAX);

  // sprite 0
  pixel_t *green_blue = (pixel_t *)malloc(BLOCK_X*BLOCK_Y*sizeof(pixel_t));
  for(int i = BLOCK_X*BLOCK_Y; --i >= 0; )
    green_blue[i] = RGB2PIXEL(i);
  c2.sprite_from_bitmap(BLOCK_X, BLOCK_Y, green_blue);

  // sprite 1
  pixel_t *red_green = (pixel_t *)malloc(BLOCK_X*BLOCK_Y*sizeof(pixel_t));
  for(int i = BLOCK_X*BLOCK_Y; --i >= 0; )
    red_green[i] = RGB2PIXEL(i<<8);
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
