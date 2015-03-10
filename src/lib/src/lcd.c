/*-
 * Copyright (c) 2014 Marko Zec, University of Zagreb
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * $Id$
 */


#include <io.h>


static void
lcd_delay(int us)
{
	uint32_t start, stop;
	uint32_t ticks = us * 128; /* XXX assumes <= 128 MHz clock */

	RDTSC(start);
	do {
		RDTSC(stop);
	} while (stop - start <= ticks);
}


static void
lcd_nibble(int rs, int val)
{

	val &= LCD_DATA;
	if (rs)
		val |= LCD_RS;
	
	OUTB(IO_LCD, val | LCD_E);
	lcd_delay(6);
	OUTB(IO_LCD, val);
	lcd_delay(40);
}


void
lcd_byte(int rs, int val)
{

	lcd_nibble(rs, val >> 4);
	lcd_nibble(rs, val);
}


void
lcd_init(void)
{

	/* Cold-start init sequence */
	lcd_nibble(0, 0x3);
	lcd_delay(4100);
	lcd_nibble(0, 0x3);
	lcd_delay(100);
	lcd_nibble(0, 0x3);
	lcd_delay(4100);
	lcd_nibble(0, 0x2);

	/* We should be in 4-bit mode now */
	lcd_byte(0, 0x28);	/* 4-bit, 2 lines, font 0 (5x8) */
	lcd_byte(0, 0x06);	/* Auto position increment, no scroll */
	lcd_byte(0, 0x0c);	/* Display on, cursor off, blink off */
	lcd_byte(0, 0x01);	/* Clear screen */
	lcd_delay(1600);
}


void
lcd_puts(const char *cp)
{

	while (*cp != 0) 
		lcd_byte(1, *cp++);
}
