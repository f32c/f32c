
#ifndef _IO_H_
#define	_IO_H_

#define	IO_BASE		0xe0000000

#define	IO_LED		0x0	/* byte, WR */
#define	IO_SPI		0x3	/* byte, RW */
#define	IO_SIO		0x4	/* word, RW */
#define	IO_TSC		0x8	/* word, RD */
#define	IO_PCM		0xc	/* word, WR */

/* SIO bitmask */
#define	SIO_TX_BUSY	0x8
#define	SIO_RX_BYTES	0x3

/* SPI bitmask: outputs */
#define	SPI_SI		0x80
#define	SPI_SCK		0x40
#define	SPI_CEN		0x20
/* SPI bitmask: input */
#define	SPI_SO		0x80

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

#define	DELAY_TICKS(ticks)						\
	do {								\
		register int start, current;				\
		INW(start, IO_TSC); 					\
		do {							\
			INW(current, IO_TSC);				\
		} while (current - start < (ticks));			\
	} while (0);


/*
 * Declaration of misc. IO functions.
 */

int spi_byte(int);
void spi_start_transaction(void);
void spi_stop_transaction(void);

inline int
rdtsc(void) {
	register int tsc;

	INW(tsc, IO_TSC);
	return (tsc);
}

#endif /* !_IO_H_ */

