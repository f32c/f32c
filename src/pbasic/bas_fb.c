
#include "bas.h"

#include <stdio.h>
#include <fb.h>


static int fgcolor = 0xffff;
static int bgcolor = 0;


void
setup_fb(void)
{

	fb_set_mode(1);
}


int
draw_fgcolor(void)
{
	int arg;

	arg = evalint();
	check();
	fgcolor = arg;
	normret;
}


int
draw_bgcolor(void)
{
	int arg;

	arg = evalint();
	check();
	bgcolor = arg;
	normret;
}


int
draw_plot(void)
{
	int x, y;

	x = evalint();
	if(getch() != ',')
		error(SYNTAX);
	y = evalint();
	check();
	fb_plot(x, y, fgcolor);
	normret;
}


int
draw_line(void)
{
	int x0, y0, x1, y1;

	x0 = evalint();
	if(getch() != ',')
		error(SYNTAX);
	y0 = evalint();
	if(getch() != ',')
		error(SYNTAX);
	x1 = evalint();
	if(getch() != ',')
		error(SYNTAX);
	y1 = evalint();
	check();
	fb_line(x0, y0, x1, y1, fgcolor);
	normret;
}


int
draw_rectangle(void)
{
	int x0, y0, x1, y1;

	x0 = evalint();
	if(getch() != ',')
		error(SYNTAX);
	y0 = evalint();
	if(getch() != ',')
		error(SYNTAX);
	x1 = evalint();
	if(getch() != ',')
		error(SYNTAX);
	y1 = evalint();
	check();
	fb_line(x0, y0, x0, y1, fgcolor);
	fb_line(x0, y1, x1, y1, fgcolor);
	fb_line(x1, y1, x0, y1, fgcolor);
	fb_line(x1, y0, x0, y0, fgcolor);
	normret;
}


int
draw_fillrectangle(void)
{
	int x0, y0, x1, y1;

	x0 = evalint();
	if(getch() != ',')
		error(SYNTAX);
	y0 = evalint();
	if(getch() != ',')
		error(SYNTAX);
	x1 = evalint();
	if(getch() != ',')
		error(SYNTAX);
	y1 = evalint();
	check();
	fb_rectangle(x0, y0, x1, y1, fgcolor);
	normret;
}


int
draw_circle(void)
{
	int x0, y0, r;

	x0 = evalint();
	if(getch() != ',')
		error(SYNTAX);
	y0 = evalint();
	if(getch() != ',')
		error(SYNTAX);
	r = evalint();
	check();
	fb_circle(x0, y0, r, fgcolor);
	normret;
}


int
draw_fillcircle(void)
{
	int x0, y0, r;

	x0 = evalint();
	if(getch() != ',')
		error(SYNTAX);
	y0 = evalint();
	if(getch() != ',')
		error(SYNTAX);
	r = evalint();
	check();
	fb_filledcircle(x0, y0, r, fgcolor);
	normret;
}
