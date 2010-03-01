
#include "asm.h"
#include "regdef.h"
#include "io.h"
#include "lcdfunc.h"


char lcdbuf[LCD_ROWS][LCD_COLUMNS] = {
	"   Hello, world!    ",
	"  f32c              ",
	"01234567890123456789",
	"Evo zore, evo dana! ",
};

static int lcd_initialized = 0;

static int alive;
static int old_key;

static void lcd_cr(int i)
{
	int cmd;

	switch (i) {
		case 0:
			cmd = 0x80;
			break;
		case 1:
			cmd = 0xc0;
			break;
		case 2:
			cmd = 0x94;
			break;
		case 3:
			cmd = 0xd4;
			break;
	}
	OUTW(IO_LCD_DATA, cmd);
	OUTW(IO_LCD_CTRL, LCD_CTRL_E);	/* control sequence, clock high */
	DELAY(LCD_DELAY);
	OUTW(IO_LCD_CTRL, 0);		/* clock low */
	DELAY(LCD_DELAY);
}

static void lcd_putchar(int c)
{

	OUTW(IO_LCD_DATA, c);		/* char to send */
	OUTW(IO_LCD_CTRL, LCD_CTRL_E | LCD_CTRL_RS); /* data sqn, clock high */
	DELAY(LCD_DELAY);
	OUTW(IO_LCD_CTRL, LCD_CTRL_RS);	/* clock low */
	DELAY(LCD_DELAY);
}

static void lcd_init(void)
{
	int i;

	for (i = 0; i < 3; i++) {
		OUTW(IO_LCD_DATA, 0x38);	/* 8-bit, 2-line mode */
		OUTW(IO_LCD_CTRL, LCD_CTRL_E);	/* ctrl sequence, clk hi */
		DELAY(LCD_DELAY << 10);
		OUTW(IO_LCD_CTRL, 0);		/* clock low */
		DELAY(LCD_DELAY << 10);
	}

	OUTW(IO_LCD_DATA, 0x0c);	/* display on */
	OUTW(IO_LCD_CTRL, LCD_CTRL_E);	/* ctrl sequence, clk lo */
	DELAY(LCD_DELAY << 8);
	OUTW(IO_LCD_CTRL, 0);		/* clock low */
	DELAY(LCD_DELAY << 8);

	lcd_initialized = 1;
}

void lcd_redraw(void)
{
	int i, j;

	if (!lcd_initialized)
		lcd_init();

	for (j = 0; j < LCD_ROWS; j++) {
		lcd_cr(j);
		for (i = 0; i < LCD_COLUMNS; i++)
			lcd_putchar(lcdbuf[j][i]);
	}
}

void
platform_start() {
	int tsc;
	int key;
	int i, j;

	lcd_redraw();

	/* Occassionally scroll the 1st line left */
	if ((alive & 0x3f) == 0) {
		j = lcdbuf[0][0];
		for (i = 0; i < LCD_COLUMNS; i++)
			lcdbuf[0][i] = lcdbuf[0][i + 1];
		lcdbuf[0][LCD_COLUMNS - 1] = j;
	}

	/* Occassionally scroll the 4rd line left */
	if ((alive & 0x1f) == 0) {
		j = lcdbuf[3][0];
		for (i = 0; i < 20; i++)
			lcdbuf[3][i] = lcdbuf[3][i + 1];
		lcdbuf[3][19] = j;
	}

	/* Occassionally swap 1st and 4th line */
	INW(key, IO_LED);	/* effectively IO_LED = IO_KEY */
	if ((key & 0x100) && !(old_key & 0x100)) {
		for (i = 0; i < 20; i++) {
			j = lcdbuf[0][i];
			lcdbuf[0][i] = lcdbuf[3][i];
			lcdbuf[3][i] = j;
		}
	}
	old_key = key;

	/* Read TSC, and dump it in hex in lcdbuf */
	INW(tsc, IO_TSC);
	for (i = 15; i >= 8; i--) {
		j = (tsc & 0xf) + '0';
		if (j > '9')
			j += 'a' - ':';
		lcdbuf[1][i] = j;
		tsc = tsc >> 4;
	}

	INW(tsc, IO_TSC);
	__asm __volatile ("addu $26,$0,%1"	/* k1 = IO_BASE */
		: "=r" (tsc)			/* outputs */     
		: "r" (tsc));			/* inputs */

	OUTW(IO_LED, ++alive);	/* blink LEDs */
	
	return;
}
