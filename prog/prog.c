
#include "io.h"
#include "lcdfunc.h"

char lcdbuf[2][16] = {"   Hello, world!", "  f32c          "};

#define	BLACK	0
#define	GREEN	2
#define YELLOW	4
#define	RED	8

#define sem(s, v)						\
	do {							\
		if (s)						\
			state = (state & 0xf0) | (v);		\
		else						\
			state = (state & 0x0f) | ((v) << 4);	\
       		OUTW(IO_LED, state);				\
	} while (0);

#define	sleep(ms)	DELAY((ms) * 50000)
//#define	sleep(ms)	DELAY((ms * 3) >> 2)
//#define sleep(ms)

int state;
int a;
int b;

void
platform_start() {
	int i;

	if (a == b) {
		/* Pocetno stanje */
		for (i = 0; i < 16; i++) {
        		sem(0, BLACK);
        		sem(1, BLACK);
			sleep(500);
        		sem(0, YELLOW);
        		sem(1, YELLOW);
			sleep(500);
		}
       		sem(0, RED);
       		sem(1, RED);
		sleep(3000);
	}

	/* Zamijeni a / b */
	a = ~a;
	b = ~a;

       	sem(a, RED);
       	sem(b, RED);
	sleep(1000);

       	sem(a, RED | YELLOW);
	sleep(1500);

       	sem(a, GREEN);
	sleep(8000);

	for (i = 0; i < 4; i++) {
        	sem(a, BLACK);
		sleep(500);
        	sem(a, GREEN);
		sleep(500);
	}

       	sem(a, YELLOW);
	sleep(3000);

	return;
}
