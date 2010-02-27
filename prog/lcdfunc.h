
/* LCD manipulation functions are cheaper inlined the otherwise */

inline void lcd_cr(int i) {

	if (i) {
		OUTW(IO_LCD_DATA, 0xc0);	/* line 0, char 0 */
	} else {
		OUTW(IO_LCD_DATA, 0x80);	/* line 1, char 0 */
	}
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
