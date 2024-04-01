#ifndef COMPOSITING_H
#define COMPOSITING_H

extern "C"
{
  #include "compositing_line.h"
  #include "sprite.h"
  #include "shape.h"
}

#include <inttypes.h>

#define VGA_X_MAX 640
#define VGA_Y_MAX 480

class Compositing
{
  private:

  public:
    // compositing line without pixel content
    // content needs to be malloc'd
    struct compositing_line **scanlines;
    volatile uint32_t *videobase_reg;
    volatile uint8_t *cntrl_reg;
    volatile uint8_t *vblank_reg;
    
    struct sprite **Sprite; // global pointer array to sprites
    int n_sprites, sprite_max; // number of sprites currently created

    // constructor will initialize
    Compositing()
    {
       videobase_reg = (volatile uint32_t *)0xFFFFFB90;
       cntrl_reg = (volatile uint8_t *)0xFFFFFB81;
       vblank_reg = (volatile uint8_t *)0xFFFFFB87;
       n_sprites = 0;
       sprite_max = 0;
    }

    void init();
    void alloc_sprites(int n);
    void sprite_refresh(); // refresh compositing linked list after changing x/y positions
    void sprite_refresh(int m); // refresh from sprite number 'm' to last sprite
    void sprite_refresh(int m, int n); // refresh sprites from 'm' to 'n'-1 ('n' non-inclusive)
    int shape_to_sprite(const struct shape *sh);
    int sprite_clone(int original); // new sprite with clone content from existing sprite
    int sprite_add(struct sprite *s); // new sprite with clone content from existing sprite
    int sprite_fill_rect(int w, int h, pixel_t color);
    int x_even_size(int x);
    int sprite_from_bitmap(int w, int h, pixel_t *bmp);
    void sprite_position(int sprite, int x, int y);
    void sprite_link_content(int original, int clone);
};

#endif
