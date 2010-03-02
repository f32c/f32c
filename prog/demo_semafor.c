
#include "demo.h"
#include "io.h"
#include "lcdfunc.h"
#include "libc.h"

#define	BLACK	0
#define	GREEN	2
#define YELLOW	4
#define	RED	8

#define	MSLEEP(t)	if (msleep(t)) return;

static struct sem_colors {
	int	mask;
	char	*name;
} sem_colors[4][3] = {
	{
		{ RED, "CRVENO" },
		{ GREEN, "ZELENO" },
		{ YELLOW, "ZUTO  " },
	},
	{
		{ RED, "crveno" },
		{ GREEN, "zeleno" },
		{ YELLOW, "zuto  " },
	},
	{
		{ RED, "RED   " },
		{ GREEN, "GREEN " },
		{ YELLOW, "YELLOW" },
	},
	{
		{ RED, "red   " },
		{ GREEN, "green " },
		{ YELLOW, "yellow" },
	}
};

static int led_state;

static void sem(int s, int v)
{
	char *c;
	int i, len, sel;

	if (s)
		led_state = (led_state & 0xf0) | (v);
	else
		led_state = (led_state & 0x0f) | ((v) << 4);
       	OUTW(IO_LED, led_state);

	c = &lcdbuf[s + 2][0];
	memset(c, ' ', 20);

	/* sw3 & sw2 select language & upper / lower case */
	INW(sel, IO_LED);
	sel = (sel >> 2) & 0x3;

	for (i = 0; i < 3; i++) {
		if (v & sem_colors[sel][i].mask) {
			/* XXX strlen broken??? Why? Revisit !!! */
			//len = strlen(sem_colors[sel][i].name);
			len = 6;
			bcopy(sem_colors[sel][i].name, c, len);
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
	static int cnt;
	int i;

	switch (prog) {
	case DEMO_AUTOMATSKI_SEMAFOR:
		bcopy(" Automatski semafor ", &lcdbuf[0][0], 20);
		break;
	case DEMO_POKVARENI_SEMAFOR:
		bcopy(" Pokvareni semafor  ", &lcdbuf[0][0], 20);
		break;
	case DEMO_POLUDJELI_SEMAFOR:
		bcopy(" Poludjeli semafor  ", &lcdbuf[0][0], 20);
       		sem(0, (cnt >> 4) & 0xf);
       		sem(1, cnt & 0xf);
		cnt++;
		MSLEEP(100);
		return;
	}

	if (a == b || prog == DEMO_POKVARENI_SEMAFOR) {
		/* Pocetno stanje */
		for (i = 0; i < 16; i++) {
        		sem(0, BLACK);
        		sem(1, BLACK);
			MSLEEP(500);
        		sem(0, YELLOW);
        		sem(1, YELLOW);
			MSLEEP(500);
		}

		if (prog == DEMO_POKVARENI_SEMAFOR)
			return;

       		sem(0, RED);
       		sem(1, RED);
		MSLEEP(3000);
	}

	/* Zamijeni a / b */
	a = !a;
	b = !a;

       	sem(a, RED);
       	sem(b, RED);
	MSLEEP(1000);

       	sem(a, RED | YELLOW);
	MSLEEP(1500);

       	sem(a, GREEN);
	MSLEEP(8000);

	for (i = 0; i < 4; i++) {
        	sem(a, BLACK);
		MSLEEP(500);
        	sem(a, GREEN);
		MSLEEP(500);
	}

       	sem(a, YELLOW);
	MSLEEP(3000);

	return;
}
