/*************************************************** 
(c)EMARD
LICENSE=BSD

Vector unit used as the blitter
****************************************************/
extern "C"
{
#include <stdlib.h>
#include <string.h>
#include <math.h>
}
#include "Compositing/Compositing.h"
#include "Vector/Vector.h"

#define ANZCOL 256
#define SCREEN_WIDTH 640
#define SCREEN_HEIGHT 480
#define SPRITE_MAX 10

#define TILE_WIDTH 32
#define TILE_HEIGHT 32

#define TILES_X (SCREEN_WIDTH/TILE_WIDTH)
#define TILES_Y (SCREEN_HEIGHT/TILE_HEIGHT)

struct vector_header_s *vtiles;

Compositing c2;
Vector V;

// crude malloc()
pixel_t *bitmap = (pixel_t *)0x80080000;
pixel_t color_map[ANZCOL];

void set_pix(int x, int y, int c)
{
  bitmap[x + SCREEN_WIDTH*y] = RGB2PIXEL(color_map[c]);
}

// create vector tiles, array of pointers to screen tiles
// which represent characters
void place_vector_tiles()
{
  int i, j, k;
  vtiles = (struct vector_header_s *)malloc(TILES_X * TILES_Y * TILE_HEIGHT * sizeof(struct vector_header_s));
 
  for(j = 0; j < TILES_Y; j++)
  {
    for(i = 0; i < TILES_X; i++)
    {
      for(k = 0; k < TILE_HEIGHT; k++)
      {
        pixel_t *p = &(bitmap[i * TILE_WIDTH + j * TILE_HEIGHT * SCREEN_WIDTH + k * SCREEN_WIDTH]);
        #if 1
        vtiles[(i + j*TILES_X)*TILE_HEIGHT + k].next = k < TILE_HEIGHT-1 ? &vtiles[(i + j*TILES_X)*TILE_HEIGHT + k + 1] : NULL;
        vtiles[(i + j*TILES_X)*TILE_HEIGHT + k].length = TILE_WIDTH-1;
        vtiles[(i + j*TILES_X)*TILE_HEIGHT + k].data = (union ifloat_u *)p;
        #endif
      }
    }
  }
}

void vector_move_tile(int src, int dest)
{
  struct vector_header_s *vsrc, *vdest;
  vsrc = &vtiles[src * TILE_HEIGHT];
  vdest = &vtiles[dest * TILE_HEIGHT];
  #if 0
    struct vector_header_s *vt = vdest;
    // software test if dest is pointed to screen
    int k, l;
    for(; vt != NULL; vt = vt->next)
      for(k = 0; k <= vt->length; k++)
        vt->data[k].u = 0; // black/erase
  #endif
  #if 1
    // hardware blitter
    V.range(0, 0, TILE_WIDTH*TILE_HEIGHT-1);
    V.io(0, vsrc, 0); // load v0, from src
    V.io(0, vdest, 1); // store v0, overwrite dest
  #endif
}

void alloc_bitmap()
{
  int i;
  c2.init();
  c2.alloc_sprites(SPRITE_MAX);
  bitmap = (pixel_t *) malloc(SCREEN_WIDTH*SCREEN_HEIGHT*sizeof(pixel_t)); // alloc memory for video
  c2.sprite_from_bitmap(SCREEN_WIDTH, SCREEN_HEIGHT, bitmap); // create c2 sprite
  c2.sprite_refresh(); // show it on screen
  *c2.cntrl_reg = 0b11000000; // vgatextmode: enable video, yes bitmap, no text mode, no cursor
  for(i = 0; i < SCREEN_WIDTH*SCREEN_HEIGHT; i++) bitmap[i] = RGB2PIXEL((i*2)<<8);  // clear screen
}


void main(void)
{
  int i,j;
  alloc_bitmap();
  place_vector_tiles();
  for(j = 8; j > 4; j--)
    for(i = j*20+5; i < j*20+15; i++)
      vector_move_tile(i-2*20-1, i);
}
