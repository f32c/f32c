/* f32c Galaga
 * AUTHOR=EMARD
 * LICENSE=BSD
 * Game logic
 */
extern "C"
{
#include <stdlib.h>
#include <string.h>
#include <math.h>
}

#include "Compositing/Compositing.h"
#include "shapes.h"

#if 1
// ULX3S onboard buttons
#define BTN_L (5)
#define BTN_R (6)
#define BTN_F (1)
#define BTN_PRESSED (HIGH)
#endif

#if 0
// ULX3S external joystick
#define BTN_L (32+25)
#define BTN_R (32+26)
#define BTN_F (32+21)
#define BTN_PRESSED (LOW)
#endif

// Arduino workaround
#define HIGH  1
#define LOW   0
#define INPUT 1
int digitalRead(int x) {return 0;}
void pinMode(int x, int y) {}

int game_demo = 1; // 0-play 1-demo

#define SPRITE_MAX 512
#define N_SHAPES (sizeof(Shape)/sizeof(Shape[0]))

// demo mode ship slow shooting freq (friendly mode)
#define SHIP_SHOOTING_FREQ_SLOW 5000000
// demo mode ship fast shooting freq (alien_mode)
#define SHIP_SHOOTING_FREQ_FAST 500000000

// max number of objects on the screen
#define SHIPS_MAX (SPRITE_MAX-N_SHAPES)

// fixed point scale
#define FPSCALE 256

// global speed 1/2/4 (more=faster)
#define SPEED 6

// fleet drift (more = SLOWER)
#define FLEET_DRIFT 4

// alien distance in convoy
#define CONVOY_DISTANCE 24

// alien x-distance in fleet
#define FLEET_DISTANCE 20

// numver of different attack formations in the fleet
#define FLEET_MAX_GROUP 10

// showcase all sprites on the left (debug)
#define SHOWCASE_SPRITES 0

// off-screen y
#define OFF_SCREEN 2048

// time to reload next ship missile
#define SHIP_MISSILE_RELOAD 8

// time to reload next alien bomb
#define ALIEN_BOMB_RELOAD 8

// alien suction bars distance
#define SUCTION_DISTANCE 12

Compositing c2;

// starship states
enum 
{ 
  S_NONE,
  S_ALIEN_PREPARE,
  S_ALIEN_CONVOY, S_ALIEN_HOMING, S_ALIEN_HOME, S_ALIEN_ATTACK,
  S_SUCTION_BAR,
  S_BOMB, S_MISSILE, S_EXPLOSION, S_SHIP, S_FIREBALL
};

int *isin; // sine table for full circle 0-255 
uint8_t *iatan; // arctan table 0-FPSCALE
int Alien_count = 0; // number of aliens on the screen
int Alien_friendly = 1; // by default aliens are friendly (they don't attack)
int Missile_wiggle = 0; // 0-3
int Hold_fire = 0; // alien hold fire counter
int Hold_fire_delay = 20; // frames delay between two aliens firing
int Hold_fire_new_ship = 2000; // frames delay for introduction of the new ship

struct shape_center
{
  int x,y;
};
// center pixel x,y coordinates for each shape:
struct shape_center Scenter[] =
{
  // aliens small
  [SH_ALIEN1R] = { 4, 5}, // right
  [SH_ALIEN1U] = { 5, 3}, // up
  [SH_ALIEN1L] = { 3, 6}, // left
  [SH_ALIEN1D] = { 5, 4}, // down
  [SH_ALIEN2R] = { 4, 5}, // right
  [SH_ALIEN2U] = { 5, 3}, // up
  [SH_ALIEN2L] = { 3, 6}, // left
  [SH_ALIEN2D] = { 5, 4}, // down
  // aliens big
  [SH_ALIEN3R] = {10, 9},   // right
  [SH_ALIEN3U] = { 9, 5},   // up
  [SH_ALIEN3L] = { 5, 10},  // left
  [SH_ALIEN3D] = {10, 6},   // down
  [SH_ALIEN4R] = {10, 9},   // right
  [SH_ALIEN4U] = { 9, 5},   // up
  [SH_ALIEN4L] = { 5, 10},  // left
  [SH_ALIEN4D] = {10, 6},   // down
  [SH_ALIEN5R] = {10, 9},   // right
  [SH_ALIEN5U] = { 9, 13},  // up
  [SH_ALIEN5L] = { 5, 10},  // left
  [SH_ALIEN5D] = {10, 14},  // down
  // ship single
  [SH_SHIP1R] = {5, 5},
  [SH_SHIP1U] = {5, 5},
  [SH_SHIP1L] = {5, 5},
  [SH_SHIP1D] = {5, 5},
  // ship double
  [SH_SHIP2] = {9, 5},
  // suction bars
  [SH_ALIEN_SUCTION1] = { 1, 1},
  [SH_ALIEN_SUCTION3] = { 5, 1},
  [SH_ALIEN_SUCTION5] = { 9, 1},
  [SH_ALIEN_SUCTION7] = {13, 1},
  [SH_ALIEN_SUCTION9] = {17, 1},
  [SH_ALIEN_SUCTION11] = {21, 1},
  // missile
  [SH_MISSILE0] = {1, 5},
  [SH_MISSILE1] = {1, 5},
  [SH_MISSILE2] = {1, 5},
  [SH_MISSILE3] = {1, 5},
  // bomb
  [SH_BLOCK_RED] = {1, 1},
  [SH_BLOCK_ORANGE] = {1, 1},
  [SH_BLOCK_YELLOW] = {1, 1},
  [SH_BLOCK_GREEN] = {1, 1},
  [SH_BLOCK_CYAN] = {1, 1},
  [SH_BLOCK_BLUE] = {1, 1},
  [SH_BLOCK_VIOLETT] = {1, 1},
  [SH_BLOCK_WHITE] = {1, 1},
  // fireball
  [SH_FIREBALLY0] = {32, 32},
  [SH_FIREBALLY1] = {32, 32},
  [SH_FIREBALLY2] = {28, 28},
  [SH_FIREBALLY3] = {20, 20},
  [SH_FIREBALLB0] = {32, 32},
  [SH_FIREBALLB1] = {32, 28},
  [SH_FIREBALLB2] = {32, 21},
  [SH_FIREBALLB3] = {32, 21},
};

struct fleet
{
  int x,y;
  int xmin,xmax;
  int xd; // x-direction
};

struct fleet Fleet =
{
  200*FPSCALE,32*FPSCALE, // initial xy
  160*FPSCALE,400*FPSCALE, // min-max x
  SPEED*FPSCALE/FLEET_DRIFT // initial x-dir
};


// easy search that suction is present
struct suction
{
  int x,y;
  int countdown; // sucks until 0
};

struct suction Suction =
{
  0,0,
  0,
};

struct path_segment
{
  int v; // velocity, v = FPSCALE --> 1 pixel/frame
  uint8_t a; // initial angle 0-255 covers 0-360 degrees, 0->right, 64->up, 128->left, 192->down
  int8_t r; // rotation (angle increment)
  int n; // how many frames to run on this path segment, 0 for last
};

struct path_segment stage1_demo[] =
{
  {FPSCALE,   0, 0, 50 }, // right 50 frames
  {FPSCALE,  32, 0, 50 }, // right-up 50 frames
  {FPSCALE,  64, 0, 50 }, // up 50 fames
  {FPSCALE,  96, 0, 50 }, // up-left 50 fames
  {FPSCALE, 128, 0, 50 }, // left 50 fames
  {FPSCALE, 160, 0, 50 }, // left-down 50 fames
  {FPSCALE, 192, 0, 50 }, // down 50 fames
  {FPSCALE, 224, 0, 50 }, // down-right 50 fames
  {FPSCALE,   0, 1, 256 }, // left circle 256 frames
  {FPSCALE,   0,-1, 256 }, // right circle 256 frames
  {FPSCALE,   0, 1, 256 }, // left circle 256 frames
  {FPSCALE,   0,-1, 256 }, // right circle 256 frames
  {0,0,0} // end
};

struct path_segment stage1_convoy[] =
{
  {FPSCALE,   0, 0, 50 }, // right 50 frames
  {FPSCALE,  32, 0, 50 }, // right-up 50 frames
  {FPSCALE,  64, 0, 50 }, // up 50 fames
  {FPSCALE,  96, 0, 50 }, // up-left 50 fames
  {FPSCALE, 128, 0, 50 }, // left 50 fames
  {FPSCALE, 160, 0, 50 }, // left-down 50 fames
  {FPSCALE, 192, 0, 50 }, // down 50 fames
  {FPSCALE, 224, 0, 50 }, // down-right 50 fames
  {FPSCALE,   0, 1, 256 }, // left circle 256 frames
  {FPSCALE,   0,-1, 256 }, // right circle 256 frames
  {FPSCALE,   0, 1, 256 }, // left circle 256 frames
  {FPSCALE,   0,-1, 256 }, // right circle 256 frames
  {0,0,0} // end
};

struct path_segment stage2_convoy_left[] =
{
  {SPEED*FPSCALE,   8, 0,     128/SPEED }, // right slightly up 128 frames
  {SPEED*FPSCALE,   0, SPEED, 256/SPEED }, // left circle 256 frames
  {SPEED*FPSCALE,   8, 0,     128/SPEED }, // right slightly up 128 frames
  {SPEED*FPSCALE,   0,-SPEED, 256/SPEED }, // right circle 256 frames
  {SPEED*FPSCALE,   0, SPEED, 126/SPEED }, // left helf-circle 128 frames
  {SPEED*FPSCALE, 128,-SPEED, 128/SPEED }, // right helf-circle 128 frames
  {0,0,0} // end
};

struct path_segment stage2_convoy_right[] =
{
  {SPEED*FPSCALE,  120, 0,     128/SPEED }, // right slightly up 128 frames
  {SPEED*FPSCALE,  128,-SPEED, 256/SPEED }, // left circle 256 frames
  {SPEED*FPSCALE,  120, 0,     128/SPEED }, // right slightly up 128 frames
  {SPEED*FPSCALE,  128, SPEED, 256/SPEED }, // right circle 256 frames
  {SPEED*FPSCALE,  128,-SPEED, 128/SPEED }, // left half-circle 128 frames
  {SPEED*FPSCALE,    0, SPEED, 128/SPEED }, // right half-circle 128 frames
  {0,0,0} // end
};

struct path_segment stage1_wave1_left[] =
{
  {SPEED*FPSCALE,  176, 0,     256/SPEED }, // down left 256 frames
  {SPEED*FPSCALE,  176, SPEED,  80/SPEED }, // right circle 80 frames
  {SPEED*FPSCALE,    8, 0,     128/SPEED }, // right up 128 frames
  {SPEED*FPSCALE,    0, SPEED,  64/SPEED }, // right circle 64 frames
  {SPEED*FPSCALE,   64, 0,      96/SPEED }, // up 96 frames
  {0,0,0} // end
};

struct path_segment stage1_wave1_right[] =
{
  {SPEED*FPSCALE,  208, 0,     256/SPEED }, // down right 256 frames
  {SPEED*FPSCALE,  208,-SPEED,  80/SPEED }, // left circle 80 frames
  {SPEED*FPSCALE,  120, 0,     128/SPEED }, // left up 128 frames
  {SPEED*FPSCALE,  128,-SPEED,  64/SPEED }, // left circle 64 frames
  {SPEED*FPSCALE,   64, 0,      96/SPEED }, // up 96 frames
  {0,0,0} // end
};

struct path_segment alien_attack_straight_down[] =
{
  {SPEED*FPSCALE,  192, 0,     512/SPEED }, // straight down 512frames
  {0,0,0} // end
};

struct path_segment alien_attack_small_vibration[] =
{
  {SPEED*FPSCALE,  208, 0,      64/SPEED }, // down right 64 frames
  {SPEED*FPSCALE,  208,-SPEED,  32/SPEED }, // left circle 32 frames
  {SPEED*FPSCALE,  176, SPEED,  32/SPEED }, // right circle 32 frames
  {SPEED*FPSCALE,  208,-SPEED,  32/SPEED }, // left circle 32 frames
  {SPEED*FPSCALE,  176, SPEED,  32/SPEED }, // right circle 32 frames
  {SPEED*FPSCALE,  208,-SPEED,  32/SPEED }, // left circle 32 frames
  {SPEED*FPSCALE,  176, SPEED,  32/SPEED }, // right circle 32 frames
  {SPEED*FPSCALE,  208,-SPEED,  32/SPEED }, // left circle 32 frames
  {SPEED*FPSCALE,  176, SPEED,  32/SPEED }, // right circle 32 frames
  {SPEED*FPSCALE,  208,-SPEED,  32/SPEED }, // left circle 32 frames
  {SPEED*FPSCALE,  176, SPEED,  32/SPEED }, // right circle 32 frames
  {SPEED*FPSCALE,  208,-SPEED,  32/SPEED }, // left circle 32 frames
  {SPEED*FPSCALE,  176, SPEED,  32/SPEED }, // right circle 32 frames
  {0,0,0} // end
};

struct path_segment alien_attack_medium_vibration[] =
{
  {SPEED*FPSCALE,  224, 0,      64/SPEED }, // down right 64 frames
  {SPEED*FPSCALE,  224,-SPEED,  64/SPEED }, // left circle 64 frames
  {SPEED*FPSCALE,  160, SPEED,  64/SPEED }, // right circle 64 frames
  {SPEED*FPSCALE,  224,-SPEED,  64/SPEED }, // left circle 64 frames
  {SPEED*FPSCALE,  160, SPEED,  64/SPEED }, // right circle 64 frames
  {SPEED*FPSCALE,  224,-SPEED,  64/SPEED }, // left circle 64 frames
  {SPEED*FPSCALE,  160, SPEED,  64/SPEED }, // right circle 64 frames
  {SPEED*FPSCALE,  224,-SPEED,  64/SPEED }, // left circle 64 frames
  {SPEED*FPSCALE,  160, SPEED,  64/SPEED }, // right circle 64 frames
  {SPEED*FPSCALE,  224,-SPEED,  64/SPEED }, // left circle 64 frames
  {SPEED*FPSCALE,  160, SPEED,  64/SPEED }, // right circle 64 frames
  {0,0,0} // end
};

struct path_segment alien_attack_zig_zag_return[] =
{
  {SPEED*FPSCALE,  223, 0,     128/SPEED }, // down right 64 frames
  {SPEED*FPSCALE,  161, 0,     128/SPEED }, // down left 64 frames
  {0,0,0} // end
};

struct path_segment alien_attack_zig_zag_thru[] =
{
  {SPEED*FPSCALE,  223, 0,     128/SPEED }, // down right 64 frames
  {SPEED*FPSCALE,  161, 0,     128/SPEED }, // down left 64 frames
  {SPEED*FPSCALE,  223, 0,     128/SPEED }, // down right 64 frames
  {SPEED*FPSCALE,  161, 0,     128/SPEED }, // down left 64 frames
  {SPEED*FPSCALE,  223, 0,     128/SPEED }, // down right 64 frames
  {SPEED*FPSCALE,  161, 0,     128/SPEED }, // down left 64 frames
  {SPEED*FPSCALE,  223, 0,     128/SPEED }, // down right 64 frames
  {SPEED*FPSCALE,  161, 0,     128/SPEED }, // down left 64 frames
  {SPEED*FPSCALE,  223, 0,     128/SPEED }, // down right 64 frames
  {SPEED*FPSCALE,  161, 0,     128/SPEED }, // down left 64 frames
  {0,0,0} // end
};

struct path_segment alien_attack_zig_zag_small_circle[] =
{
  {SPEED*FPSCALE,  223, 0,     128/SPEED }, // down right 64 frames
  {SPEED*FPSCALE,  161, 0,     128/SPEED }, // down left 64 frames
  {SPEED*FPSCALE,  223, 0,     128/SPEED }, // down right 64 frames
  {SPEED*FPSCALE,  161, 0,     128/SPEED }, // down left 64 frames
  {SPEED*FPSCALE,  223, SPEED, 256/SPEED }, // left circle 64 frames
  {SPEED*FPSCALE,  223, 0,     128/SPEED }, // down right 64 frames
  {SPEED*FPSCALE,  161, 0,     128/SPEED }, // down left 64 frames
  {SPEED*FPSCALE,  223, 0,     128/SPEED }, // down right 64 frames
  {SPEED*FPSCALE,  161, 0,     128/SPEED }, // down left 64 frames
  {SPEED*FPSCALE,  223, 0,     128/SPEED }, // down right 64 frames
  {SPEED*FPSCALE,  161, 0,     128/SPEED }, // down left 64 frames
  {0,0,0} // end
};

struct path_segment alien_attack_zig_zag_big_circle[] =
{
  {SPEED*FPSCALE,  223, 0,      128/SPEED }, // down right 64 frames
  {SPEED*FPSCALE,  161, 0,      128/SPEED }, // down left 64 frames
  {SPEED*FPSCALE,  223, 0,      128/SPEED }, // down right 64 frames
  {SPEED*FPSCALE,  161, 0,      128/SPEED }, // down left 64 frames
  {SPEED*FPSCALE,  223, SPEED/2,512/SPEED }, // left circle 64 frames
  {SPEED*FPSCALE,  223, 0,      128/SPEED }, // down right 64 frames
  {SPEED*FPSCALE,  161, 0,      128/SPEED }, // down left 64 frames
  {SPEED*FPSCALE,  223, 0,      128/SPEED }, // down right 64 frames
  {SPEED*FPSCALE,  161, 0,      128/SPEED }, // down left 64 frames
  {SPEED*FPSCALE,  223, 0,      128/SPEED }, // down right 64 frames
  {SPEED*FPSCALE,  161, 0,      128/SPEED }, // down left 64 frames
  {0,0,0} // end
};

struct path_segment alien_suction[] =
{
  {SPEED*FPSCALE,  192, 0,     304/SPEED }, // straight down 304 frames
  {            0,  192, 0,     512/SPEED }, // stop for 512 frames
  {SPEED*FPSCALE,  192, 0,     512/SPEED }, // straight down 512 frames
  {0,0,0} // end
};

struct path_types
{
  struct path_segment *path;
  int orientation; // should the sprite be reshaped (for angular orientation)
};

enum
{
  PT_ALIEN_SUCTION=12,
};

struct path_types Path_types[] =
{
  [0] = {stage1_convoy,1},
  [1] = {stage2_convoy_left,1},
  [2] = {stage2_convoy_right,1},
  [3] = {stage1_wave1_left,1},
  [4] = {stage1_wave1_right,1},
  [5] = {alien_attack_straight_down,0}, // go down straight
  [6] = {alien_attack_small_vibration,0}, // go down with small vibration
  [7] = {alien_attack_medium_vibration,0}, // go down with larger vibration
  [8] = {alien_attack_zig_zag_return,1}, // small zig-zag and return
  [9] = {alien_attack_zig_zag_thru,0}, // go down zig-zag way all way thru
 [10] = {alien_attack_zig_zag_small_circle,1}, // go down zig-zag way all way thru
 [11] = {alien_attack_zig_zag_big_circle,1}, // go down zig-zag way all way thru
 [PT_ALIEN_SUCTION] = {alien_suction,0}, // go down, stop to suck, continue down
  {NULL}
};


/* fleet formation example
**
** 3.  4       W  W W  W
** 3.  6      w w w w w w
** 2.  8    w w w w w w w w
** 1. 10  v v v v v v v v v v
** 4. 10  v v v v v v v v v v
**
** the attack groups
**
** 3.  4       1  2 3  4
** 3.  6      1 1 2 3 4 4
** 2.  8    5 5 6 6 7 7 8 8
** 1. 10  5 5 5 6 6 7 7 8 8 8
** 4. 10  5 5 5 6 6 7 7 8 8 8
**
** 1. v v v v v        v v v v v
**           /          \
**           ->        <-
** 2.    <- O <- w w w w w w w w
** 3. w W w W w w W w W w -> O ->
** 4. v v v v v        v v v v v
**           /          \
**           ->        <-
*/


struct starship
{
  int x,y; // current coordinates of this starship (x256)
  uint8_t a; // current angle of movement
  int v; // the speed (usually SPEED*FPSCALE). 1*FPSCALE -> 1 pixel per frame
  int state; // the state number
  int prepare; // prepare countdown (also shooting reload)
  int sprite; // sprite number which is used to display this starship
  uint32_t shape; // sprite base carrying the shape
  int group; // group membership for alien attacks
  int path_type; // current path type
  int path_state; // state of the current path
  int path_count; // frame countdown until next path state
  int hx, hy; // home position in the fleet
  struct starship *parent; // who created it (from suction bars to the alien)
};
struct starship *Starship;

struct starship *Fighter; // direct pointer to player's ship

// here ship will publish its x/y coordinates
struct ship
{
  int x,y;
  int n; // 1-single ship, 2-double ship
  int suction; // suction counter
  struct starship *sucker; // pointer to alien that sucks this ship
};

struct ship Ship =
{
  391*FPSCALE,400*FPSCALE, // x=392..407 ship coordinates
  1, // single ship
  0, // no suction
};

// defines which members of convoy are to enter the stage
// their flight path and their position in the fleet
struct convoy
{
  int x,y;      // x,y entry point on the screen
  int hx,hy;    // x,y coordinates in fleet
  int group;    // group membership
  int prepare;  // time delay of the alien to prepare for convoy start
  int8_t path;  // convoy path type
  int8_t alien_type; // alien type 0-3, -1 end
};

struct convoy Convoy1[] =
{
    {380,  0,   1*FLEET_DISTANCE,3*FLEET_DISTANCE,5,  1, 3,0 },
    {380,  0,   2*FLEET_DISTANCE,3*FLEET_DISTANCE,5,  2, 3,0 },
    {380,  0,   3*FLEET_DISTANCE,3*FLEET_DISTANCE,5,  3, 3,0 },
    {380,  0,   4*FLEET_DISTANCE,3*FLEET_DISTANCE,6,  4, 3,0 },
    {380,  0,   5*FLEET_DISTANCE,3*FLEET_DISTANCE,6,  5, 3,0 },
    {420,  0,   6*FLEET_DISTANCE,3*FLEET_DISTANCE,7,  1, 4,0 },
    {420,  0,   7*FLEET_DISTANCE,3*FLEET_DISTANCE,7,  2, 4,0 },
    {420,  0,   8*FLEET_DISTANCE,3*FLEET_DISTANCE,8,  3, 4,0 },
    {420,  0,   9*FLEET_DISTANCE,3*FLEET_DISTANCE,8,  4, 4,0 },
    {420,  0,  10*FLEET_DISTANCE,3*FLEET_DISTANCE,8,  5, 4,0 },

    {640,290,   2*FLEET_DISTANCE,2*FLEET_DISTANCE,5, 40+ 0, 2,1 },
    {640,290,   3*FLEET_DISTANCE,2*FLEET_DISTANCE,5, 40+ 1, 2,1 },
    {640,290,   4*FLEET_DISTANCE,2*FLEET_DISTANCE,6, 40+ 2, 2,1 },
    {640,290,   5*FLEET_DISTANCE,2*FLEET_DISTANCE,6, 40+ 3, 2,1 },
    {640,290,   6*FLEET_DISTANCE,2*FLEET_DISTANCE,7, 40+ 4, 2,1 },
    {640,290,   7*FLEET_DISTANCE,2*FLEET_DISTANCE,7, 40+ 5, 2,1 },
    {640,290,   8*FLEET_DISTANCE,2*FLEET_DISTANCE,8, 40+ 6, 2,1 },
    {640,290,   9*FLEET_DISTANCE,2*FLEET_DISTANCE,8, 40+ 7, 2,1 },

    {160,260,   3*FLEET_DISTANCE,  1*FLEET_DISTANCE,1,  90+ 0, 1,1 },
    {160,260,   6*FLEET_DISTANCE/2,0*FLEET_DISTANCE,1,  90+ 1, 1,3 },
    {160,260,   4*FLEET_DISTANCE,  1*FLEET_DISTANCE,2,  90+ 2, 1,1 },
    {160,260,   9*FLEET_DISTANCE/2,0*FLEET_DISTANCE,2,  90+ 3, 1,3 },
    {160,260,   5*FLEET_DISTANCE,  1*FLEET_DISTANCE,2,  90+ 4, 1,1 },
    {160,260,   6*FLEET_DISTANCE,  1*FLEET_DISTANCE,3,  90+ 5, 1,1 },
    {160,260,  13*FLEET_DISTANCE/2,0*FLEET_DISTANCE,3,  90+ 6, 1,3 },
    {160,260,   7*FLEET_DISTANCE,  1*FLEET_DISTANCE,3,  90+ 7, 1,1 },
    {160,260,  16*FLEET_DISTANCE/2,0*FLEET_DISTANCE,4,  90+ 8, 1,3 },
    {160,260,   8*FLEET_DISTANCE,  1*FLEET_DISTANCE,4,  90+ 9, 1,1 },

    {380,  0,   1*FLEET_DISTANCE,4*FLEET_DISTANCE,5, 140+ 1, 3,0 },
    {380,  0,   2*FLEET_DISTANCE,4*FLEET_DISTANCE,5, 140+ 2, 3,0 },
    {380,  0,   3*FLEET_DISTANCE,4*FLEET_DISTANCE,5, 140+ 3, 3,0 },
    {380,  0,   4*FLEET_DISTANCE,4*FLEET_DISTANCE,6, 140+ 4, 3,0 },
    {380,  0,   5*FLEET_DISTANCE,4*FLEET_DISTANCE,6, 140+ 5, 3,0 },
    {420,  0,   6*FLEET_DISTANCE,4*FLEET_DISTANCE,7, 140+ 1, 4,0 },
    {420,  0,   7*FLEET_DISTANCE,4*FLEET_DISTANCE,7, 140+ 2, 4,0 },
    {420,  0,   8*FLEET_DISTANCE,4*FLEET_DISTANCE,8, 140+ 3, 4,0 },
    {420,  0,   9*FLEET_DISTANCE,4*FLEET_DISTANCE,8, 140+ 4, 4,0 },
    {420,  0,  10*FLEET_DISTANCE,4*FLEET_DISTANCE,8, 140+ 5, 4,0 },

    {  0,0,     0,0,0,   0, 0,-1} // end (alien type -1)
};

struct convoy Convoy_demo[] =
{
    {160,160,  20,20,  1, 1,0 },
    {160,160,  40,20,  2, 1,1 },
    {160,160,  60,20,  3, 1,2 },
    {160,160,  80,20,  4, 1,3 },
    {160,160, 100,20,  5, 1,0 },
    {160,160, 120,20,  6, 1,1 },
    {160,160, 140,20,  7, 1,2 },
    {160,160, 160,20,  8, 1,3 },

    {600,160, 180,20,  1, 2,0 },
    {600,160, 200,20,  2, 2,1 },
    {600,160, 220,20,  3, 2,2 },
    {600,160, 240,20,  4, 2,3 },
    {600,160, 260,20,  5, 2,0 },
    {600,160, 280,20,  6, 2,1 },
    {600,160, 300,20,  7, 2,2 },
    {600,160, 320,20,  8, 2,3 },

    {  0,0,     0,0,   0, 0,-1} // end (alien type -1)
};

// explosion particle colors for alien types 0-3
int Alien_particle[][4] =
{
  [0] = { SH_BLOCK_WHITE, SH_BLOCK_WHITE, SH_BLOCK_WHITE, SH_BLOCK_BLUE },
  [1] = { SH_BLOCK_YELLOW, SH_BLOCK_YELLOW, SH_BLOCK_CYAN, SH_BLOCK_RED },
  [2] = { SH_BLOCK_WHITE, SH_BLOCK_WHITE, SH_BLOCK_VIOLETT, SH_BLOCK_VIOLETT },
  [3] = { SH_BLOCK_WHITE, SH_BLOCK_WHITE, SH_BLOCK_VIOLETT, SH_BLOCK_ORANGE },
  [4] = { SH_BLOCK_WHITE, SH_BLOCK_WHITE, SH_BLOCK_GREEN, SH_BLOCK_ORANGE },
  [5] = { SH_BLOCK_RED, SH_BLOCK_RED, SH_BLOCK_RED, SH_BLOCK_ORANGE },
};

void create_sine_table()
{
  int i;
  isin = (int *) malloc(256 * sizeof(int));
  for(i = 0; i < 256; i++)
    isin[i] = sin(i * 2.0 * M_PI / 256.0) * (1.0*FPSCALE) + 0.5;
  #if 0
  // "Tools->Serial Plotter" should draw sinewave
  for(i = 0; i < 256; i++)
    printf("isin[%d] = %d\n", i, isin[i]);
  #endif
}

void create_atan_table()
{
  int i;
  iatan = (uint8_t *) malloc(FPSCALE * sizeof(int));
  for(i = 0; i < FPSCALE; i++)
    iatan[i] = atan(i * (1.0 / FPSCALE)) * 256.0 / (2 * M_PI) + 0.5;
}

void allocate_ships()
{
  uint32_t i;
  Starship = (struct starship *) malloc(SHIPS_MAX * sizeof(struct starship) );
  for(i = 0; i < SHIPS_MAX; i++)
  {
    Starship[i].state = S_NONE;
    Starship[i].sprite = N_SHAPES+i;
  }
}

struct starship *find_free()
{
  uint32_t i;
  for(i = 0; i < SHIPS_MAX; i++)
  {
    if( Starship[i].state == S_NONE )
      return &(Starship[i]);
  }
  return NULL;
}

void create_aliens()
{
  uint32_t i;
  struct convoy *convoy;
  struct path_segment *path;
  struct starship *s;

  Alien_friendly = 1; // start with friendly set of aliens

  convoy = Convoy1;
  for(i = 0; i < SHIPS_MAX; i++)
  {
    if( convoy[i].alien_type == -1)
      return; // abort for-loop --- todo this must be done better
    s = find_free();
    if(s == NULL)
      return;
    Alien_count++;
    s->x = convoy[i].x * FPSCALE; // where it will enter screen
    s->y = convoy[i].y * FPSCALE;
    s->hx = convoy[i].hx * FPSCALE; // fleet home position
    s->hy = convoy[i].hy * FPSCALE;
    s->state = S_ALIEN_PREPARE;
    s->prepare = convoy[i].prepare * CONVOY_DISTANCE / SPEED;
    s->shape = (convoy[i].alien_type % 5)*4; // shape base
    s->path_type = convoy[i].path; // path to follow
    s->group = convoy[i].group;
    path = Path_types[s->path_type].path;
    s->a = path[0].a;
    s->v = path[0].v;
    s->path_state = 0;
    s->path_count = path[0].n;
  }
}

// angular move the ship with velocity v
void object_angular_move(struct starship *s)
{
  uint8_t xa = 64 + s->a;
  s->x += isin[xa] * s->v / FPSCALE; // cos
  s->y -= isin[s->a] * s->v / FPSCALE; // sin
  if(s->shape < sizeof(Scenter)/sizeof(Scenter[0]))
  {
    c2.Sprite[s->sprite]->x = s->x / FPSCALE - Scenter[s->shape].x;
    c2.Sprite[s->sprite]->y = s->y / FPSCALE - Scenter[s->shape].y;
  }
  else
  {
    // unknown shape - no centering
    c2.Sprite[s->sprite]->x = s->x / FPSCALE;
    c2.Sprite[s->sprite]->y = s->y / FPSCALE;
  }
}

// initiate 4-frame fireball animaton
// starting from specified shape.
// each frame increases shape number
void fireball_create(int x, int y, int shape)
{
  struct starship *s = find_free();
  if(s == NULL)
    return;
  s->x = x;
  s->y = y;
  s->state = S_FIREBALL;
  s->shape = shape;
  s->path_count = 0;
  c2.sprite_link_content(s->shape, s->sprite);
  c2.Sprite[s->sprite]->x = s->x / FPSCALE - Scenter[s->shape].x;
  c2.Sprite[s->sprite]->y = s->y / FPSCALE - Scenter[s->shape].y;
}

void fireball_move(struct starship *s)
{
  if(++s->path_count <= 3)
  {
    s->shape++;
    c2.sprite_link_content(s->shape, s->sprite);
    c2.Sprite[s->sprite]->x = s->x / FPSCALE - Scenter[s->shape].x;
    c2.Sprite[s->sprite]->y = s->y / FPSCALE - Scenter[s->shape].y;
  }
  else
  {
    s->state = S_NONE;
    c2.Sprite[s->sprite]->y = OFF_SCREEN;
  }
}

// create N explosion particles flying from x,y
void explosion_create(int x, int y, int t, uint8_t n)
{
  int i;
  for(i = 0; i < n; i++)
  {
    struct starship *s;
    s = find_free();
    if(s == NULL)
      return;
    uint32_t rng = rand();
    s->state = S_EXPLOSION;
    s->x = x;
    s->y = y;
    int sind = isin[rng&255]; // sine distribution
    s->v = 32*sind; // max initial speed
    s->path_count = 16; // countdown to disappear
    s->a = rng >> 16; // random angular direction
    // s->shape = SH_BLOCK_RED + (rng&7); // explosion with random colorful particles
    s->shape = Alien_particle[t & 7][rng & 3];
    c2.sprite_link_content(s->shape, s->sprite);
    object_angular_move(s);
  }
}

// move explosion particles
void explosion_move(struct starship *s)
{
  if(s->x < 10*FPSCALE || s->x > 640*FPSCALE || s->y > 480*FPSCALE || s->y < 10*FPSCALE
  || --s->path_count < 0)
  {
    s->state = S_NONE;
    c2.Sprite[s->sprite]->y = OFF_SCREEN; // off-screen, invisible
    return;
  }
  object_angular_move(s);
}

// bomb starting from x,y, fly at angle a
void bomb_create(int x, int y, uint8_t a)
{
  struct starship *s;
  s = find_free();
  if(s == NULL)
    return;
  s->x = x;
  s->y = y;
  s->a = a;
  s->v = SPEED*FPSCALE*5/4;
  s->state = S_BOMB;
  s->shape = SH_BLOCK_WHITE;
  c2.sprite_link_content(s->shape, s->sprite);
  c2.Sprite[s->sprite]->x = s->x / FPSCALE - Scenter[s->shape].x;
  c2.Sprite[s->sprite]->y = s->y / FPSCALE - Scenter[s->shape].y;
}

void bomb_move(struct starship *s)
{
  if(s->x < 10*FPSCALE || s->x > 640*FPSCALE || s->y > 480*FPSCALE || s->y < 10*FPSCALE)
  {
    s->state = S_NONE;
    c2.Sprite[s->sprite]->y = OFF_SCREEN; // off-screen, invisible
    return;
  }
  object_angular_move(s);
}

// missile starting from x,y
void missile_create(int x, int y)
{
  struct starship *s;
  s = find_free();
  if(s == NULL)
    return;
  s->x = x;
  s->y = y;
  s->a = 64; // fly up
  s->v = 3*SPEED*FPSCALE;
  s->state = S_MISSILE;
  s->shape = SH_MISSILE0 + Missile_wiggle;
  c2.sprite_link_content(s->shape, s->sprite);
  c2.Sprite[s->sprite]->x = s->x / FPSCALE - Scenter[s->shape].x;
  c2.Sprite[s->sprite]->y = s->y / FPSCALE - Scenter[s->shape].y;
}

// alien collision
// returns non-null pointer 
// to the alien which is hit by the missile s
struct starship *alien_hit(struct starship *s)
{
  uint32_t i;
  struct starship *as;
  int xr = 8*FPSCALE, yr = 12*FPSCALE; // collision range
  for(i = 0; i < SHIPS_MAX; i++)
  {
    as = &(Starship[i]);
    // is this ship alien alive?
    if(as->state >= S_ALIEN_CONVOY && as->state <= S_ALIEN_ATTACK)
    {
      if(as->x - xr < s->x && as->x + xr > s->x
      && as->y - yr < s->y && as->y + yr > s->y)
        return as;
    }
  }
  return NULL; // no alien is hit
}

void kill_alien(struct starship *ah)
{
  if(ah != NULL)
  {
    int alien_type = ah->shape / 4;
    if(alien_type >= 3)
    {
      ah->shape -= 4; // change from big alien type 3 to type 2
      c2.sprite_link_content(ah->shape, ah->sprite);
    }
    else
    {
      ah->state = S_NONE;
      c2.Sprite[ah->sprite]->y = OFF_SCREEN; // alien off-screen, invisible
      if(Alien_count > 0)
        Alien_count--;
    }
    fireball_create(ah->x, ah->y, alien_type == 0 ? SH_FIREBALLB0 : SH_FIREBALLY0);
    explosion_create(ah->x, ah->y, alien_type, 64);
    Alien_friendly = 0;
  }
}

void missile_move(struct starship *s)
{
  struct starship *ah = alien_hit(s);
  if(ah != NULL)
  {
    if(ah->shape == SH_ALIEN5D) // alien hit have suckered ship on the back
    {
      if(Ship.n == 1) // if currently there's single fighter ship
      {
        Ship.n = 2; // double fighter ship
        Fighter->shape = SH_SHIP2; // double ship shape
        c2.sprite_link_content(Fighter->shape, Fighter->sprite);
        s->shape = SH_ALIEN5D; // reshape the alien into big one with suckered ship on the back
        c2.sprite_link_content(s->shape, s->sprite);
      }
    }
    kill_alien(ah);
  }
  if(s->x < 10*FPSCALE || s->x > 640*FPSCALE || s->y > 480*FPSCALE || s->y < 10*FPSCALE || ah != NULL)
  {
    s->state = S_NONE;
    c2.Sprite[s->sprite]->y = OFF_SCREEN; // off-screen, invisible
    return;
  }
  s->shape = SH_MISSILE0 + Missile_wiggle;
  c2.sprite_link_content(s->shape, s->sprite);
  object_angular_move(s);
}

void suction_create(struct starship *ship, int x, int y)
{
  int i;
  struct starship *s; // suction bar
  for(i = 0; i < 6; i++)
  {
    s = find_free();
    if(s == NULL)
      return;
    s->x = x;
    s->y = y + i*SUCTION_DISTANCE*FPSCALE;
    s->a = 64; // move up
    s->v = FPSCALE; // one frame at a time
    s->shape = SH_ALIEN_SUCTION1 + i;
    s->path_state = 0; // y-reset
    s->path_count = (512 - i*SPEED*SUCTION_DISTANCE/4)/SPEED; // suction time
    s->state = S_SUCTION_BAR;
    s->parent = ship; // the alien ship who created this suction bar
    c2.sprite_link_content(s->shape, s->sprite); // the suction bar
  }
  // suctiion tracker
  Suction.x = ship->x;
  Suction.y = ship->y;
  Suction.countdown = ship->path_count;
}

// tracks (countdowns) suction time for easier search
void suction_tracker(void)
{
  if(Suction.countdown > 0)
  {
    Suction.countdown--;
  }
}

void suction_move(struct starship *s)
{
  if(s->x < 10*FPSCALE || s->x > 640*FPSCALE || s->y > 480*FPSCALE || s->y < 10*FPSCALE
  || --s->path_count < 0
  || (Ship.suction == 50) // this will immediately terminate suction bars when ship is taken
  )
  {
    s->state = S_NONE;
    c2.Sprite[s->sprite]->y = OFF_SCREEN; // off-screen, invisible
    return;
  }
  if( ++s->path_state >= SUCTION_DISTANCE)
  {
    s->y += SUCTION_DISTANCE*FPSCALE; // reset y-position of the suction bar
    s->path_state = 0;
  }
  object_angular_move(s);
}

// calculate next frame x y for the starship
// reshape=0 -> do not change shape on direction change
void alien_convoy(struct starship *s)
{
  struct path_segment *path;
  path = Path_types[s->path_type].path;
  int reshape = Path_types[s->path_type].orientation;
  s->v = path[s->path_state].v;
  if( s->path_count > 0 )
  {
    s->path_count--;
    if(reshape != 0)
    {
      s->shape = (s->shape & ~3) | (((s->a+32)/64) & 3);
      c2.sprite_link_content(s->shape, s->sprite);
    }
    object_angular_move(s);
    s->a += path[s->path_state].r; // rotate
  }
  else
  {
    if( path[s->path_state+1].n > 0 )
    {
      s->path_state++;
      s->path_count = path[s->path_state].n;
      if(s->path_type == PT_ALIEN_SUCTION)
      {
        if(path[s->path_state].v == 0) // alien stops to suck
        {
          int alien_type = s->shape / 4;
          if(alien_type == 3) // is it still alien type 3? (haven't been hit in meantime)
          {
            suction_create(s, s->x, s->y + 20 * FPSCALE); // yes, suck
          }
          else
          { // no type 3 alien, skip suction state
            if( path[s->path_state+1].n > 0 )
            {
              s->path_state++;
              s->path_count = path[s->path_state].n;
            }
          }
        }
      }
      s->a = path[s->path_state].a;
      if(reshape != 0)
      {
        s->shape = (s->shape & ~3) | (((s->a+32)/64) & 3);
        c2.sprite_link_content(s->shape, s->sprite);
      }
      object_angular_move(s);
      s->a += path[s->path_state].r; // rotate
    }
    else
    {
      s->state = S_ALIEN_HOMING;
    }
  }
}

void alien_prepare(struct starship *s)
{
  if(s->prepare > 0)
    s->prepare--;
  else
    s->state = S_ALIEN_CONVOY;
}

void alien_homing(struct starship *s)
{
  int dir = 192; // default orient down
  int xd, yd;
  xd = Fleet.x + s->hx - s->x;
  yd = Fleet.y + s->hy - s->y;
  if(xd > SPEED * FPSCALE)
  {
    xd = SPEED * FPSCALE;
    dir = 0; // right
  }
  else
  {
    if(xd < -(SPEED * FPSCALE))
    {
      xd = -(SPEED * FPSCALE);
      dir = 2; // left
    }
  }

  if(yd < -(SPEED * FPSCALE))
  {
    yd = -(SPEED * FPSCALE);
    dir = 1; // up
  }
  else
  {
    if(yd > SPEED * FPSCALE)
    {
      yd = SPEED * FPSCALE;
      dir = 3; // down
    }
  }
  s->x += xd;
  s->y += yd;
  if(abs(xd) < 2*SPEED*FPSCALE/FLEET_DRIFT && abs(yd) < 2*SPEED*FPSCALE/FLEET_DRIFT)
  // if( xd == 0 && yd == 0 )
  {
    s->state = S_ALIEN_HOME;
    s->x = Fleet.x + s->hx;
    s->y = Fleet.y + s->hy;
    dir = 3; // down
  }
  s->a = dir * 64; // orientation of the alien
  s->shape = (s->shape & ~3) | (dir & 3);
  c2.sprite_link_content(s->shape, s->sprite); // orient alien down
  c2.Sprite[s->sprite]->x = s->x / FPSCALE - Scenter[s->shape].x;
  c2.Sprite[s->sprite]->y = s->y / FPSCALE - Scenter[s->shape].y;
}

// calculate bomb angle from alien starship to the player's ship 
// possible angles are within 45 degrees
// if ship is out of shooting range - return 0
uint8_t aim_bomb_angle(struct starship *s)
{
  int rev = 1;
  int dx, dy;
  uint8_t a;
  // int xadjust = 4*FPSCALE, yadjust = 10*FPSCALE; // x,y-adjustment for uncentered sprites
  int xadjust = 0, yadjust = 0;
  int tangent; // tangent value
  // if ship is above alien, can't shoot
  if(Ship.y < s->y)
    return 0;
  dx = Ship.x + xadjust - s->x;
  dy = Ship.y + yadjust - s->y;
  // if ship is left, convert to the right
  if(dx < 0)
  {
    dx = -dx;
    rev = -1;
  }
  // both dx and dy should be positive now
  // angles > 45 are out of reach
  if(dx >= dy)
    return 0;
  // avoid eventual division by zero
  if(dy == 0)
    return 0;
  // calculate angle (arc-tan)
  tangent = (dx*FPSCALE)/dy;
  // sanity check
  if(tangent < 0 || tangent >= FPSCALE)
    return 0;
  a = iatan[tangent];
  // reverse sign
  if(rev > 0)
    return 192 + a;
  else
    return 192 - a;
}

// fly the ship in the fleet
void alien_fleet(struct starship *s)
{
  uint16_t rng;
  uint8_t a;

  s->x = Fleet.x + s->hx;
  s->y = Fleet.y + s->hy;

  c2.Sprite[s->sprite]->x = (Fleet.x + s->hx) / FPSCALE - Scenter[s->shape].x;
  c2.Sprite[s->sprite]->y = (Fleet.y + s->hy) / FPSCALE - Scenter[s->shape].y;

  if(Alien_friendly == 0 && Hold_fire == 0)
  {
    rng = rand();

    if(rng < 1000)
    {
      if(s->prepare > 0)
        s->prepare--;
      else
      {
        a = aim_bomb_angle(s);
        if(a != 0)
        {
          s->prepare = ALIEN_BOMB_RELOAD;
          bomb_create(s->x, s->y, a);
          Hold_fire = Hold_fire_delay;
        }
      }
    }
  }
}

// select a group of alien ships in the fleet
// that will perform an attack, all flying
// the same path
void fleet_select_attack()
{
  uint32_t rng = rand();
  int group;
  uint32_t i;
  if(rng < 200000000)
  {
    group = 1 + (rng % 10); // select which group will attack
    // todo: if no ships are in this group in the fleet,
    // choose next group
    // search for all ships, find those which are members of
    // selected group and are in FLEET HOME state
    for(i = 0; i < SHIPS_MAX; i++)
    {
      // fixme convoy[i] no longer descibes ship's group membership
      if(Starship[i].state == S_ALIEN_HOME && Starship[i].group == group)
      {
        // found the candidate for the group attack
        struct starship *s = &(Starship[i]);
        struct path_segment *path;
        s->path_type = 5+((rng / 256) % 8); // 5 is attack path
        // s->path_type = PT_ALIEN_SUCTION; // force alien suction (debugging)
        int alien_type = s->shape / 4;
        if(s->path_type == PT_ALIEN_SUCTION && alien_type != 3) // only big alien type 3 can suck
          s->path_type = 11; // not big alien, don't suck
        path = Path_types[s->path_type].path;
        s->state = S_ALIEN_ATTACK;
        s->path_state = 0; // 0 resets path to the first segment of the path
        s->path_count = path[0].n; // contdown of the path segment
        s->a = path[0].a; // initial angle
      }
    }
  }
}

void fleet_move()
{
  if(Fleet.x <= Fleet.xmin)
    Fleet.xd = (FPSCALE*SPEED/FLEET_DRIFT);

  if( Fleet.x >= Fleet.xmax)
    Fleet.xd = -(FPSCALE*SPEED/FLEET_DRIFT);

  Fleet.x += Fleet.xd;
}

// attack flight path steering of the alien ship
void alien_attack(struct starship *s)
{
  uint16_t rng = rand();
  uint8_t a;

  if(rng < 7000)
  {
    if(s->prepare > 0)
      s->prepare--;
    else
    {
      a = aim_bomb_angle(s);
      if(a != 0)
      {
        s->prepare = ALIEN_BOMB_RELOAD;
        bomb_create(s->x, s->y, a);
      }
    }
  }

  s->v = SPEED*FPSCALE;
  if(s->y < 480*FPSCALE)
  {
    alien_convoy(s);  
  }
  else
  {
    s->y = 0; // jump to top of the screen
    s->a = 192; // angle down
    object_angular_move(s); // initial move
    s->shape = (s->shape & ~3) | (((s->a+32)/64) & 3);
    c2.sprite_link_content(s->shape, s->sprite);
    s->state = S_ALIEN_HOMING;
  }
}

// ship at x,y
void ship_create(int x, int y)
{
  struct starship *s;
  s = find_free();
  if(s == NULL)
    return;
  Fighter = s; // update direct pointer to player's ship
  s->x = x;
  s->y = y;
  s->a = 64; // fly up
  s->v = 0;
  s->prepare = 0;
  s->state = S_SHIP;
  Ship.x = x;
  Ship.y = y;
  #if 1
  // start with single ship
  Ship.n = 1;
  s->shape = SH_SHIP1U;
  #else
  // start with double ship
  Ship.n = 2;
  s->shape = SH_SHIP2;
  #endif
  c2.sprite_link_content(s->shape, s->sprite);
  c2.Sprite[s->sprite]->x = s->x / FPSCALE - Scenter[s->shape].x;
  c2.Sprite[s->sprite]->y = s->y / FPSCALE - Scenter[s->shape].y;
}

// detect collision and
// search for possible alien above (aiming to aliens)
//  0 nothing
// -1 alien in the x-shooting range
//  1 ship hit by alien or bomb
//  2 ship sucked by the alien
int ship_aim_hit(struct starship *s, struct starship **alien)
{
  uint32_t i;
  struct starship *as;
  int xs = 32*FPSCALE; // shooting range
  int xr = 12*FPSCALE, yr = 12*FPSCALE; // collision range
  int retval = 0;
  for(i = 0; i < SHIPS_MAX; i++)
  {
    as = &(Starship[i]);
    // is the alien or bomb near enough to destroy the ship?
    if((as->state >= S_ALIEN_CONVOY && as->state <= S_ALIEN_ATTACK)
    || (as->state == S_BOMB)
    || (as->state == S_SUCTION_BAR)
    )
    {
      if(as->x - xr < s->x && as->x + xr > s->x
      && as->y - yr < s->y && as->y + yr > s->y)
      {
        if(alien != NULL)
          *alien = as;
        if(as->state == S_SUCTION_BAR)
          return 2; // suction bar is near - ship should be suckered
        return 1; // alien or bomb near, ship should explode
      }
    }
    // is the alien above? (non-sucking one)
    if(as->state >= S_ALIEN_CONVOY && as->state <= S_ALIEN_ATTACK && as->path_state != PT_ALIEN_SUCTION)
    {
      if(as->x - xs < s->x && as->x + xs > s->x)
        retval = -1; // alien found above, ship should shoot
    }
  }
  return retval;
}

void ship_move(struct starship *s)
{
  uint32_t rng = rand();
  uint32_t shooting_freq = SHIP_SHOOTING_FREQ_SLOW;
  static int xdir = SPEED*FPSCALE/2; // x-direction that ship moves
  struct starship *object_collided;
  static int immunity = 0; // can't be destroyed
  int collision = ship_aim_hit(s, &object_collided);
  static int disappeared = 0;
  if(disappeared > 0)
  {
    disappeared--;
    if(disappeared == 0) // reappear
      c2.Sprite[s->sprite]->y = s->y / FPSCALE - Scenter[s->shape].y;
    return;
  }
  if(Ship.suction > 0)
  {
    int up_to_suction_level = 0;
    if(Ship.sucker != NULL)
    {
      if(s->y < Ship.sucker->y)
        up_to_suction_level = 1;
    }
    // ship goes up and joins the sucker alien
    // after joining: if there's another ship available
    // it should enter the game
    Ship.suction--;
    if(Ship.suction > 0 && up_to_suction_level == 0)
    { // move up
      s->y -= SPEED*FPSCALE/4; // move up at suction speed
      c2.Sprite[s->sprite]->y = s->y / FPSCALE - Scenter[s->shape].y;
      immunity = 200;
      Hold_fire = Hold_fire_new_ship;
      return;
    }
    else
    { // inform the sucker to proceed with taking the ship
      if(Ship.sucker != NULL && up_to_suction_level == 1) // sanity check
      {
        struct path_segment *path;
        path = Path_types[Ship.sucker->path_type].path;
        if( path[Ship.sucker->path_state+1].n > 0 )
        {
          Ship.sucker->path_state++;
          Ship.sucker->path_count = path[Ship.sucker->path_state].n;
          Ship.sucker->shape = SH_ALIEN5D; // reshape the alien into big one with suckered ship on the back
          c2.sprite_link_content(Ship.sucker->shape, Ship.sucker->sprite);
        }
      }
      // create new ship (if available) at old position
      s->y = Ship.y;
      c2.Sprite[s->sprite]->y = s->y / FPSCALE - Scenter[s->shape].y;
      immunity = 200;
      Hold_fire = Hold_fire_new_ship;
      return;
    }
  }
  if(immunity > 0)
    immunity--;
  if(collision == 1 && Ship.suction == 0 && immunity == 0) // fatal hit
  {
    if(object_collided)
    {
      if(object_collided->state >= S_ALIEN_CONVOY && object_collided->state <= S_ALIEN_ATTACK)
        kill_alien(object_collided);
      // if it was not alien but just a bomb, silently remove it
      // so the ship will not continously keep exploding
      if(object_collided->state == S_BOMB)
      {
        object_collided->state = S_NONE;
        c2.Sprite[object_collided->sprite]->y = OFF_SCREEN;
      }
    }
    if(Ship.n == 2) // ship hit: double ship will turn into single ship
    {
      Ship.n = 1;
      s->shape = SH_SHIP1U;
      c2.sprite_link_content(s->shape, s->sprite);   
    }
    else
    {
      disappeared = 50; // ship will disappear for some time
      // TODO: delete all missiles
      c2.Sprite[s->sprite]->y = s->y / FPSCALE - Scenter[s->shape].y + 100; // invisible
      Alien_friendly = 1;
    }
    fireball_create(s->x, s->y, SH_FIREBALLY0);
    explosion_create(s->x, s->y, 5, 16); // explosion color type 5 (player ship)
    return;
  }
  if(collision == 2 && immunity == 0) // enter suction state
  {
    Ship.suction = 100; // counter for the ship to move up
    Ship.sucker = NULL;
    if(object_collided->state == S_SUCTION_BAR && object_collided->parent != NULL)
    {
      if(object_collided->parent->path_type == PT_ALIEN_SUCTION)
        Ship.sucker = object_collided->parent; // the alien that sucks this ship
    }
    return;
  }
  if(Alien_friendly == 0)
    shooting_freq = SHIP_SHOOTING_FREQ_FAST;
  if(s->prepare > 0)
    s->prepare--;
  else
  {
    if((rng < shooting_freq && game_demo > 0 && collision == -1) // alien in the shooting range
    || (digitalRead(BTN_F)==BTN_PRESSED && game_demo <= 0) )
    {
      s->prepare = SHIP_MISSILE_RELOAD;
      if(Ship.n == 1) // single ship single shots
        missile_create(Ship.x, Ship.y);
      if(Ship.n == 2) // double ship double shots
      {
        missile_create(Ship.x - 6*FPSCALE, Ship.y);
        missile_create(Ship.x + 6*FPSCALE, Ship.y);
      }
    }
  }
  if(game_demo > 0)
  {
  if((s->x > 600*FPSCALE || s->x > Fleet.x + 240*FPSCALE) && xdir > 0)
    xdir = -SPEED*FPSCALE/2;
  if((s->x < 100*FPSCALE || s->x < Fleet.x + 0*FPSCALE)  && xdir < 0)
    xdir =  SPEED*FPSCALE/2;
  }
  else
  {
    xdir = 0;
    if(s->x > 100*FPSCALE && digitalRead(BTN_L) == BTN_PRESSED)
      xdir = -SPEED*FPSCALE/2;
    if(s->x < 600*FPSCALE && digitalRead(BTN_R) == BTN_PRESSED)
      xdir = SPEED*FPSCALE/2;
  }
  s->x += xdir;
  Ship.x = s->x; // publish ship's new x coordinate (y stays the same)
  Ship.y = s->y;
  c2.Sprite[s->sprite]->x = s->x / FPSCALE - Scenter[s->shape].x;
  c2.Sprite[s->sprite]->y = s->y / FPSCALE - Scenter[s->shape].y; // visible
}

void nothing_move(struct starship *s)
{
  return;
}

void (*jumptable_move[])(struct starship *) =
{
  [S_NONE] = nothing_move,
  [S_ALIEN_PREPARE] = alien_prepare,
  [S_ALIEN_CONVOY] = alien_convoy,
  [S_ALIEN_HOMING] = alien_homing,
  [S_ALIEN_HOME] = alien_fleet,
  [S_ALIEN_ATTACK] = alien_attack,
  [S_SUCTION_BAR] = suction_move,
  [S_BOMB] = bomb_move,
  [S_MISSILE] = missile_move,
  [S_EXPLOSION] = explosion_move,
  [S_SHIP] = ship_move,
  [S_FIREBALL] = fireball_move,
};

void setup()
{
  int i;
  c2.init();
  // after c2.init() disables video burst
  // wait 3 video blanks for video burst
  // to completely stop before
  // creating sprite linked list
  // active video burst may disturb CPU
  // c2 linked list may be created wrong
  for(i = 0; i < 3; i++)
  {
    while((*c2.vblank_reg & 0x80) == 0);
    while((*c2.vblank_reg & 0x80) != 0);
  }
  c2.alloc_sprites(SPRITE_MAX);
  create_sine_table();
  create_atan_table();
  allocate_ships();

  pinMode(BTN_L, INPUT);
  pinMode(BTN_R, INPUT);
  pinMode(BTN_F, INPUT);
  #if 1
    // ORIGINAL SHAPE SPRITES
    // first number of sprites will be used only to carry
    // original shapes. They will not be displayed
    for(i = 0; i < c2.sprite_max && i < (int)N_SHAPES; i++)
      c2.shape_to_sprite(&Shape[i]);
    // CLONED SHAPE SPRITES
    // rest of the sprites can be displayed they
    // contain cloned shapes from original shape sprites
    for(i = c2.n_sprites; i < c2.sprite_max; i++)
      c2.sprite_clone(SH_PLACEHOLDER); // shape is big enough to allow reshaping with smaller ones
    for(i = 0; i < c2.n_sprites; i++)
    {
      c2.Sprite[i]->x = 0 + 32*(i&3);
      #if SHOWCASE_SPRITES
      c2.Sprite[i]->y = 0 + 12*i;
      #else
      c2.Sprite[i]->y = OFF_SCREEN; // off screen (invisible)
      #endif
    }
  #endif

  // create the ship, just to display something
  ship_create(Ship.x, Ship.y);

  // suction_create(320*FPSCALE,200*FPSCALE);

  // experimental bomb
  // bomb_create(300*FPSCALE,50*FPSCALE,191);

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
  uint32_t i;

  if(Alien_count <= 0)
    create_aliens();
  fleet_move();
  Missile_wiggle = (Missile_wiggle + 1) & 3;
  if(Alien_friendly == 0)
    fleet_select_attack();
  for(i = 0; i < SHIPS_MAX; i++)
  {
    struct starship *s = &(Starship[i]);
    jumptable_move[s->state](s);
  }
  suction_tracker();

  if(Hold_fire > 0)
    Hold_fire--;
  while((*c2.vblank_reg & 0x80) == 0);
  #if SHOWCASE_SPRITES
  c2.sprite_refresh(); // display all sprites, originals and clones
  #else
  c2.sprite_refresh(N_SHAPES); // display only clones (faster)
  #endif
  while((*c2.vblank_reg & 0x80) != 0);
  //delay(400);
  static uint8_t r;
  r++;
  //if(r == 0)
  //  Serial.println(Alien_count);
}

void main(void)
{
  setup();
  while(1)
    loop();
}
