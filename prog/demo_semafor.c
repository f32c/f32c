
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

static char *prog_names[] = {
	"Automatski semafor",
	"Pokvareni semafor",
	"Poludjeli semafor",
	"  Rucni semafor",
	"      Noise",
};

static int led_state;
static int sem_a;
static int sem_b;

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
	int i;

	bcopy(prog_names[prog], &lcdbuf[0][1], strlen(prog_names[prog]));

	if (prog == DEMO_NOISE) {
		do {
			sem_a = random() & 3;
			div(random(), 20, (unsigned int *) &sem_b);
			div(random(), 95, (unsigned int *) &i);
			lcdbuf[sem_a][sem_b] = ' ' + i;
			MSLEEP(10);
		} while (1);
	}

	if (prog == DEMO_POLUDJELI_SEMAFOR) {
		sem_a = random();
       		sem(0, (sem_a >> 3) & 0xe);
       		sem(1, sem_a & 0xe);
		MSLEEP(sem_a & 0x1ff);
		return;
	}

	if (sem_a == sem_b || prog == DEMO_POKVARENI_SEMAFOR) {
		/* Pocetno stanje */
		for (i = 0; i < 8; i++) {
        		sem(0, BLACK);
        		sem(1, BLACK);
			MSLEEP(500);
        		sem(0, YELLOW);
        		sem(1, YELLOW);
			MSLEEP(500);
		}

		if (prog == DEMO_POKVARENI_SEMAFOR) {
			sem_a--;
			return;
		}

       		sem(0, RED);
       		sem(1, RED);
		MSLEEP(3000);
	}

	/* Zamijeni a / b */
	sem_a = !sem_a;
	sem_b = !sem_a;

       	sem(sem_a, RED);
       	sem(sem_b, RED);
	MSLEEP(1500);

       	sem(sem_a, RED | YELLOW);
	MSLEEP(1500);

       	sem(sem_a, GREEN);
	MSLEEP(8000);

	for (i = 0; i < 4; i++) {
        	sem(sem_a, BLACK);
		MSLEEP(500);
        	sem(sem_a, GREEN);
		MSLEEP(500);
	}

       	sem(sem_a, YELLOW);
	MSLEEP(3000);

	return;
}
