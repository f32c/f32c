
/* LCD manipulation functions are cheaper inlined the otherwise */

inline void lcd_cr(int i) {
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

inline void lcd_putchar(int c) {

	OUTW(IO_LCD_DATA, c);		/* char to send */
	OUTW(IO_LCD_CTRL, LCD_CTRL_E | LCD_CTRL_RS); /* data sqn, clock high */
	DELAY(LCD_DELAY);
	OUTW(IO_LCD_CTRL, LCD_CTRL_RS);	/* clock low */
	DELAY(LCD_DELAY);
}
