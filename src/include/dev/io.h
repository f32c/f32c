/*-
 * Copyright (c) 2013-2017 Marko Zec, University of Zagreb
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
 */

#ifndef _IO_H_
#define	_IO_H_

#ifdef __mips
#include <mips/io.h>
#else
#ifdef __riscv
#include <riscv/io.h>
#else
#error "Unsupported architecture"
#endif
#endif


#define	IO_BASE		0xfffff800

#define	IO_ADDR(a)	(IO_BASE | (a))

#define	IO_GPIO_DATA	IO_ADDR(0x000)	/* word, RW */
#define	IO_GPIO_CTL	IO_ADDR(0x004)	/* word, WR */
#define	IO_GPIO_RISE_IF	IO_ADDR(0x008)	/* word, RW (clear only) */
#define	IO_GPIO_RISE_IE	IO_ADDR(0x00C)	/* word, RW */
#define	IO_GPIO_FALL_IF	IO_ADDR(0x010)	/* word, RW (clear only) */
#define	IO_GPIO_FALL_IE	IO_ADDR(0x014)	/* word, RW */

#define	IO_TIMER	IO_ADDR(0x100)	/* 16-byte, WR */

#define	IO_SIO_BYTE	IO_ADDR(0x300)	/* byte, RW */
#define	IO_SIO_STATUS	IO_ADDR(0x301)	/* byte, RD */
#define	IO_SIO_BAUD	IO_ADDR(0x302)	/* half, WR */

#define	IO_SPI_FLASH	IO_ADDR(0x340)	/* half, RW */
#define	IO_SPI_SDCARD	IO_ADDR(0x350)	/* half, RW */

#define	IO_FB		IO_ADDR(0x380)	/* word, WR */
#define	IO_TXTMODE_CTRL	IO_ADDR(0x381)	/* byte, WR */
#define	IO_C2VIDEO_BASE	IO_ADDR(0x390)	/* word, WR */

#define	IO_PCM_CUR	IO_ADDR(0x3A0)	/* word, RD */
#define	IO_PCM_FIRST	IO_ADDR(0x3A0)	/* word, WR */
#define	IO_PCM_LAST	IO_ADDR(0x3A4)	/* word, WR */
#define	IO_PCM_FREQ	IO_ADDR(0x3A8)	/* word, WR */
#define	IO_PCM_VOLUME	IO_ADDR(0x3AC)	/* half, WR */

#define	IO_LEGO_DATA	IO_ADDR(0x520)	/* byte, WR */
#define	IO_LEGO_CTL	IO_ADDR(0x521)	/* byte, WR */

#define	IO_PUSHBTN	IO_ADDR(0x700)	/* word, RD */
#define	IO_DIPSW	IO_ADDR(0x702)	/* word, RD */
#define	IO_LED		IO_ADDR(0x710)	/* word, WR */
#define	IO_LCD		IO_ADDR(0x712)	/* word, WR */

#define	IO_CPU_RESET	IO_ADDR(0x7F0)	/* byte, WR */


/* SIO status bitmask */
#define	SIO_TX_BUSY	0x4
#define	SIO_RX_OVERRUN	0x2
#define	SIO_RX_FULL	0x1

/* Pushbutton input bitmask */
#define	ROT_A		0x40
#define	ROT_B		0x20
#define	BTN_CENTER	0x10
#define	BTN_UP		0x08
#define	BTN_DOWN	0x04
#define	BTN_LEFT	0x02
#define	BTN_RIGHT	0x01

/* PMOD output mask */
#define	PMOD_J1_MASK	0x0f
#define	PMOD_J2_MASK	0xf0

/* LCD control output bitmask */
#define	LCD_DATA	0x0f
#define	LCD_RS		0x10
#define	LCD_E		0x20

/*
0xFFFFF800 ... 0xFFFFFFFF

0x800-0x83F gpio0 32xI/O, 32xIRQ (6x4-byte, expandable to 16x4-byte)
0x840-0x87F gpio1 ...
0x880-0x8DF gpio2
0x8C0-0x8FF gpio3

0x900-0x97F timer0 2xPWM 2xICP (14x4-byte, expandable to 32x4-byte)
0x980-0x9FF timer1 ...
0xA00-0xA7F timer2
0xA80-0xAFF timer3

0xB00-0xB0F SIO0 RS232 (4-byte, expandable to 16-byte)
0xB10-0xB1F SIO1 ...
0xB20-0xB2F SIO2 ...
0xB30-0xB3F SIO3 ...

0xB40-0xB4F SPI0 (Flash) (2 byte, expandable to 16-byte)
0xB50-0xB4F SPI1 (MicroSD)
0xB60-0xB4F SPI2 user spi's
0xB70-0xB4F SPI3 ...

0xB80-0xB8F FB0  framebuffer composite (2-byte, expandable to 16-byte)
0xB90-0xB9F FB1  framebuffer VGA/HDMI

0xBA0-0xBAF PCM0 Audio DMA (11-byte, expandable to 16-byte)
0xBB0-0xBBF PCM1 ...

0xC00-0xC3F CAN0 (can bus 64-byte)
0xC40-0xC7F CAN1 ...

0xC80-0xCDF USB0 (usb bus 64-byte)
0xCC0-0xCFF USB1 ...

0xD00-0xDFF free (I2C, LEGO, 433MHz, 16-byte each)
0xD20 LEGO
0xD30 433 MHz
0xD80 PID0
0xD90 PID1
0xDA0 PID2
0xDB0 PID3
0xDD0 DDS

0xE00-0xE3F ETH0 (ethernet 64-byte)
0xE40-0xE7F ETH1 ..

0xF00-0xF03 BTN0 (simple input  16-byte, address -256)
0xF04-0xF07 BTN1
0xF08-0xF0D BTN2
0xF0C-0xF0F BTN3

0xF10-0xF13 LED0 (simple output 16-byte, address -240)
0xF14-0xF17 LED1
0xF18-0xF1D LED2
0xF1C-0xF1F LED3
*/

#endif /* !_IO_H_ */
