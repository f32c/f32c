
#include "bas.h"

#include <stdio.h>
#include <fb.h>


static int last_x;
static int last_y;
static int fgcolor = 0xffff;
static int bgcolor = 0;


void
setup_fb(void)
{

	/* Turn off video framebuffer */
	fb_set_mode(3);
}


int
vidmode(void)
{
	int mode;

	mode = evalint();
	check();
	if (mode < 0 || mode > 3)
		error(33);	/* argument error */
	fb_set_mode(mode);
	if (mode < 2)
		fb_rectangle(0, 0, 511, 287, 0);
	last_x = 0;
	last_y = 0;
	normret;
}


int
color(void)
{
	int color, c;
	int bg = 0;

	color = evalint();
	c = getch();
	if (istermin(c))
		point--;
	else {
		if (c != ',')
			error(15);
		bg = evalint();
		check();
		if (bg < 0 || bg > 1)
			error(33);	/* argument error */
	}

	if (bg)
		bgcolor = color;
	else
		fgcolor = color;
	normret;
}


int
plot(void)
{
	int x, y, c;
	int firstdot = 1;

	do {
		x = evalint();
		if(getch() != ',')
			error(SYNTAX);
		y = evalint();
		if (firstdot) {
			fb_plot(x, y, fgcolor);
			firstdot = 0;
		} else
			fb_line(last_x, last_y, x, y, fgcolor);
		last_x = x;
		last_y = y;
		c = getch();
		if (istermin(c)) {
			point--;
			normret;
		}
		if (c != ',')
			error(15);
	} while (1);
}


int
lineto(void)
{
	int x, y, c;

	do {
		x = evalint();
		if(getch() != ',')
			error(SYNTAX);
		y = evalint();
		fb_line(last_x, last_y, x, y, fgcolor);
		last_x = x;
		last_y = y;
		c = getch();
		if (istermin(c)) {
			point--;
			normret;
		}
		if (c != ',')
			error(15);
	} while (1);
}


int
rectangle(void)
{
	int x0, y0, x1, y1;
	int c, fill = 0;

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

	c = getch();
	if (istermin(c))
		point--;
	else {
		if (c != ',')
			error(15);
		fill = evalint();
		check();
		if (fill < 0 || fill > 1)
			error(33);	/* argument error */
	}

	if (fill)
		fb_rectangle(x0, y0, x1, y1, fgcolor);
	else {
		fb_line(x0, y0, x1, y0, fgcolor);
		fb_line(x1, y0, x1, y1, fgcolor);
		fb_line(x1, y1, x0, y1, fgcolor);
		fb_line(x0, y1, x0, y0, fgcolor);
	}
	normret;
}


int
circle(void)
{
	int x0, y0, r;
	int c, fill = 0;

	x0 = evalint();
	if(getch() != ',')
		error(SYNTAX);
	y0 = evalint();
	if(getch() != ',')
		error(SYNTAX);
	r = evalint();

	c = getch();
	if (istermin(c))
		point--;
	else {
		if (c != ',')
			error(15);
		fill = evalint();
		check();
		if (fill < 0 || fill > 1)
			error(33);	/* argument error */
	}

	if (fill)
		fb_filledcircle(x0, y0, r, fgcolor);
	else
		fb_circle(x0, y0, r, fgcolor);
	normret;
}


int
blkmove(void)
{

	normret;
}


int
text(void)
{

	normret;
}
