
#include "asm.h"
#include "regdef.h"
#include "io.h"
#include "lcdfunc.h"

char lcdbuf[4][20] = {
	"   Hello, world!    ",
	"  f32c              ",
	"01234567890123456789",
	"Evo zore, evo dana! ",
};
static int alive;

void
platform_start() {
	int tsc;
	int i, j;

	/* Init LCD on the first run */
	if (alive == 0) {
		for (i = 0; i < 3; i++) {
			OUTW(IO_LCD_DATA, 0x38);	/* 8-bit, 2-line mode */
			OUTW(IO_LCD_CTRL, LCD_CTRL_E);	/* ctrl sequence */
			DELAY(LCD_DELAY << 10);
			OUTW(IO_LCD_CTRL, 0);		/* clock low */
			DELAY(LCD_DELAY << 10);
		}

		OUTW(IO_LCD_DATA, 0x0c);	/* display on */
		OUTW(IO_LCD_CTRL, LCD_CTRL_E);	/* ctrl sequence */
		DELAY(LCD_DELAY << 8);
		OUTW(IO_LCD_CTRL, 0);		/* clock low */
		DELAY(LCD_DELAY << 8);
	}

	/* Occassionally scroll the 1st line left */
	if ((alive & 0x3f) == 0) {
		j = lcdbuf[0][0];
		for (i = 0; i < 20; i++)
			lcdbuf[0][i] = lcdbuf[0][i + 1];
		lcdbuf[0][19] = j;
	}

	/* Occassionally scroll the 4rd line left */
	if ((alive & 0x1f) == 0) {
		j = lcdbuf[3][0];
		for (i = 0; i < 20; i++)
			lcdbuf[3][i] = lcdbuf[3][i + 1];
		lcdbuf[3][19] = j;
	}

	/* Occassionally swap 1st and 4th line */
	if ((alive & 0x1ff) == 0) {
		for (i = 0; i < 20; i++) {
			j = lcdbuf[0][i];
			lcdbuf[0][i] = lcdbuf[3][i];
			lcdbuf[3][i] = j;
		}
	}

	/* Read TSC, and dump it in hex in lcdbuf */
	INW(tsc, IO_TSC);
	for (i = 15; i >= 8; i--) {
		j = (tsc & 0xf) + '0';
		if (j > '9')
			j += 'a' - ':';
		lcdbuf[1][i] = j;
		tsc = tsc >> 4;
	}

	/* Refresh LCD */
	for (j = 0; j < 4; j++) {
		lcd_cr(j);
		for (i = 0; i < 20; i++)
			lcd_putchar(lcdbuf[j][i]);
	}

	INW(tsc, IO_TSC);
	__asm __volatile ("addu $26,$0,%1"	/* k1 = IO_BASE */
		: "=r" (tsc)			/* outputs */     
		: "r" (tsc));			/* inputs */

	OUTW(IO_LED, ++alive);	/* blink LEDs */
	
	return;
}
