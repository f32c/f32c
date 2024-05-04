// source from https://gtoal.com/src/pacman-maze-generators/
#ifndef PACMAZE_H
#define PACMAZE_H
#include <stdio.h>

#define EXIT_SUCCESS 0

#define TARGET_HEIGHT 19
#define TARGET_WIDTH 25
#define TILE_DIMENSION 4
#define MIDDLE ((TARGET_WIDTH+1)/2)


#define WIDTH (TARGET_HEIGHT/2)
#define HEIGHT (TARGET_WIDTH/4)

#define JAIL 1

#ifndef FALSE
#define FALSE (0!=0)
#define TRUE (!FALSE)
#endif

#define PACWIDTH (HEIGHT*2+1)
#define PACHEIGHT (WIDTH+2)

extern char line[PACHEIGHT*2+1][PACWIDTH*6+1]; // slop is to allow for stretched image

void generate_maze(void);
void draw_maze(void);
#endif
