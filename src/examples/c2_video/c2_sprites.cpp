/*
 * Print a message on serial console, and blink LEDs until a button
 * is pressed on the ULX2S FPGA board.
 *
 * $Id$
 */

extern "C" {
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <dev/io.h>
}

#include "Compositing/Compositing.h"
#include "Compositing/shape.h"
#include "shapes.h"

#define SPRITE_MAX 160
#define N_SHAPES ((int)(sizeof(Shape)/sizeof(Shape[0])))

Compositing c2;

struct sprite_speed 
{
  int x,y;
};
struct sprite_speed *Sprite_speed;

void setup()
{
  int i;
  c2.init();
  c2.alloc_sprites(SPRITE_MAX);
  Sprite_speed = (struct sprite_speed *) malloc(SPRITE_MAX * sizeof(struct sprite_speed));

  #if 1
    for(i = 0; i < c2.sprite_max && i < N_SHAPES; i++)
      c2.shape_to_sprite(&Shape[i]);
    for(i = c2.n_sprites; i < c2.sprite_max; i++)
      c2.sprite_clone(i%N_SHAPES);
    for(i = 0; i < c2.n_sprites; i++)
    {
      //shape_to_sprite(1 + (i % 3),i);
      c2.Sprite[i]->x = 20 + (rand() % 600);
      c2.Sprite[i]->y = 20 + (rand() % 400);
      Sprite_speed[i].x = (rand() % 3)-1;
      Sprite_speed[i].y = (rand() % 3)-1;
    }
  #endif

  if(1)
  {
  // enable video fetching after all the
  // pointers have been correctly sat.
    c2.sprite_refresh();
  }
  // prevents random RAM content from
  // causing extensive fetching, and slowing
  // down CPU
  //videodisplay_reg = &(scanlines[0][0]);
  // this is needed for vgatext
  // to disable textmode and enable bitmap
  *c2.cntrl_reg = 0b11000000; // enable video, yes bitmap, no text mode, no cursor
  // try it with text to "see" what's going
  // on with linked list :)
  //*c2.cntrl_reg = 0b11100000; // enable video, yes bitmap, yes text mode, no cursor
}

void loop()
{
  int i;

  for(i = 0; i < c2.n_sprites; i++)
  {
    c2.Sprite[i]->x += Sprite_speed[i].x;
    c2.Sprite[i]->y += Sprite_speed[i].y;
    if(c2.Sprite[i]->x < -40)
    {
      Sprite_speed[i].x = 1;
      if( (rand()&7) == 0 )
        Sprite_speed[i].y = (rand()%3)-1;
    }
    if(c2.Sprite[i]->x > VGA_X_MAX)
    {
      Sprite_speed[i].x = -1;
    }

    if(c2.Sprite[i]->y < -40)
    {
      Sprite_speed[i].y = 1;
      if( (rand()&7) == 0 )
        Sprite_speed[i].x = (rand()%3)-1;
    }
    if(c2.Sprite[i]->y > VGA_Y_MAX+40)
      Sprite_speed[i].y = -1;
  }
  while((*c2.vblank_reg & 0x80) == 0);
  c2.sprite_refresh();
  while((*c2.vblank_reg & 0x80) != 0);
  //delay(15);
}

void
main(void)
{
        setup();
again:;
	loop();
	goto again;
}
