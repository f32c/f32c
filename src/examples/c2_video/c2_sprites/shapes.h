#include <stdlib.h>
#include "Compositing/shape.h"

// ascii-art of the shapes
const struct charcolors std_colors[] =
{ //      RRGGBB
  {'O', RGB2PIXEL(0xFF7F00)}, // orange
  {'R', RGB2PIXEL(0xFF0000)}, // red
  {'Y', RGB2PIXEL(0xFFFF00)}, // yellow
  {'C', RGB2PIXEL(0x00FFFF)}, // cyan
  {'G', RGB2PIXEL(0x00FF00)}, // green
  {'B', RGB2PIXEL(0x0000FF)}, // blue
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

const struct shape Shape[] =
{
  [0] = { std_colors, shape_invader1 },
  [1] = { std_colors, shape_invader2 },
  [2] = { std_colors, shape_ship1},
//  [3] = { std_colors, shape_ship2},
//  [4] = { std_colors, shape_ship3},
//  [5] = { NULL, NULL }
};

