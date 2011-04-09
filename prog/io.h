

#ifndef _IO_H_
#define	_IO_H_

#define	IO_BASE		0xe0000000

#define	IO_LED		0x0
#define	IO_TSC		0x4
#define	IO_LCD_DATA	0x8
#define	IO_LCD_CTRL	0xc

#define	LCD_CTRL_RS	0x01
#define	LCD_CTRL_E	0x02
#define	LCD_DELAY	5000		/* In clock ticks, OK up to 200 MHz */

/* In the default design the clock ticks at 75 MHz */
#define	CPU_FREQ	75000000

/* I/O macros */

#define	OUTB(port, data)						   \
	__asm __volatile ("sb %0, %1($27)"		/* k1 = IO_BASE */ \
			:				/* outputs */	   \
			: "r" (data), "i" (port));	/* inputs */

#define	OUTH(port, data)						   \
	__asm __volatile ("sh %0, %1($27)"		/* k1 = IO_BASE */ \
			:				/* outputs */	   \
			: "r" (data), "i" (port));	/* inputs */

#define	OUTW(port, data)						   \
	__asm __volatile ("sw %0, %1($27)"		/* k1 = IO_BASE */ \
			:				/* outputs */	   \
			: "r" (data), "i" (port));	/* inputs */

#define	INB(data, port)							   \
	__asm __volatile ("lb %0, %1($27)"		/* k1 = IO_BASE */ \
			: "=r" (data)			/* outputs */	   \
			: "i" (port));			/* inputs */

#define	INH(data, port)							   \
	__asm __volatile ("lh %0, %1($27)"		/* k1 = IO_BASE */ \
			: "=r" (data)			/* outputs */	   \
			: "i" (port));			/* inputs */

#define	INW(data, port)							   \
	__asm __volatile ("lw %0, %1($27)"		/* k1 = IO_BASE */ \
			: "=r" (data)			/* outputs */	   \
			: "i" (port));			/* inputs */

#define	DELAY(ticks)							\
	do {								\
		int start, current;					\
		INW(start, IO_TSC); 					\
		do {							\
			INW(current, IO_TSC);				\
		} while (current - start < (ticks));			\
	} while (0);

#endif /* !_IO_H_ */

