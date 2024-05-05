#include <stdlib.h>
#include "Compositing/shape.h"

const struct charcolors snack_colors[] =
{ //      RRGGBB
  {'O', RGB2PIXEL(0xFF7F00)}, // orange
  {'R', RGB2PIXEL(0xFF0000)}, // red
  {'Y', RGB2PIXEL(0xFFFF00)}, // yellow
  {'V', RGB2PIXEL(0xC734FF)}, // violet
  {'G', RGB2PIXEL(0x38CB00)}, // green
  {'B', RGB2PIXEL(0x0DA1FF)}, // blue
  {'W', RGB2PIXEL(0xFFFFFF)}, // white
  {' ', RGB2PIXEL(0)}, // transparent
  {0, 0}
};

#define SHAPE_SPACE 0
const char *shape_space[] =
{
"    ",
NULL
};

#define SHAPE_WALL_HORIZONTAL 1
const char *shape_wall_horizontal[] =
{
"WWWWWWWWWWWWWWWWWWWW",
NULL
};

#define SHAPE_WALL_VERTICAL 2
const char *shape_wall_vertical[] =
{
"W   ",
"W   ",
"W   ",
"W   ",
"W   ",
"W   ",
"W   ",
"W   ",
"W   ",
"W   ",
"W   ",
"W   ",
"W   ",
"W   ",
"W   ",
"W   ",
"W   ",
"W   ",
"W   ",
"W   ",
NULL
};

#define SHAPE_GUARD_VIOLET_LEFT 3
const char *shape_guard_violet_left[] =
{/*
 0123456789012345678901 */
"   VVVVVVVVVVVVVVV    ",
"  V  WWWWVVVWWWW  V   ",
"  VVWWWWWWGWWWWWWVV   ",
"  VVV  WWWGG  WWWVV   ",
"  VVV  WWWGG  WWWVV   ",
"  VVWWWWWWGWWWWWWVV   ",
"  VVWWWWWWGWWWWWWVV   ",
"  VVWWWWWWGWWWWWWVV   ",
"  V  WWWWVVVWWWW  V   ",
"  VVVVVVVVVVVVVVVVV   ",
"   WWWWWGWWWWWGWWWWG  ",
"    VWW   VWW   VWW   ",
"     G     G     G    ",
NULL
};

#define SHAPE_GUARD_GREEN_DOWN 4
const char *shape_guard_green_down[] =
{/*
 0123456789012345678901 */
"   GGGGGGGGGGGGGGG    ",
"  G  WWWWGGGWWWW  G   ",
"  GGWWWWWWVWWWWWWGG   ",
"  GGWWWWWWVWWWWWWGG   ",
"  GGWWWWWWVWWWWWWGG   ",
"  GGWWWWWWVWWWWWWGG   ",
"  GGWW  WWVWW  WWGG   ",
"  GGWW  WWVWW  WWGG   ",
"  G  WWWWGGGWWWW  G   ",
"  GGGGGGGGGGGGGGGGG   ",
"  WWWWWGWWWWWGWWWWG   ",
"   VWW   VWW   VWW    ",
"    G     G     G     ",
NULL
};


#define SHAPE_GUARD_BLUE_UP 5
const char *shape_guard_blue_up[] =
{/*
 0123456789012345678901 */
"   BBBBBBBBBBBBBBB    ",
"  B  WWWWBBBWWWW  B   ",
"  BBWW  WWOWW  WWBB   ",
"  BBWW  WWOWW  WWBB   ",
"  BBWWWWWWOWWWWWWBB   ",
"  BBWWWWWWOWWWWWWBB   ",
"  BBWWWWWWOWWWWWWBB   ",
"  BBWWWWWWOWWWWWWBB   ",
"  B  WWWWBBBWWWW  B   ",
"  BBBBBBBBBBBBBBBBB   ",
" WWWWWGWWWWWGWWWWG    ",
"  VWW   VWW   VWW     ",
"   G     G     G      ",
NULL
};

#define SHAPE_GUARD_ORANGE_RIGHT 6
const char *shape_guard_orange_right[] =
{/*
 0123456789012345678901 */
"   OOOOOOOOOOOOOOO    ",
"  O  WWWWOOOWWWW  O   ",
"  OOWWWWWWBWWWWWWOO   ",
"  OOWWW  BBWWW  OOO   ",
"  OOWWW  BBWWW  OOO   ",
"  OOWWWWWWBWWWWWWOO   ",
"  OOWWWWWWBWWWWWWOO   ",
"  OOWWWWWWBWWWWWWOO   ",
"  O  WWWWOOOWWWW  O   ",
"  OOOOOOOOOOOOOOOOO   ",
"  WWWWWGWWWWWGWWWWG   ",
"   VWW   VWW   VWW    ",
"    G     G     G     ",
NULL
};


#define SHAPE_SNACKER_RIGHT_1 7
const char *shape_snacker_right_1[] =
{/*
 0123456789012345678901 */
"                      ",
"                      ",
"      GWWWWWWW        ",
"     VWW  WWWWW       ",
"    GWWW  WWWWWW      ",
"  WWWWWWWW            ",
"  WWWWWWWW            ",
"  WWWWWWWWW           ",
"    GWWWWWWWW         ",
"     VWWWWWWWWWW      ",
"      GWWWWWWWW       ",
"                      ",
"                      ",
NULL
};

#define SHAPE_SNACKER_RIGHT_2 8
const char *shape_snacker_right_2[] =
{/*
 0123456789012345678901 */
"                      ",
"                      ",
"                      ",
"  WW                  ",
"  WW  GWWWWWWW        ",
"  WW VWW  WWWWW       ",
"  WWGWWW  WWWWWW      ",
"  WWWWWWWW            ",
"  WWWWWWWWWWWWWW      ",
"  WWWWWWWWWWWWWW      ",
"   GWWWWWWWWWWW       ",
"    VWWWWWWWW         ",
"                      ",
"                      ",
"                      ",
NULL
};

#define SHAPE_SNACKER_DOWN_1 9
const char *shape_snacker_down_1[] =
{/*
 0123456789012345678901 */
"        GWWWWWWV      ",
"        GWWWWWWV      ",
"       VWWWV          ",
"      GWWWWWG         ",
"      GWWWWWWV        ",
"      GWWWWV  B       ",
"      GWWWWV  B       ",
"      GWWWG WWG       ",
"      GWWV  WWG       ",
"      GWWV  WWG       ",
"      GWWV  WV        ",
"       VWV  G         ",
NULL
};

#define SHAPE_SNACKER_DOWN_2 10
const char *shape_snacker_down_2[] =
{/*
 0123456789012345678901 */
"    WWWWWWV           ",
"    WWWWWWV           ",
"       GWWWG          ",
"     GWWWWWWWWG       ",
"    VWWWWW  WWG       ",
"   VWWWWWW  WWWV      ",
"  VWWWWW  WWWWWV      ",
"  VWWWW    WWWWV      ",
"  VWWW      WWWV      ",
"  VWW        WWV      ",
"   GG        GG       ",
"                      ",
NULL
};

#define SHAPE_DESSERT 11
const char *shape_dessert[] =
{/*
 0123456789012345678901 */
"                      ",
"             BB       ",
"           BB         ",
"         BB OOO       ",
"   OOOOO  OOOOOOO     ",
" OOOOOOOOOOOOOOOOO    ",
"OOOO  OOOOOO  OOOO    ",
"OOOOOOOOOOOOOOOOOO    ",
"OOOOOOOO  OOOOOOOO    ",
"OOO OOOOOOOOOO OOO    ",
"OOOO          OOO     ",
" OOOOOOOOOOOOOOO      ",
"    OOOOOOOOO         ",
NULL
};

#define SHAPE_GUMDROP 12
const char *shape_gumdrop[] =
{/*
 0123456789012345678901 */
"  OOO   ",
"OOOOOOO ",
"OOOOOOO ",
"OOOOOOO ",
"  OOO   ",
NULL
};

#define SHAPE_WALL_T_RIGHT 13
const char *shape_wall_t_right[] =
{
"W   ",
"W   ",
"W   ",
"W   ",
"W   ",
"W   ",
"W   ",
"W   ",
"W   ",
"W   ",
"WWWWWWWWWW",
"W   ",
"W   ",
"W   ",
"W   ",
"W   ",
"W   ",
"W   ",
"W   ",
"W   ",
NULL
};

#define SHAPE_WALL_T_LEFT 14
const char *shape_wall_t_left[] =
{
"          W",
"          W",
"          W",
"          W",
"          W",
"          W",
"          W",
"          W",
"          W",
"          W",
"WWWWWWWWWWW",
"          W",
"          W",
"          W",
"          W",
"          W",
"          W",
"          W",
"          W",
"          W",
"          W",
NULL
};

#define SHAPE_WALL_T_DOWN 15
const char *shape_wall_t_down[] =
{
"WWWWWWWWWWWWWWWWWWWW",
"          W         ",
"          W         ",
"          W         ",
"          W         ",
"          W         ",
"          W         ",
"          W         ",
"          W         ",
"          W         ",
"          W         ",
NULL
};

#define SHAPE_WALL_T_UP 16
const char *shape_wall_t_up[] =
{
"          W         ",
"          W         ",
"          W         ",
"          W         ",
"          W         ",
"          W         ",
"          W         ",
"          W         ",
"          W         ",
"          W         ",
"WWWWWWWWWWWWWWWWWWWW",
NULL
};

#define SHAPE_WALL_L_LEFT_DOWN 17
const char *shape_wall_l_left_down[] =
{
"WWWWWWWWWWW",
"          W",
"          W",
"          W",
"          W",
"          W",
"          W",
"          W",
"          W",
"          W",
"          W",
NULL
};

#define SHAPE_WALL_L_RIGHT_DOWN 18
const char *shape_wall_l_right_down[] =
{
"WWWWWWWWWW",
"W         ",
"W         ",
"W         ",
"W         ",
"W         ",
"W         ",
"W         ",
"W         ",
"W         ",
"W         ",
NULL
};

#define SHAPE_WALL_L_LEFT_UP 19
const char *shape_wall_l_left_up[] =
{
"          W",
"          W",
"          W",
"          W",
"          W",
"          W",
"          W",
"          W",
"          W",
"          W",
"WWWWWWWWWWW",
NULL
};

#define SHAPE_WALL_L_RIGHT_UP 20
const char *shape_wall_l_right_up[] =
{
"W         ",
"W         ",
"W         ",
"W         ",
"W         ",
"W         ",
"W         ",
"W         ",
"W         ",
"W         ",
"WWWWWWWWWW",
NULL
};

#define SHAPE_WALL_CROSS 21
const char *shape_wall_cross[] =
{
"          W",
"          W",
"          W",
"          W",
"          W",
"          W",
"          W",
"          W",
"          W",
"          W",
"WWWWWWWWWWWWWWWWWWWWW",
"          W",
"          W",
"          W",
"          W",
"          W",
"          W",
"          W",
"          W",
"          W",
"          W",
NULL
};

#define SHAPE_WALL_LEFT_HORIZONTAL 22
#define SHAPE_WALL_RIGHT_HORIZONTAL 23
const char *shape_wall_short_horizontal[] =
{
"WWWWWWWWWW",
NULL
};

#define SHAPE_WALL_UP_VERTICAL 24
#define SHAPE_WALL_DOWN_VERTICAL 25
const char *shape_wall_short_vertical[] =
{
"W",
"W",
"W",
"W",
"W",
"W",
"W",
"W",
"W",
"W",
"W",
NULL
};

const struct shape Shape[] =
{
 [SHAPE_SPACE] = { snack_colors, shape_space },
 [SHAPE_WALL_HORIZONTAL] = { snack_colors, shape_wall_horizontal, -10, 0 },
 [SHAPE_WALL_VERTICAL] = { snack_colors, shape_wall_vertical, 0, -10 },
 [SHAPE_GUARD_VIOLET_LEFT] = { snack_colors, shape_guard_violet_left },
 [SHAPE_GUARD_GREEN_DOWN] = { snack_colors, shape_guard_green_down },
 [SHAPE_GUARD_BLUE_UP] = { snack_colors, shape_guard_blue_up },
 [SHAPE_GUARD_ORANGE_RIGHT] = { snack_colors, shape_guard_orange_right },
 [SHAPE_SNACKER_RIGHT_1] = { snack_colors, shape_snacker_right_1  },
 [SHAPE_SNACKER_RIGHT_2] = { snack_colors, shape_snacker_right_2  },
 [SHAPE_SNACKER_DOWN_1] = { snack_colors, shape_snacker_down_1   },
 [SHAPE_SNACKER_DOWN_2] = { snack_colors, shape_snacker_down_2   },
 [SHAPE_DESSERT] = { snack_colors, shape_dessert          },
 [SHAPE_GUMDROP] = { snack_colors, shape_gumdrop, -3, -2 },
 [SHAPE_WALL_T_RIGHT] = { snack_colors, shape_wall_t_right, 0, -10 },
 [SHAPE_WALL_T_LEFT] = { snack_colors, shape_wall_t_left, -10, -10 },
 [SHAPE_WALL_T_DOWN] = { snack_colors, shape_wall_t_down, -10, 0 },
 [SHAPE_WALL_T_UP] = { snack_colors, shape_wall_t_up, -10, -10 },
 [SHAPE_WALL_L_LEFT_DOWN] = { snack_colors, shape_wall_l_left_down, -10, 0 },
 [SHAPE_WALL_L_RIGHT_DOWN] = { snack_colors, shape_wall_l_right_down, 0, 0 },
 [SHAPE_WALL_L_LEFT_UP] = { snack_colors, shape_wall_l_left_up, -10, -10 },
 [SHAPE_WALL_L_RIGHT_UP] = { snack_colors, shape_wall_l_right_up, 0, -10 },
 [SHAPE_WALL_CROSS] = { snack_colors, shape_wall_cross, -10, -10 },
 [SHAPE_WALL_LEFT_HORIZONTAL] = { snack_colors, shape_wall_short_horizontal, -10, 0 },
 [SHAPE_WALL_RIGHT_HORIZONTAL] = { snack_colors, shape_wall_short_horizontal, 0, 0 },
 [SHAPE_WALL_UP_VERTICAL] = { snack_colors, shape_wall_short_vertical, 0, -10 },
 [SHAPE_WALL_DOWN_VERTICAL] = { snack_colors, shape_wall_short_vertical, 0, 0 },
//  [5] = { NULL, NULL }
};
