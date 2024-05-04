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
  int xo,yo; // placment offset
  int shape; // shape index from sprites
};
struct lin2shap lin2shap;

void line2shape(int i, int j, struct lin2shap *s)
{
  if(i <= 0 || i >= XM-1)
  {
    s->xo = 0;
    s->yo = -10;
    s->shape = SHAPE_WALL_VERTICAL;
    if(i <= 0 && j <= 0)
    {
      s->xo = 0;
      s->yo = 0;
      s->shape = SHAPE_WALL_L_RIGHT_DOWN;
    }
    if(i <= 0 && j >= YM-1)
    {
      s->xo = 0;
      s->yo = -10;
      s->shape = SHAPE_WALL_L_RIGHT_UP;
    }
    if(i >= XM-1 && j <= 0)
    {
      s->xo = -10;
      s->yo = 0;
      s->shape = SHAPE_WALL_L_LEFT_DOWN;
    }
    if(i >= XM-1 && j >= YM-1)
    {
      s->xo = -10;
      s->yo = -10;
      s->shape = SHAPE_WALL_L_LEFT_UP;
    }
    return;
  }
  if(j <= 0 || j >= YM-1)
  {
    s->xo = -10;
    s->yo = 0;
    s->shape = SHAPE_WALL_HORIZONTAL;
    return;
  }
  if(line[j-1][i] == ' ' && line[j+1][i] == ' ' && line[j][i-1] == '#'  && line[j][i+1] == ' ')
  {
    s->xo = 0;
    s->yo = -10;
    s->shape = SHAPE_WALL_T_RIGHT;
    return;
  }
  if(line[j-1][i] == ' ' && line[j+1][i] == ' ' && line[j][i-1] == ' '  && line[j][i+1] == '#')
  {
    s->xo = -10;
    s->yo = -10;
    s->shape = SHAPE_WALL_T_LEFT;
    return;
  }
  if(line[j-1][i] == '#' && line[j+1][i] == ' ' && line[j][i-1] == ' '  && line[j][i+1] == ' ')
  {
    s->xo = -10;
    s->yo = 0;
    s->shape = SHAPE_WALL_T_DOWN;
    return;
  }
  if(line[j-1][i] == ' ' && line[j+1][i] == '#' && line[j][i-1] == ' '  && line[j][i+1] == ' ')
  {
    s->xo = -10;
    s->yo = -10;
    s->shape = SHAPE_WALL_T_UP;
    return;
  }
  if(line[j-1][i] == ' ' && line[j+1][i] == '#' && line[j][i-1] == ' '  && line[j][i+1] == '#')
  {
    s->xo = -10;
    s->yo = -10;
    s->shape = SHAPE_WALL_L_LEFT_UP;
    return;
  }
  if(line[j-1][i] == ' ' && line[j+1][i] == '#' && line[j][i-1] == '#'  && line[j][i+1] == ' ')
  {
    s->xo = 0;
    s->yo = -10;
    s->shape = SHAPE_WALL_L_RIGHT_UP;
    return;
  }
  if(line[j-1][i] == '#' && line[j+1][i] == ' ' && line[j][i-1] == '#'  && line[j][i+1] == ' ')
  {
    s->xo = 0;
    s->yo = 0;
    s->shape = SHAPE_WALL_L_RIGHT_DOWN;
    return;
  }
  if(line[j-1][i] == '#' && line[j+1][i] == ' ' && line[j][i-1] == ' '  && line[j][i+1] == '#')
  {
    s->xo = -10;
    s->yo = 0;
    s->shape = SHAPE_WALL_L_LEFT_DOWN;
    return;
  }
  if(line[j][i-1] == ' ' && line[j][i+1] == ' ')
  {
    s->xo = -10;
    s->yo = 0;
    s->shape = SHAPE_WALL_HORIZONTAL;
    return;
  }
  if(line[j][i-1] == '#' && line[j][i+1] == ' ')
  {
    s->xo = 0; // overlap - shorten
    s->yo = 0;
    s->shape = SHAPE_WALL_HORIZONTAL;
    return;
  }
  if(line[j][i-1] == ' ' && line[j][i+1] == '#')
  {
    s->xo = -20; // overlap - shorten
    s->yo = 0;
    s->shape = SHAPE_WALL_HORIZONTAL;
    return;
  }
  if(line[j-1][i] == ' ' && line[j+1][i] == ' ')
  {
    s->xo = 0;
    s->yo = -10;
    s->shape = SHAPE_WALL_VERTICAL;
    return;
  }
  if(line[j-1][i] == ' ' && line[j+1][i] == '#')
  {
    s->xo = 0;
    s->yo = -20; // overlap - shorten
    s->shape = SHAPE_WALL_VERTICAL;
    return;
  }
  if(line[j-1][i] == '#' && line[j+1][i] == ' ')
  {
    s->xo = 0;
    s->yo = 0; // overlap - shorten
    s->shape = SHAPE_WALL_VERTICAL;
    return;
  }
  s->xo = 0;
  s->yo = 0;
  s->shape = SHAPE_SPACE;
  return;
}


void place_c2_tiles()
{
  for(int j = 0; j < YM; j++)
    for(int i = 0; i < XM; i++)
    {
      c2_tile[j][i].x = 60+i*20;
      c2_tile[j][i].y = 30+j*20;
      if(line[j][i] == ' ')
      {
        line2shape(i,j,&lin2shap);
        c2_tile[j][i].shape = lin2shap.shape;
        // centering
        c2_tile[j][i].x += lin2shap.xo;
        c2_tile[j][i].y += lin2shap.yo;
      }
      if(line[j][i] == '#')
      {
        c2_tile[j][i].shape = SHAPE_GUMDROP;
        // centering
        c2_tile[j][i].x -= 3;
        c2_tile[j][i].y -= 2;
      }
      c2.sprite_clone(c2_tile[j][i].shape);
      c2_tile[j][i].sprite = c2.n_sprites;
      c2.Sprite[c2.n_sprites-1]->x = c2_tile[j][i].x;
      c2.Sprite[c2.n_sprites-1]->y = c2_tile[j][i].y;
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
    c2.Sprite[i]->x = 100+i*20;
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
      Sprite_speed[i].x = -1;

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
}

void
main(void)
{
  for(int i = 0; i < 4; i++)
    random();
  generate_maze();
  draw_maze(); // print to stdoup
  setup();
  while(0)
    loop();
}
