#include <stdlib.h>
#include "Compositing/shape.h"

// ascii-art of the shapes
const struct charcolors std_colors[] =
{ //      RRGGBB
  {'O', RGB2PIXEL(0xF25E00)}, // orange
  {'R', RGB2PIXEL(0xFF0000)}, // red
  {'Y', RGB2PIXEL(0xFFFF00)}, // yellow
  {'C', RGB2PIXEL(0x00FFFF)}, // cyan
  {'G', RGB2PIXEL(0x00FF00)}, // green
  {'B', RGB2PIXEL(0x0000FF)}, // blue
  {'W', RGB2PIXEL(0xFFFFFF)}, // white
  {' ', RGB2PIXEL(0)}, // transparent
  {0, 0}
};

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

const char *shape_ship1[] =
{
"       W",
"       W",
"       W",
"      WWW",
"      WWW",
"   R  WWW  R",
"   R  WWW  R",
"   W WWWWW W",
"R  WBWWRWWBW  R",
"R  BWWRRRWWB  R",
"W  WWWRWRWWW  W",
"W WWWWWWWWWWW W",
"WWWWWRWWWRWWWWW",
"WWW RRWWWRR WWW",
"WW  RR W RR  WW",
"W      W      W",
NULL
};

const char *shape_ship2[] =
{
"              WW",
"              WW",
"              WW",
"              WW",
"              WW",
"              WW",
"            WWWWWW",
"            WWWWWW",
"            WWWWWW",
"            WWWWWW",
"      RR    WWWWWW    RR",
"      RR    WWWWWW    RR",
"      RR    WWWWWW    RR",
"      RR    WWWWWW    RR",
"      WW  WWWWWWWWWW  WW",
"      WW  WWWWWWWWWW  WW",
"RR    WWBBWWWWRRWWWWBBWW    RR",
"RR    WWBBWWWWRRWWWWBBWW    RR",
"RR    BBWWWWRRRRRRWWWWBB    RR",
"RR    BBWWWWRRRRRRWWWWBB    RR",
"WW    WWWWWWRRWWRRWWWWWW    WW",
"WW    WWWWWWRRWWRRWWWWWW    WW",
"WW  WWWWWWWWWWWWWWWWWWWWWW  WW",
"WW  WWWWWWWWWWWWWWWWWWWWWW  WW",
"WWWWWWWWWWRRWWWWWWRRWWWWWWWWWW",
"WWWWWWWWWWRRWWWWWWRRWWWWWWWWWW",
"WWWWWW  RRRRWWWWWWRRRR  WWWWWW",
"WWWWWW  RRRRWWWWWWRRRR  WWWWWW",
"WWWW    RRRR  WW  RRRR    WWWW",
"WWWW    RRRR  WW  RRRR    WWWW",
"WW            WW            WW",
"WW            WW            WW",
NULL
};

const char *shape_ship3[] =
{
"   WWW  ",
"   WWWOOOOO ",
" WWWWWYYYYYYYYYY",
"   WWWWWOOO ",
"   WWWWWW   ",
"   WWCWWWWW       BBBBBB",
" WWWWCCWWWWWW    BBWWWWWW   ",
"WWWWOOOOOWWWWWWWWWWWWWWWWWW ",
"  WWOOOOOOYYYWWWWWWYOORRROYWWWWW",
"WWWWOOOOOWWWWWWWWWWWWWWWWWW ",
" WWWWCCWWWWWW    BBWWWWWW   ",
"   WWCWWWWW       BBBBBB",
"   WWWWWW   ",
"   WWWWWOOO ",
" WWWWWYYYYYYYYYY",
"   WWWOOOOO ",
"   WWW  ",
NULL
};

const char *shape_invader1[] =
{/*
 01234567890123456789012345678901 */
"      GGGG  ",
"      GGGG  ",
"    GGGGGGGG",
"    GGGGGGGG",
"  GGGGGGGGGGGG  ",
"  GGGGGGGGGGGG  ",
"GGGG  GGGG  GGGG",
"GGGG  GGGG  GGGG",
"GGGGGGGGGGGGGGGG",
"GGGGGGGGGGGGGGGG",
"    GG    GG",
"    GG    GG",
"  GG  GGGG  GG  ",
"  GG  GGGG  GG  ",
"GG  GG    GG  GG",
"GG  GG    GG  GG",
NULL
};

const char *shape_invader2[] =
{/*
 01234567890123456789012345678901 */
"      OOOO  ",
"      OOOO  ",
"    OOOOOOOO",
"    OOOOOOOO",
"  OOOOOOOOOOOO  ",
"  OOOOOOOOOOOO  ",
"OOOO  OOOO  OOOO",
"OOOO  OOOO  OOOO",
"OOOOOOOOOOOOOOOO",
"OOOOOOOOOOOOOOOO",
"  OO        OO  ",
"  OO        OO  ",
"OO            OO",
"OO            OO",
"  OO        OO  ",
"  OO        OO  ",
NULL
};

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

const struct shape Shape[] =
{
  [0] = { std_colors, shape_invader1 },
  [1] = { std_colors, shape_invader2 },
  [2] = { std_colors, shape_ship1},
  [3] = { snack_colors, shape_guard_violet_left },
  [4] = { snack_colors, shape_guard_green_down },
  [5] = { snack_colors, shape_guard_blue_up },
  [6] = { snack_colors, shape_guard_orange_right },
  [7] = { snack_colors, shape_snacker_right_1  },
  [8] = { snack_colors, shape_snacker_right_2  },
  [9] = { snack_colors, shape_snacker_down_1   },
 [10] = { snack_colors, shape_snacker_down_2   },
 [11] = { snack_colors, shape_dessert          },
//  [5] = { NULL, NULL }
};

