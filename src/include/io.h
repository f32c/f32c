
#ifndef _IO_H_
#define	_IO_H_

#define	IO_BASE		0xe0000000

#define	IO_LED		0x00	/* byte, WR */
#define	IO_PUSHBTN	0x00	/* byte, RD */
#define	IO_DIPSW	0x01	/* byte, RD */
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

/* Pushbutton bitmask */
#define	BTN_CENTER	0x10
#define	BTN_UP		0x08
#define	BTN_DOWN	0x04
#define	BTN_LEFT	0x02
#define	BTN_RIGHT	0x01

#if !defined(__ASSEMBLER__)

/* I/O macros */

#define	OUTB(port, data)						   \
	do {								   \
		__asm __volatile ("sb %0, %1($27)"	/* k1 = IO_BASE */ \
			:				/* outputs */	   \
			: "r" (data), "i" (port));	/* inputs */	   \
	} while (0)

#define	OUTH(port, data)						   \
	do {								   \
		__asm __volatile ("sh %0, %1($27)"	/* k1 = IO_BASE */ \
			:				/* outputs */	   \
			: "r" (data), "i" (port));	/* inputs */	   \
	} while (0)

#define	OUTW(port, data)						   \
	do {								   \
		__asm __volatile ("sw %0, %1($27)"	/* k1 = IO_BASE */ \
			:				/* outputs */	   \
			: "r" (data), "i" (port));	/* inputs */	   \
	} while (0)

#define	INB(data, port)							   \
	do {								   \
		__asm __volatile ("lb %0, %1($27)"	/* k1 = IO_BASE */ \
			: "=r" (data)			/* outputs */	   \
			: "i" (port));			/* inputs */	   \
	} while (0)

#define	INH(data, port)							   \
	do {								   \
		__asm __volatile ("lh %0, %1($27)"	/* k1 = IO_BASE */ \
			: "=r" (data)			/* outputs */	   \
			: "i" (port));			/* inputs */	   \
	} while (0)

#define	INW(data, port)							   \
	do {								   \
		__asm __volatile ("lw %0, %1($27)"	/* k1 = IO_BASE */ \
			: "=r" (data)			/* outputs */	   \
			: "i" (port));			/* inputs */	   \
	} while (0)

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

inline void
spi_start_transaction(void)
{

	OUTB(IO_SPI, 0);
}

inline void
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
	int tsc1, tsc2;

	do {
		INW(tsc1, IO_TSC);
		INW(tsc2, IO_TSC);
	} while (tsc2 != tsc1);
	return (tsc2);
}

#endif /* __ASSEMBLER__ */

#endif /* !_IO_H_ */

