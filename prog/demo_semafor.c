
#include "demo.h"
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
} sem_colors[2][3] = {
	{
		{ RED, "crveno" },
		{ YELLOW, " zuto" },
		{ GREEN, "zeleno" },
	},
	{
		{ RED, "  red" },
		{ YELLOW, "yellow" },
		{ GREEN, "green" },
	}
};

static char *prog_names[3] = {
	"Automatski semafor",
	"Pokvareni semafor",
	"Poludjeli semafor",
};

static int led_state;

#define	MSLEEP(t)	if (msleep(t)) return;


static void sem(int s, int v)
{
	int i, sel;
	char *c;

	if (s)
		led_state = (led_state & 0xf0) | (v);
	else
		led_state = (led_state & 0x0f) | ((v) << 4);
       	OUTW(IO_LED, led_state);

	c = &lcdbuf[s + 2][0];
	memset(c, ' ', 20);

	/* sw2 selects language */
	INW(sel, IO_LED);
	sel = (sel >> 2) & 0x1;

	for (i = 0; i < 3; i++) {
		if (v & sem_colors[sel][i].mask)
			bcopy(sem_colors[sel][i].name, c,
			    strlen(sem_colors[sel][i].name));
		c += 7;
	}
}

void demo_semafor(int prog) {
	static int a;
	static int b;
	int i;

	bcopy(prog_names[prog], &lcdbuf[0][1], strlen(prog_names[prog]));

	if (prog == DEMO_POLUDJELI_SEMAFOR) {
       		sem(0, (a >> 3) & 0xe);
       		sem(1, a & 0xe);
		a++;
		MSLEEP(250);
		return;
	}

	if (a == b || prog == DEMO_POKVARENI_SEMAFOR) {
		/* Pocetno stanje */
		for (i = 0; i < 8; i++) {
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
	MSLEEP(1500);

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
