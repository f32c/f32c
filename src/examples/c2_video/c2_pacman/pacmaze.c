// source from https://gtoal.com/src/pacman-maze-generators/
#include <stdio.h>

extern long int random(void);
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

static int next_tile = 0, first_tile, last_tile, dead_block;

unsigned int tile[] = {
    142, 3208, 1100, 226, 46, 3140, 2188, 232, 79, 35976, 19524, 242,
    47, 19524, 35016, 244, 1252, 1252, 78, 2248, 1220, 228, 140, 200,
    196, 76, 14, 2184, 12, 136, 204,
};

long tetris[WIDTH][HEIGHT+TILE_DIMENSION+1]; // 0,0 at bottom left, 8,19 at top right

void place_tile(int tileno, int r, int c)
{
  int row, col, t = tile[tileno], nibble, bit;
  next_tile++;
  for (row = 0; row < 4; row++) {
    nibble = t&15; t >>= 4;
    for (col = 0; col < 4; col++) {
      bit = nibble&8; nibble <<= 1;
      if (bit) tetris[col+c][row+r] = next_tile;
    }
  }
}

int can_place(int tileno, int r, int c)
{
  int row, col, t = tile[tileno], nibble, bit;
  for (row = 0; row < 4; row++) {
    nibble = t&15; t >>= 4;
    for (col = 0; col < 4; col++) {
      bit = nibble&8; nibble <<= 1;
      if ((bit && tetris[col+c][row+r] != 0) || (bit && ((row+r) > (HEIGHT-1)))) {
        return FALSE;
      }
      if (bit && ((c+col) > WIDTH-1)) {
        return FALSE;
      }
    }
  }
  return TRUE;
}

#ifdef DEBUG
static char t[]="0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz~!@#$%^&*()_+`-={}|[]\\:\";'<>,./";
#endif
void debug(void) {
#ifdef DEBUG
  int i, j;
  for (i = HEIGHT-1; i >= 0; i--) {
    for (j = 0; j < WIDTH; j++) {
      putchar(t[tetris[j][i]]);
    }
    putchar('\n');
  }
  putchar('\n');
#endif
}

void drop(int tileno, int r, int c)
{
  if (can_place(tileno, r, c) && (r==0 || !can_place(tileno, r-1, c))) {
    place_tile(tileno, r, c);
  } else {
    if (r>0) drop(tileno, r-1, c);
  }
}

int ran(int low, int high) {
  return low + random()%(high-low+1);
}

void play_tetris(void) {
  int i, j;
  next_tile = 0; // used by 'place_tile' called from 'drop'
  for (i = 0; i < WIDTH; i++) {
    for (j = 0; j < HEIGHT+TILE_DIMENSION+1; j++) {
      tetris[i][j] = 0;
    }
  }
  drop(30, HEIGHT+1, WIDTH/2); // jail.  Should also handle tunnels here.
  for (i = 0; i < 1000; i++) {
    drop(ran(first_tile, last_tile-1), HEIGHT, ran(0,WIDTH-1));
  }
}

#define PACWIDTH (HEIGHT*2+1)
#define PACHEIGHT (WIDTH+2)

static int maze[PACWIDTH+TILE_DIMENSION][PACHEIGHT+TILE_DIMENSION];

static int this_row, this_len; // remember to ensure a blank line at top and bottom for tombstones

char line[PACHEIGHT*2+1][PACWIDTH*6+1]; // slop is to allow for stretched image

void add(int this, int next) {
  line[this_row][this_len++]= this;
  line[this_row][this_len++]= next;
  line[this_row][this_len]= '\0';
}


void init_row(void) {
  this_row = -1;
  this_len = 0;
}

void next_row(void) {
  this_row++;
  line[this_row][0] = ' ';
  line[this_row][1] = '\0';
  this_len = 1;
}

void convert_to_maze(void) {
  int i, j, row, col;
  row = 1;
  for (j = 0; j < WIDTH; j++) {
    col = 1;
    for (i = HEIGHT-1; i >= 0; i--) {
      maze[col][row] = tetris[j][i]; if (maze[col][row] == 0) maze[col][row] = dead_block;
      col++;
    }
    for (i = 1; i < HEIGHT; i++) {
      maze[col][row] = tetris[j][i]; if (maze[col][row] == 0) maze[col][row] = dead_block;
      col++;
    }
    row++;
  }
}

void debug_maze(void) {
#ifdef DEBUG
  int i, j;
  for (i = PACHEIGHT-2; i > 0; i--) {
    for (j = 1; j < PACWIDTH-1; j++) {
      putchar(t[maze[j][i]]);
    }
    putchar('\n');
  }
  putchar('\n');
#endif
}

void cell(int above_below, int i, int j) {
  // This is messy but I don't have the time to work it out properly and
  // do a neater implementation.  Sorry.  There's a minor bug that is
  // worked around by 'trim_junk()'
  if (above_below < 0) {
    if ((i+1 == PACWIDTH) && (j+1 == PACHEIGHT)) add('#', ' '); else {
      if (maze[i][j-1] != maze[i][j]) {
        if ((maze[i][j-1] == 0) && (maze[i][j] == dead_block)) {
          if ((maze[i][j] == dead_block) && (maze[i-1][j] == 0)) {
            add(' ', ' ');
          } else {
            add('#', ' ');
          }
        } else {
          if ((maze[i][j] == 0) && (maze[i][j-1] == dead_block)) {
            if ((maze[i-1][j-1] == dead_block) || (maze[i][j-1] == 0)) {
              add(' ', ' ');
            } else {
              if ((maze[i-1][j-1] == 0) && (maze[i-1][j] == 0)) {
                add(' ', ' ');
              } else {
                add('#', ' ');
	      }
	    }
 	  } else {
            add('#', '#');
	  }
	}
      } else {
        if ((maze[i-1][j] != maze[i][j])) {
          if ((maze[i][j] == dead_block) && (maze[i-1][j] == 0)) {
            add(' ', ' ');
          } else {
            add('#', ' ');
          }
        } else {
          if ((maze[i][j] == maze[i][j-1]) && (maze[i-1][j-1] != maze[i][j])) {
            add('#', ' ');
	  } else {
            add(' ', ' ');
	  }
	}
      }
    }
  } else if (above_below == 0) {
    if ((maze[i-1][j] != maze[i][j])) {
      if ((maze[i][j] == dead_block) && (maze[i-1][j] == 0)) {
        add(' ', ' '); 
      } else {
        add('#', ' '); 
      }
    } else add(' ', ' ');
  }
}

void symmetry(int i, char *s) {
  char *left, *right;
  int len = MIDDLE;
  left = right = s+len;
  while (len-- >= 0) *right++ = *left--;
  *right = '\0';
}

void gen_text_maze(void) {
  int i, j, k;
  init_row();
  for (i = PACHEIGHT-1; i > 0; i--) {
    for (k = 0; k >= -1; k--) {
      next_row();
      for (j = 1; j < PACWIDTH; j++) {
        cell(k,j,i);
      }
    }
  }
  for (i = 0; i < TARGET_WIDTH+1; i++) line[TARGET_HEIGHT+1][i] = ' ';
  line[TARGET_HEIGHT+1][TARGET_WIDTH+1] = '\0';
  for (i = 0; i < PACHEIGHT*2/*-1*/; i++) {
    symmetry(i, line[i]);
  }
}

void trim_central_column(void) {
  int iterate, i;
  // Trim any central '#'s that don't connect above or below (OK if connecting to left and right)
  for (iterate = 0; iterate < PACHEIGHT*2-1; iterate++) {
    for (i = 1; i < PACHEIGHT*2-1; i++) {
      if (line[i][MIDDLE] == '#' && line[i][MIDDLE-1] != '#' && (line[i-1][MIDDLE] != '#' || line[i+1][MIDDLE] != '#')) {
        line[i][MIDDLE] = ' ';
      }
    }
  }
}

// made in EMARD
void trim_central_vertical_parallel(void) {
  int iterate, i;
  // Trim vertical central '#' that have parallel '#' to the left
  for (iterate = 0; iterate < PACHEIGHT*2-1; iterate++) {
    for (i = 1; i < PACHEIGHT*2-1; i++) {
      if (line[i][MIDDLE] == '#' && line[i][MIDDLE-1] != '#' && line[i][MIDDLE-2] == '#') {
        line[i][MIDDLE] = ' ';
      }
    }
  }
}

int too_narrow(void) {
  // Reject any that don't have >= 3 #'s on any row or col
  int i, j, paths = 0;
  for (i = 1; i < PACHEIGHT*2-1; i++) {
    for (j = 1; j <= TARGET_WIDTH; j++) {
      if (line[i][j] > ' ') paths += 1; // # or @ etc
    }
  }
  return(paths < 4);
}

int wide_path(void) {
  // Reject if there is a path all the way across
  int i, j, paths;
  for (i = 1; i <= TARGET_HEIGHT; i++) {
    paths = 0;
    for (j = 1; j <= TARGET_WIDTH; j++) {
      if (line[i][j] != ' ') paths += 1; // # or @ etc
    }
    if (paths == TARGET_WIDTH) return(TRUE);
  }

  for (j = 1; j <= TARGET_WIDTH; j++) {
    paths = 0;
    for (i = 1; i <= TARGET_HEIGHT; i++) {
      if (line[i][j] != ' ') paths += 1; // # or @ etc
    }
    if (paths == TARGET_HEIGHT) return(TRUE);
  }

  // Reject if too many paths joining left to right 
  paths = 0;
  for (i = 1; i < TARGET_HEIGHT; i++) {
    if (line[i][MIDDLE] != ' ' && line[i][MIDDLE-1] != ' ') paths += 1; // # or @ etc
  }
  if (paths > 5) return(TRUE);

  return(FALSE);
}

int small_loops(void) {
  // Reject squares (small loops):
  int i, j;
  for (i = 2; i < PACHEIGHT*2-2; i++) {
    for (j = 1; j <= TARGET_WIDTH; j++) {
      if (line[i][j] == ' ' &&
          line[i-1][j-1] == '#' &&
          line[i-1][j] == '#' &&
          line[i-1][j+1] == '#' &&
          line[i][j-1] == '#' &&
          line[i][j+1] == '#' &&
          line[i+1][j-1] == '#' &&
          line[i+1][j] == '#' &&
          line[i+1][j+1] == '#'
          ) return(TRUE);
    }
  }
  return(FALSE);
}

void trim_junk(void) {
  int i, j;
  for (i = 2; i < PACHEIGHT*2-2; i++) {
    for (j = 1; j <= TARGET_WIDTH; j++) {
      if (line[i][j] == '#' &&
          line[i-1][j-1] == ' ' &&
          line[i-1][j] == ' ' &&
          line[i-1][j+1] == ' ' &&
          line[i][j-1] == ' ' &&
          line[i][j+1] == ' ' &&
          line[i+1][j-1] == ' ' &&
          line[i+1][j] == ' ' &&
          line[i+1][j+1] == ' '
          ) line[i][j] = ' ';
    }
  }
}

int bad_spawn_point(void) {
  int i;

  // While we're at it, set up the jail exit
  for (i = (TARGET_HEIGHT/2); i > 0; i--) {
    if (line[i][MIDDLE] == '#') {
      line[i+1][MIDDLE] = 'V';
      if (line[i-1][MIDDLE] == '#') return(TRUE);
      break;
    }
  }

  // must spawn below jail
  for (i = (TARGET_HEIGHT/2)+4; i < (PACHEIGHT-1)*2; i++) {
    if (line[i][MIDDLE] == '#') {
      line[i][MIDDLE] = '@';
      if (line[i-1][MIDDLE] == '#') return TRUE;
      if (line[i+1][MIDDLE] == '#') return TRUE;
      break;
    }
  }

  // don't spawn on bottom line
  for (i = i+1; i < (PACHEIGHT-1)*2; i++) {
    if (line[i][MIDDLE] == '#') return(FALSE);
  }

  return(TRUE);
}

void draw_maze(void) {
  int i, j, c;
  printf("       1234567890123456789012345\n");
  for (i = 0; i < PACHEIGHT*2-1; i++) {
    printf("%03d: |%s|   ", i, line[i]);
    for (j = 0; j <= TARGET_WIDTH; j++) {
      if ((j == TARGET_WIDTH/2) || (j == (TARGET_WIDTH/2)+2)) {
        //putchar('.'); putchar('.'); -- unfortunately fixing the wide middle sometimes
	//                               leaves a vertical path down the centerline... - needs tweaking...
      } else {
        c = line[i][j];
        putchar(c);
        if (c == ' ') putchar(c); else putchar((line[i][j+1] == ' ' ? ' ' : '#')); // hack for spawn point
      }
    }
    putchar('\n');
  }
  putchar('\n');
}

void generate_maze(void)
{
  first_tile = 0; last_tile = sizeof(tile)/sizeof(tile[0])-1; dead_block = last_tile+1;

  // Generating is cheap so we can afford to generate and reject
  for (;;) {

    play_tetris();
    debug();
    convert_to_maze();
    debug_maze();
    gen_text_maze();
    trim_junk();
    trim_central_column();
    trim_central_vertical_parallel(); // made in EMARD

    // Reject any completed mazes that have problems
    if (too_narrow()) continue;
    if (small_loops()) continue; // often rejects
    if (wide_path()) continue;
    if (bad_spawn_point()) continue;

    break;
  }
}

void main(void)
{
  int i;
  for(i = 0; i < 4; i++) // simple seed sets random to quickly make its first maze
    random();
  for(;;)
  {
    generate_maze();
    draw_maze(); // print on stdout
  }
}
