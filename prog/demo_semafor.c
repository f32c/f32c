
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

static struct gradovi {
	char	*name;
	int	km;
} gradovi[] = {
	{ "Vukovar", -294 },
	{ "Slavonski Brod", -192 },
	{ "Zagreb", 0 },
	{ "Karlovac", 55 },
	{ "Gospic", 201 },
	{ "Zadar", 287 },
	{ "Split", 410 },
	{ "Dubrovnik", 637 },
};

static char *prog_names[] = {
	"Automatski semafor",
	"Pokvareni semafor",
	"  Rucni semafor",
	"Poludjeli semafor",
	" Naplatne kucice",
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
	int i, s, d;
	char *c;

	bcopy(prog_names[prog], &lcdbuf[0][1], strlen(prog_names[prog]));

	if (prog == DEMO_POKVARENI_SEMAFOR) {
		sem(0, BLACK);
		sem(1, BLACK);
		MSLEEP(500 - (rotpos << 3));
		sem(0, YELLOW);
		sem(1, YELLOW);
		MSLEEP(500 - (rotpos << 3));
		return;
	}

	if (prog == DEMO_RUCNI_SEMAFOR) {
		do {
			sem(0, (rotpos >> 2) & 0xe);
			sem(1, (rotpos << 1) & 0xe);
			MSLEEP(10);
		} while (1);
	}

	if (prog == DEMO_POLUDJELI_SEMAFOR) {
		sem_a = random();
		sem(0, (sem_a >> 3) & 0xe);
		sem(1, sem_a & 0xe);
		MSLEEP((sem_a & 0x1ff) - (rotpos << 3));
		return;
	}

	if (prog == DEMO_GRADOVI) {
		do {
			for (i = 1; i < 4; i++)
				memset(&lcdbuf[i][0], ' ', 20);

			s = (rotpos >> 3) & 0x7;
			d = rotpos & 0x7;
			i = strlen(gradovi[s].name);
			bcopy(gradovi[s].name, &lcdbuf[1][(20 - i) >> 1], i);
			i = strlen(gradovi[d].name);
			bcopy(gradovi[d].name, &lcdbuf[2][(20 - i) >> 1], i);
			i = gradovi[s].km - gradovi[d].km;
			if (i < 0)
				i = -i;
			c = itoa(i, &lcdbuf[3][7]);
			bcopy(" km", c, 3);

			INW(i, IO_TSC);
			i = div(i, CPU_FREQ / 2, (void *) 0);
			if (i & 0x1) {
       		OUTW(IO_LED, 0x44);
			} else {
       		OUTW(IO_LED, 0);
			}
			MSLEEP(10);
		} while (1);
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
