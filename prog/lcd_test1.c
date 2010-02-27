
#include "io.h"
#include "lcdfunc.h"

char lcdbuf[2][16] = {"   Hello, world!", "  f32c          "};
static int alive = 0;

void
platform_start() {
	int i, j;
	int tsc;

	/* Occassionally scroll the 1st line left */
	if ((alive & 0x7f) == 0) {
		j = lcdbuf[0][0];
		for (i = 0; i < 15; i++)
			lcdbuf[0][i] = lcdbuf[0][i + 1];
		lcdbuf[0][15] = j;
	}

	/* Init LCD on the first run */
	if (alive == 0) {
                OUTW(IO_LCD_DATA, 0x38);        /* 8-bit, 2-line mode */
		OUTW(IO_LCD_CTRL, LCD_CTRL_E);  /* ctrl sequence, clock high */
		DELAY(LCD_DELAY << 8);
		OUTW(IO_LCD_CTRL, 0);           /* clock low */
		DELAY(LCD_DELAY << 8);

                OUTW(IO_LCD_DATA, 0x0c);        /* display on */
		OUTW(IO_LCD_CTRL, LCD_CTRL_E);  /* ctrl sequence, clock high */
		DELAY(LCD_DELAY << 8);
		OUTW(IO_LCD_CTRL, 0);           /* clock low */
		DELAY(LCD_DELAY << 8);
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
	for (j = 0; j < 2; j++) {
		lcd_cr(j);
		for (i = 0; i < 16; i++)
			lcd_putchar(lcdbuf[j][i]);
	}

	OUTW(IO_LED, ++alive);	/* blink LEDs */
	
	return;
}
