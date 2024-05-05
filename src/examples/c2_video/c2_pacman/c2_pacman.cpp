// many sprites moving accross the screen

extern "C" {
#include <stdlib.h>
#include <stdint.h>
#include "pacmaze.h"
}

#include "Compositing/Compositing.h"
#include "shapes.h"

#define SPRITE_MAX 600
#define N_SHAPES ((int)(sizeof(Shape)/sizeof(Shape[0])))

Compositing c2;

struct sprite_speed 
{
  int x,y;
};
struct sprite_speed *Sprite_speed;

int sprite_snacker;

#define XM 27
#define YM 21

struct c2_tile
{
  int16_t x,y;
  uint16_t shape;
  uint16_t sprite;
};
struct c2_tile c2_tile[YM][XM];

struct lin2shap
{
  int shape; // shape index from sprites
};
struct lin2shap lin2shap;

int line2shape(int i, int j)
{
  if(i <= 0 || i >= XM-1)
  {
    if(i <= 0 && j <= 0)
      return SHAPE_WALL_L_RIGHT_DOWN;
    if(i <= 0 && j >= YM-1)
      return SHAPE_WALL_L_RIGHT_UP;
    if(i >= XM-1 && j <= 0)
      return SHAPE_WALL_L_LEFT_DOWN;
    if(i >= XM-1 && j >= YM-1)
      return SHAPE_WALL_L_LEFT_UP;
    return SHAPE_WALL_VERTICAL;
  }
  if(j <= 0 || j >= YM-1)
    return SHAPE_WALL_HORIZONTAL;
  if(line[j][i] == '#')
    return SHAPE_GUMDROP;
  if(line[j][i] == '@')
    return SHAPE_SNACKER_RIGHT_1 + (random() & 1);
  if(line[j][i] == 'V')
    return SHAPE_GUARD_VIOLET_LEFT + (random() & 3);
  if(line[j-1][i] == ' ' && line[j+1][i] == ' ' && line[j][i-1] == ' '  && line[j][i+1] == ' ')
    return SHAPE_WALL_CROSS;
  if(line[j-1][i] == ' ' && line[j+1][i] == ' ' && line[j][i-1] == '#'  && line[j][i+1] == ' ')
    return SHAPE_WALL_T_RIGHT;
  if(line[j-1][i] == ' ' && line[j+1][i] == ' ' && line[j][i-1] == ' '  && line[j][i+1] == '#')
    return SHAPE_WALL_T_LEFT;
  if(line[j-1][i] == '#' && line[j+1][i] == ' ' && line[j][i-1] == ' '  && line[j][i+1] == ' ')
    return SHAPE_WALL_T_DOWN;
  if(line[j-1][i] == ' ' && line[j+1][i] == '#' && line[j][i-1] == ' '  && line[j][i+1] == ' ')
    return SHAPE_WALL_T_UP;
  if(line[j-1][i] == ' ' && line[j+1][i] == '#' && line[j][i-1] == ' '  && line[j][i+1] == '#')
    return SHAPE_WALL_L_LEFT_UP;
  if(line[j-1][i] == ' ' && line[j+1][i] == '#' && line[j][i-1] == '#'  && line[j][i+1] == ' ')
    return SHAPE_WALL_L_RIGHT_UP;
  if(line[j-1][i] == '#' && line[j+1][i] == ' ' && line[j][i-1] == '#'  && line[j][i+1] == ' ')
    return SHAPE_WALL_L_RIGHT_DOWN;
  if(line[j-1][i] == '#' && line[j+1][i] == ' ' && line[j][i-1] == ' '  && line[j][i+1] == '#')
    return SHAPE_WALL_L_LEFT_DOWN;
  if(line[j][i-1] == ' ' && line[j][i+1] == ' ')
    return SHAPE_WALL_HORIZONTAL;
  if(line[j][i-1] == '#' && line[j][i+1] == ' ')
    return SHAPE_WALL_RIGHT_HORIZONTAL;
  if(line[j][i-1] == ' ' && line[j][i+1] == '#')
    return SHAPE_WALL_LEFT_HORIZONTAL;
  if(line[j-1][i] == ' ' && line[j+1][i] == ' ')
    return SHAPE_WALL_VERTICAL;
  if(line[j-1][i] == ' ' && line[j+1][i] == '#')
    return SHAPE_WALL_UP_VERTICAL;
  if(line[j-1][i] == '#' && line[j+1][i] == ' ')
    return SHAPE_WALL_DOWN_VERTICAL;
  return SHAPE_SPACE;
}


void place_c2_tiles()
{
  for(int j = 0; j < YM; j++)
    for(int i = 0; i < XM; i++)
    {
      c2_tile[j][i].x = 60+i*20;
      c2_tile[j][i].y = 30+j*20;
      c2_tile[j][i].shape = line2shape(i,j);
      int n = c2.n_sprites; // nth sprite that will be cloned
      c2.sprite_clone(c2_tile[j][i].shape); // increments c2.n_sprites
      c2_tile[j][i].sprite = n;
      c2.Sprite[n]->x = c2_tile[j][i].x;
      c2.Sprite[n]->y = c2_tile[j][i].y;
    }
}

void refresh_c2_tiles()
{
  for(int j = 0; j < YM; j++)
    for(int i = 0; i < XM; i++)
    {
      c2_tile[j][i].shape = line2shape(i,j);
      c2.sprite_link_content(c2_tile[j][i].shape, c2_tile[j][i].sprite);
    }
}

void setup()
{
  int i;
  c2.init();
  c2.alloc_sprites(SPRITE_MAX);
  Sprite_speed = (struct sprite_speed *) malloc(SPRITE_MAX * sizeof(struct sprite_speed));

  for(i = 0; i < c2.sprite_max && i < N_SHAPES; i++)
    c2.shape_to_sprite(&Shape[i]);
  // showcase sprites
  for(i = 0; i < c2.n_sprites; i++)
  {
    c2.Sprite[i]->x = 50+i*20;
    c2.Sprite[i]->y = 450;
  }
  place_c2_tiles();
  //for(i = c2.n_sprites; i < c2.sprite_max; i++)
  //  c2.sprite_clone(i%N_SHAPES);
  #if 0
  for(i = 0; i < c2.n_sprites; i++)
  {
    c2.Sprite[i]->x = 20 + (rand() % 600);
    c2.Sprite[i]->y = 20 + (rand() % 400);
    Sprite_speed[i].x = (rand() % 3)-1;
    Sprite_speed[i].y = (rand() % 3)-1;
  }
  #endif

  // enable video fetching after all the
  // pointers have been correctly sat.
  c2.sprite_refresh();

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
  static int x = 0; // x position of the snacker
  random_maze();
  int snacker = c2_tile[13][13].sprite;
  x++; // move snacker
  c2.Sprite[snacker]->x = 60 + ((x + 1) & 511); // set sprite x position
  // animate snacker
  c2.sprite_link_content(SHAPE_SNACKER_RIGHT_1 + ((x>>3)&1), snacker);
  while((*c2.vblank_reg & 0x80) == 0);
  if(validate_maze())
    refresh_c2_tiles();
  c2.sprite_refresh();
  while((*c2.vblank_reg & 0x80) != 0);
}

void main(void)
{
  for(int i = 0; i < 30; i++) // 4 is fast, 10 too
    random();
  generate_maze();
  draw_maze(); // print to stdoup
  setup();
  while(1)
    loop();
}
