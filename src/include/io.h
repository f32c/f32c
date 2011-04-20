
#ifndef _IO_H_
#define	_IO_H_

#define	IO_BASE		0xe0000000

#define	IO_LED		0x00	/* byte, WR */
#define	IO_SPI		0x03	/* byte, RW */
#define	IO_SIO		0x04	/* word, RW */
#define	IO_TSC		0x08	/* word, RD */
#define	IO_PCM_OUT	0x10	/* word, WR */
#define	IO_PCM_VOL	0x14	/* word, WR */

/* SIO bitmask */
#define	SIO_TX_BUSY	0x8
#define	SIO_RX_BYTES	0x3

/* SPI bitmask: outputs */
#define	SPI_SI		0x80
#define	SPI_SCK		0x40
#define	SPI_CEN		0x20
/* SPI bitmask: input */
#define	SPI_SO_BITPOS	7
#define	SPI_SO		(1 << SPI_SO_BITPOS)

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
int spi_byte_in(void);

void inline
spi_start_transaction(void)
{

	OUTB(IO_SPI, 0);
}

void inline
spi_stop_transaction(void)
{

	OUTB(IO_SPI, SPI_CEN);
}


/*
 * Fetch the current timestamp counter value.  Given that CPU and TSC
 * clocks are not guaranteed to be in sync, we need to read the TSC
 * register twice, and repeat the process until we have obtained two
 * consistent readings.
 */
inline int
rdtsc(void) {
	register int tsc1, tsc2;

	do {
		INW(tsc1, IO_TSC);
		INW(tsc2, IO_TSC);
	} while (tsc2 != tsc1);
	return (tsc2);
}

#endif /* !_IO_H_ */

