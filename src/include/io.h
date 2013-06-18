
#ifndef _IO_H_
#define	_IO_H_


#define	IO_BASE		-32768

#define	IO_ADDR(a)	(IO_BASE + (a))

#define	IO_LED		IO_ADDR(0x00)	/* byte, WR */
#define	IO_PUSHBTN	IO_ADDR(0x00)	/* byte, RD */
#define	IO_DIPSW	IO_ADDR(0x01)	/* byte, RD */
#define	IO_PMOD_J1_J2	IO_ADDR(0x01)	/* byte, WR */
#define	IO_LCD_DB	IO_ADDR(0x02)	/* byte, WR */
#define	IO_LCD_CTRL	IO_ADDR(0x03)	/* byte, WR */
#define	IO_SIO_BYTE	IO_ADDR(0x04)	/* byte, RW */
#define	IO_SIO_STATUS	IO_ADDR(0x05)	/* byte, RD */
#define	IO_SIO_BAUD	IO_ADDR(0x06)	/* half, WR */
#define	IO_CPU_RESET	IO_ADDR(0x08)	/* byte, WR */
#define	IO_PCM_OUT	IO_ADDR(0x0c)	/* word, WR */
#define	IO_SPI_FLASH	IO_ADDR(0x10)	/* byte, RW */
#define	IO_SPI_SDCARD	IO_ADDR(0x14)	/* byte, RW */
#define	IO_FB		IO_ADDR(0x18)	/* byte, WR */
#define	IO_DDS		IO_ADDR(0x1c)	/* word, WR */

#define	FB_BASE		0x80080000


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
#define	LCD_CTRL_E	0x4
#define	LCD_CTRL_RS	0x2
#define	LCD_CTRL_RW	0x1


#if !defined(__ASSEMBLER__)

/* Load / store macros */

#define	SB(data, offset, addr)						\
	__asm __volatile (						\
		"sb %0, %1(%2)"						\
		:							\
		: "r" (data), "i" (offset), "r" (addr)			\
	)

#define	SH(data, offset, addr)						\
	__asm __volatile (						\
		"sh %0, %1(%2)"						\
		:							\
		: "r" (data), "i" (offset), "r" (addr)			\
	)

#define	SW(data, offset, addr)						\
	__asm __volatile (						\
		"sw %0, %1(%2)"						\
		:							\
		: "r" (data), "i" (offset), "r" (addr)			\
	)

#define	LB(data, offset, addr)						\
	__asm __volatile (						\
		"lb %0, %1(%2)"						\
		: "=r" (data)						\
		: "i" (offset), "r" (addr)				\
	)

#define	LH(data, offset, addr)						\
	__asm __volatile (						\
		"lh %0, %1(%2)"						\
		: "=r" (data)						\
		: "i" (offset), "r" (addr)				\
	)

#define	LW(data, offset, addr)						\
	__asm __volatile (						\
		"lw %0, %1(%2)"						\
		: "=r" (data)						\
		: "i" (offset), "r" (addr)				\
	)

/* I/O macros */

#define	OUTB(port, data)					   \
	__asm __volatile ("sb %0, %1($0)"	/* IO_BASE = 0xf* */ \
		:				/* outputs */	   \
		: "r" (data), "i" (port))	/* inputs */

#define	OUTH(port, data)					   \
	__asm __volatile ("sh %0, %1($0)"	/* IO_BASE = 0xf* */ \
		:				/* outputs */	   \
		: "r" (data), "i" (port))	/* inputs */

#define	OUTW(port, data)					   \
	__asm __volatile ("sw %0, %1($0)"	/* IO_BASE = 0xf* */ \
		:				/* outputs */	   \
		: "r" (data), "i" (port))	/* inputs */

#define	INB(data, port)						   \
	__asm __volatile ("lb %0, %1($0)"	/* IO_BASE = 0xf* */ \
		: "=r" (data)			/* outputs */	   \
		: "i" (port))			/* inputs */

#define	INH(data, port)						   \
	__asm __volatile ("lh %0, %1($0)"	/* IO_BASE = 0xf* */ \
		: "=r" (data)			/* outputs */	   \
		: "i" (port))			/* inputs */

#define	INW(data, port)						   \
	__asm __volatile ("lw %0, %1($0)"	/* IO_BASE = 0xf* */ \
		: "=r" (data)			/* outputs */	   \
		: "i" (port))			/* inputs */


/*
 * Declaration of misc. IO functions.
 */

/* XXX this doesn't belong here... */
#include <mips/cpuregs.h>
#define	RDTSC(var)						\
	__asm __volatile ("mfc0 %0, $%1"			\
		: "=r" (var)			/* outputs */	\
		: "i" (MIPS_COP_0_COUNT))	/* inputs */

#define	DELAY(ticks) 						\
	__asm __volatile__ (					\
		".set noreorder;"				\
		".set noat;"					\
		"	li	$1, -2;"			\
		"	and	$1, $1, %0;"			\
		"1:	bnez	$1, 1b;"			\
		"	addiu	$1, $1, -2;"			\
		".set at;"					\
		".set reorder;"					\
		:						\
		: "r" (ticks)					\
	)

#endif /* __ASSEMBLER__ */

#endif /* !_IO_H_ */

