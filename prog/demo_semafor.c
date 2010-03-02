
#include "io.h"
#include "lcdfunc.h"
#include "libc.h"

#define	BLACK	0
#define	GREEN	2
#define YELLOW	4
#define	RED	8

static struct sem_colors {
	int	mask;
	char	*name;
} sem_colors[] = {
	{ RED, "CRVENO" },
	{ GREEN, "ZELENO" },
	{ YELLOW, "ZUTO  " },
};

static int led_state;

static void sem(int s, int v)
{
	char *c;
	int i, len;

	if (s)
		led_state = (led_state & 0xf0) | (v);
	else
		led_state = (led_state & 0x0f) | ((v) << 4);
       	OUTW(IO_LED, led_state);

	c = &lcdbuf[s + 2][0];
	memset(c, ' ', 20);

	for (i = 0; i < 3; i++) {
		if (v & sem_colors[i].mask) {
			/* XXX strlen broken??? Why? Revisit !!! */
			//len = strlen(sem_colors[i].name);
			len = 6;
			bcopy(sem_colors[i].name, c, len);
			c += len;
			if (i < 2)
				*c++ = ' ';
		}
	}

	lcd_redraw();
}

void demo_semafor(int prog) {
	static int a;
	static int b;
	int i;

	bcopy(" Automatski semafor ", &lcdbuf[0][0], 20);

	if (a == b) {
		/* Pocetno stanje */
		for (i = 0; i < 16; i++) {
        		sem(0, BLACK);
        		sem(1, BLACK);
			msleep(500);
        		sem(0, YELLOW);
        		sem(1, YELLOW);
			msleep(500);
		}
       		sem(0, RED);
       		sem(1, RED);
		msleep(3000);
	}

	/* Zamijeni a / b */
	a = !a;
	b = !a;

       	sem(a, RED);
       	sem(b, RED);
	msleep(1000);

       	sem(a, RED | YELLOW);
	msleep(1500);

       	sem(a, GREEN);
	msleep(8000);

	for (i = 0; i < 4; i++) {
        	sem(a, BLACK);
		msleep(500);
        	sem(a, GREEN);
		msleep(500);
	}

       	sem(a, YELLOW);
	msleep(3000);

	return;
}
