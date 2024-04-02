extern "C" {
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <dev/io.h>
}
#include "Compositing/Compositing.h"
#include "font.h"

#define N_LETTERS ((int)(sizeof(Font)/sizeof(Font[0])))

Compositing c2;

void main(void)
{
  int i;
  int unique_sprites;
  c2.init();
  c2.alloc_sprites(765); // 1200 full screen, 765 triangle, it sets c2.sprite_max
  *c2.videobase_reg = 0; // disable video during update
  *c2.cntrl_reg = 0;
  #if 1
    for(i = 0; i < c2.sprite_max && i < N_LETTERS; i++)
      c2.shape_to_sprite(&(Font[i]));
    unique_sprites = c2.n_sprites;
    for(i = unique_sprites; i < c2.sprite_max; i++)
      c2.sprite_clone(i%unique_sprites);
    // position all sprites to display a font
    int col=0, row=0;
    for(i = 0; i < c2.sprite_max; i++)
    {
      c2.Sprite[i]->x = col*16;
      c2.Sprite[i]->y = row*16;
      col++;
      if(col>=11+row) // triangle
      //if(col>=40) // full screen
      {
        col=0;
        row++;
      }
    }
  #endif

  c2.sprite_refresh();

  // this is needed for vgatext
  // to disable textmode and enable bitmap
  *c2.cntrl_reg = 0b11000000; // enable video, yes bitmap, no text mode, no cursor
}
