/*************************************************** 
  This is a Pong port for the Arduino. The application 
  uses an Arduino Uno, Adafruit’s 128x64 OLED display, 
  2 potentiometers and an piezo buzzer.

  More info about this project can be found on my blog:
  http://michaelteeuw.nl

  Written by Michael Teeuw | Xonay Labs.  
  Apache 2 license, all text above must be included 
  in any redistribution.
  Self-play mode by RADIONA
 ****************************************************/

extern "C"
{
#include <stdlib.h>
}

#include "Compositing/Compositing.h"
#define SPRITE_MAX 10
Compositing c2;
//                            RRGGBB
#define C2_WHITE  RGB2PIXEL(0xFFFFFF)
#define C2_GREEN  RGB2PIXEL(0x00FF00)
#define C2_ORANGE RGB2PIXEL(0xFF7F00)
#define C2_BLUE   RGB2PIXEL(0x4080FF)

//Define Pins
#define BEEPER     33

#define HAVE_ANALOG 0
#if HAVE_ANALOG
#define CONTROL_A A0
#define CONTROL_B A1
#endif

#define HAVE_TONE 0

//Define Visuals
#define FONT_SIZE 4
#define SCREEN_WIDTH VGA_X_MAX // 640
#define SCREEN_HEIGHT VGA_Y_MAX // 480
#define PADDLE_WIDTH 8
#define PADDLE_HEIGHT 32
#define PADDLE_PADDING 16
#define BALL_SIZE 8
#define SCORE_PADDING 10

#define EFFECT_SPEED 1
#define MIN_Y_SPEED 1
#define MAX_Y_SPEED 3

#define X_BOUNCE_DISTANCE (SCREEN_WIDTH-2*PADDLE_PADDING-2*PADDLE_WIDTH-1*BALL_SIZE)
#define Y_BOUNCE_DISTANCE (SCREEN_HEIGHT-1*BALL_SIZE)

//Define Variables

int paddleLocationA = 0;
int paddleLocationB = 0;

int ballX = SCREEN_WIDTH/2;
int ballY = SCREEN_HEIGHT/2;
int ballSpeedX = 8;
int ballSpeedY = 8;

int lastPaddleLocationA = 0;
int lastPaddleLocationB = 0;

/* self-play mode ball Y position prediction
** there we should place the paddle
*/
int expectAY = 0;
int expectBY = 0;

int scoreA = 0;
int scoreB = 0;

void soundStart() 
{
  #if HAVE_TONE
  tone(BEEPER, 250);
  delay(100);
  tone(BEEPER, 500);
  delay(100);
  tone(BEEPER, 1000);
  delay(100);
  noTone(BEEPER);
  #endif
}

void soundBounce() 
{
  #if HAVE_TONE
  tone(BEEPER, 500, 50);
  #endif
}

void soundPoint() 
{
  #if HAVE_TONE
  tone(BEEPER, 150, 150);
  #endif
}

void addEffect(int paddleSpeed)
{
  int oldBallSpeedY = ballSpeedY;

  //add effect to ball when paddle is moving while bouncing.
  //for every pixel of paddle movement, add or substact EFFECT_SPEED to ballspeed.
  for (int effect = 0; effect < abs(paddleSpeed); effect++) {
    if (paddleSpeed > 0) {
      ballSpeedY += EFFECT_SPEED;
    } else {
      ballSpeedY -= EFFECT_SPEED;
    }
  }

  //limit to minimum speed
  if (ballSpeedY < MIN_Y_SPEED && ballSpeedY > -MIN_Y_SPEED) {
    if (ballSpeedY > 0) ballSpeedY = MIN_Y_SPEED;
    if (ballSpeedY < 0) ballSpeedY = -MIN_Y_SPEED;
    if (ballSpeedY == 0) ballSpeedY = oldBallSpeedY;
  }

  //limit to maximum speed
  if (ballSpeedY > MAX_Y_SPEED) ballSpeedY = MAX_Y_SPEED;
  if (ballSpeedY < -MAX_Y_SPEED) ballSpeedY = -MAX_Y_SPEED;
}

int expect_y(int x_distance)
{
  int normalY; // normalized Y position
  // as if ball is always traveling positive
  int absSpeedX, absSpeedY;
  int expectY;
  int expect2Y;

  absSpeedX = ballSpeedX > 0 ? ballSpeedX : -ballSpeedX;
  absSpeedY = ballSpeedY > 0 ? ballSpeedY : -ballSpeedY;
  normalY = ballSpeedY > 0 ? ballY : Y_BOUNCE_DISTANCE - ballY;

  /* reflection from "double" y */
  if(absSpeedX != 0)
    expect2Y = (normalY + x_distance*absSpeedY/absSpeedX) % (2*Y_BOUNCE_DISTANCE);
  else
    expect2Y = normalY;
  /* convert double Y to reflect up or down */
  expectY = expect2Y < Y_BOUNCE_DISTANCE ? expect2Y : 2*Y_BOUNCE_DISTANCE - expect2Y;
  if(ballSpeedY < 0)
    expectY = (SCREEN_HEIGHT - BALL_SIZE) - expectY;
  return expectY;
}

int expectA()
{
  return expect_y(ballX - PADDLE_PADDING-BALL_SIZE);
}

int expectB()
{
  return expect_y(SCREEN_WIDTH-PADDLE_PADDING-BALL_SIZE - ballX);
}

//Setup 
void setup() 
{
  c2.init();
  c2.alloc_sprites(SPRITE_MAX);
  
  // sprite 0: ball
  c2.sprite_fill_rect(BALL_SIZE, BALL_SIZE, C2_WHITE);

  // sprite 1: paddle
  c2.sprite_fill_rect(PADDLE_WIDTH, PADDLE_HEIGHT, C2_WHITE);

  // sprite 2: another paddle, clone of sprite 1
  c2.sprite_clone(1);

  // sprite 3: playfield horizontal lines of ball size is
  c2.sprite_fill_rect(SCREEN_WIDTH, BALL_SIZE, C2_ORANGE);
  c2.Sprite[3]->x = 0;
  c2.Sprite[3]->y = 0;

  // sprite 4: same line as above
  c2.sprite_clone(3);
  c2.Sprite[4]->y = (SCREEN_HEIGHT)-BALL_SIZE;
  
  // sprite 5: playfield vertical line
  c2.sprite_fill_rect(BALL_SIZE, SCREEN_HEIGHT-2*BALL_SIZE, C2_BLUE);
  c2.Sprite[5]->x = SCREEN_WIDTH/2 - BALL_SIZE/2;
  c2.Sprite[5]->y = BALL_SIZE;

  // draw them all
  c2.sprite_refresh();
  *c2.cntrl_reg = 0b11000000; // enable video, yes bitmap, no text mode, no cursor
  
  expectBY = expectB();
}

#if 1
long map(long x, long in_min, long in_max, long out_min, long out_max)
{
  return (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min;
}
#endif

//Splash Screen
void splash()
{
}


void calculateMovement() 
{
#if HAVE_ANALOG
  int controlA = analogRead(CONTROL_A);
  int controlB = analogRead(CONTROL_B);
#else
  static int controlA = 0;
  static int controlB = 0;
  if(ballSpeedX < 0)
    controlA += 1*(expectAY-paddleLocationA-PADDLE_HEIGHT/2+BALL_SIZE/2);
  if(ballSpeedX > 0)
    controlB += 1*(expectBY-paddleLocationB-PADDLE_HEIGHT/2+BALL_SIZE/2);
#endif
  paddleLocationA = map(controlA, 0, 1023, 0, SCREEN_HEIGHT - PADDLE_HEIGHT);
  paddleLocationB = map(controlB, 0, 1023, 0, SCREEN_HEIGHT - PADDLE_HEIGHT);

  int paddleSpeedA = paddleLocationA - lastPaddleLocationA;
  int paddleSpeedB = paddleLocationB - lastPaddleLocationB;

  ballX += ballSpeedX;
  ballY += ballSpeedY;

  //bounce from top and bottom
  if (ballY >= SCREEN_HEIGHT - BALL_SIZE || ballY <= 0) {
    ballSpeedY = -ballSpeedY;
    soundBounce();
  }

  //bounce from paddle A
  if (ballX >= PADDLE_PADDING && ballX <= PADDLE_PADDING+BALL_SIZE && ballSpeedX < 0) {
    if (ballY > paddleLocationA - BALL_SIZE && ballY < paddleLocationA + PADDLE_HEIGHT) {
      soundBounce();
      ballSpeedX = -ballSpeedX;
    
      addEffect(paddleSpeedA);
      expectBY = expectB();
    }

  }

  //bounce from paddle B
  if (ballX >= SCREEN_WIDTH-PADDLE_WIDTH-PADDLE_PADDING-BALL_SIZE && ballX <= SCREEN_WIDTH-PADDLE_PADDING-BALL_SIZE && ballSpeedX > 0) {
    if (ballY > paddleLocationB - BALL_SIZE && ballY < paddleLocationB + PADDLE_HEIGHT) {
      soundBounce();
      ballSpeedX = -ballSpeedX;
    
      addEffect(paddleSpeedB);
      expectAY = expectA();
    }

  }

  //score points if ball hits wall behind paddle
  if (ballX >= SCREEN_WIDTH - BALL_SIZE || ballX <= 0) {
    if (ballSpeedX > 0) {
      scoreA++;
      ballX = SCREEN_WIDTH / 4;
      expectBY = expectB();
    }
    if (ballSpeedX < 0) {
      scoreB++;
      ballX = SCREEN_WIDTH / 4 * 3;
      expectAY = expectA();
    }

    soundPoint();   
  }

  //set last paddle locations
  lastPaddleLocationA = paddleLocationA;
  lastPaddleLocationB = paddleLocationB;  
}

void draw()
{
  c2.Sprite[0]->x = ballX;
  c2.Sprite[0]->y = ballY;
  c2.Sprite[1]->x = PADDLE_PADDING;
  c2.Sprite[1]->y = paddleLocationA;
  c2.Sprite[2]->x = SCREEN_WIDTH-PADDLE_WIDTH-PADDLE_PADDING;
  c2.Sprite[2]->y = paddleLocationB;

  while((*c2.vblank_reg & 0x80) == 0);
  c2.sprite_refresh();
  while((*c2.vblank_reg & 0x80) != 0);
} 

//Loop
void loop()
{
  calculateMovement();
  draw();
}

void main(void)
{
  setup();
  while(1)
    loop();
}
