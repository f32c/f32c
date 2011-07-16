
#ifndef X
#include <io.h>
#include <sio.h>
#include <types.h>
#else
#include <sys/types.h>
#include <fcntl.h>
#endif
#include <stdio.h>


/* Host -> board commands */
#define	FP_CMD_READID		1
#define	FP_CMD_READ_SECTOR	2
#define	FP_CMD_CSUM_SECTOR	3
#define	FP_CMD_CSUM_CHIP	4
#define	FP_CMD_ENABLE_WRITE	5
#define	FP_CMD_DISABLE_WRITE	6
#define	FP_CMD_ERASE_CHIP	7
#define	FP_CMD_ERASE_SECTOR	8
#define	FP_CMD_WRITE_SECTOR	9
#define	FP_CMD_SET_BAUD		10
#define	FP_CMD_DONE		11

#define	FP_START_MARK		0x817e

#define	FP_PAGESIZE		4096

#define	FP_MAX_BLOCKSIZE	(sizeof(struct fp_header) + FP_PAGESIZE)

typedef struct fp_header {
	uint16_t	start_mark;
	uint8_t		fp_cmd;
	uint8_t		fp_res;
	uint32_t	fp_addr;
	uint32_t	payload_csum;
	uint16_t	payload_len;
	uint16_t	header_csum;
} fph_t;


static char buf[FP_MAX_BLOCKSIZE + 8];


#ifndef X
#define	rxbyte()	getchar()
#define	txbyte(x)	putchar(x)
#else
static int sioid;
static int
rxbyte(void)
{
	char b, res;
	
	do {
		res = read(sioid, &b, 1);
		if (res == 0)
			usleep(10000);
	} while (res != 1);
	return(b);
}
#endif


static int
rx_frame(void)
{
	char *cp;
	char c;
	fph_t *fphp = (fph_t *) buf;
	uint32_t csum;

	cp = buf;
	fphp->start_mark = FP_START_MARK;
	
	do {
		c = rxbyte();

		/* Detect start of record marker */
		if (cp < &buf[2]) {
			if (cp == &buf[0] && c == buf[0]) {
				cp++;
			} else if (cp == &buf[1]) {
				if (c == buf[1])
					cp++;
				else 
					cp = buf;
			}
			continue;
		}
		*cp++ = c;

		/* Header complete?  Header checksum OK? */
		if (cp == &buf[sizeof(*fphp)]) {
			for (csum = 0, cp = buf;
			    cp < (char *) &fphp->header_csum; cp++)
				csum += (*cp & 0xff);
			if (csum != fphp->header_csum)
				return (-1);
			if (fphp->payload_len > FP_PAGESIZE)
				return (-2);
			cp = &buf[sizeof(*fphp)];
		}

	} while (cp < &buf[sizeof(*fphp) + fphp->payload_len]);

	/* Payload checksum OK? */
	for (csum = 0; cp > &buf[sizeof(*fphp)];)
		csum += (*--cp & 0xff);
	if (csum != fphp->payload_csum)
		return (-3);
	else
		return(0);
}


static void
tx_frame(void)
{
	char *cp;
	fph_t *fphp = (fph_t *) buf;
	int csum, len;
	int i;

	fphp->start_mark = FP_START_MARK;

	/* Compute payload checksum */
	for (csum = 0, cp = &buf[sizeof(*fphp)];
	    cp < &buf[sizeof(*fphp) + fphp->payload_len]; cp++)
		csum += (*cp & 0xff);
	fphp->payload_csum = csum;

	/* Compute header checsum */
	for (csum = 0, cp = buf; cp < (char *) &fphp->header_csum; cp++)
		csum += (*cp & 0xff);
	fphp->header_csum = csum;

	/* Compute frame length, and add a few dummy trailer bytes */
	len = sizeof(*fphp) + fphp->payload_len;
	for (i = 0; i < 4; i++, len++)
		buf[len] = 0;

	/* Send it */
#ifndef X
	for (cp = buf; cp < &buf[len]; cp++)
		txbyte(*cp);
#else
	write(sioid, buf, len);
#endif

}


#ifndef X
static void
dispatch(void)
{
	fph_t *fphp = (fph_t *) buf;
	int error = 0;
	int i;
	char *cp;

	/* Check that the device is idle before issuing next command */
	spi_stop_transaction();
	spi_start_transaction();
	spi_byte(0x05); /* RDSR */
	do {} while (spi_byte(0x05) & 1);
	spi_stop_transaction();
	OUTB(IO_LED, rdtsc());

	switch (fphp->fp_cmd) {
	case FP_CMD_READID:
		/* SPI: Read JEDEC ID */
		spi_start_transaction();
		spi_byte(0x9f); /* JEDEC Read-ID */
		for (i = 0, cp = &buf[sizeof(*fphp)]; i < 3; i++)
			*cp++ = spi_byte(0);
		spi_stop_transaction();
		fphp->payload_len = 3;
		break;

	case FP_CMD_ENABLE_WRITE:
		spi_start_transaction();
		spi_byte(0x50); /* EWSR */
		spi_stop_transaction();

		spi_start_transaction();
		spi_byte(0x01); /* WRSR */
		spi_byte(0);	/* Clear write-protect bits */
		spi_stop_transaction();

		fphp->payload_len = 0;
		break;

	case FP_CMD_DISABLE_WRITE:
		spi_start_transaction();
		spi_byte(0x50); /* EWSR */
		spi_stop_transaction();

		spi_start_transaction();
		spi_byte(0x01); /* WRSR */
		spi_byte(0x1c);	/* Set write-protect bits */
		spi_stop_transaction();

		fphp->payload_len = 0;
		break;

	case FP_CMD_ERASE_CHIP:
		spi_start_transaction();
		spi_byte(0x06); /* WREN */
		spi_stop_transaction();

		spi_start_transaction();
		spi_byte(0x60); /* Chip-erase */
		spi_stop_transaction();

		spi_start_transaction();
		spi_byte(0x05); /* RDSR */
		do {} while (spi_byte(0x05) & 1);
		spi_stop_transaction();

		spi_start_transaction();
		spi_byte(0x04); /* WRDI */
		spi_stop_transaction();

		fphp->payload_len = 0;
		break;

	case FP_CMD_WRITE_SECTOR:

		if (fphp->payload_len != FP_PAGESIZE) {
			fphp->payload_len = 0;
			error = -1;
			break;
		};
		cp = &buf[sizeof(*fphp)];

		spi_start_transaction();
		spi_byte(0x06); /* WREN */
		spi_stop_transaction();

		spi_start_transaction();
		spi_byte(0x20); /* Sector erase */
		spi_byte(fphp->fp_addr >> 16);
		spi_byte(fphp->fp_addr >> 8);
		spi_byte(fphp->fp_addr);
		spi_stop_transaction();

		spi_start_transaction();
		spi_byte(0x05); /* RDSR */
		do {} while (spi_byte(0x05) & 1);
		spi_stop_transaction();

		spi_start_transaction();
		spi_byte(0x06); /* WREN */
		spi_stop_transaction();

#if 1
		spi_start_transaction();
		spi_byte(0xad); /* AAI write mode */
		spi_byte(fphp->fp_addr >> 16);
		spi_byte(fphp->fp_addr >> 8);
		spi_byte(fphp->fp_addr);
		spi_byte(*cp++);
		spi_byte(*cp++);
		spi_stop_transaction();

		for (i = 2; i < FP_PAGESIZE; i++) {

			spi_start_transaction();
			spi_byte(0x05); /* RDSR */
			do {} while (spi_byte(0x05) & 1);
			spi_stop_transaction();

			spi_start_transaction();
			spi_byte(0xad); /* AAI write mode */
			spi_byte(*cp++);
			spi_byte(*cp++);
			spi_stop_transaction();
		}
#else
		int j;
		for (i = 0; i < FP_PAGESIZE; i++) {
			spi_start_transaction();
			spi_byte(0x02); /* Byte program */
			j = fphp->fp_addr + i;
			spi_byte(j >> 16);
			spi_byte(j >> 8);
			spi_byte(j);
			spi_byte(*cp++);
			spi_stop_transaction();
		}
#endif

		spi_start_transaction();
		spi_byte(0x05); /* RDSR */
		do {} while (spi_byte(0x05) & 1);
		spi_stop_transaction();

		spi_start_transaction();
		spi_byte(0x04); /* WRDI */
		spi_stop_transaction();

		spi_start_transaction();
		spi_byte(0x05); /* RDSR */
		do {} while (spi_byte(0x05) & 1);
		spi_stop_transaction();

		spi_start_transaction();
		spi_byte(0x0b); /* High-speed read */
		spi_byte(0);
		spi_byte(0);
		spi_byte(0);
		spi_byte(0);
		spi_byte(0);
		spi_byte(0);
		spi_byte(0);
		spi_byte(0);
		spi_byte(0);
		spi_byte(0);
		spi_byte(0);
		spi_stop_transaction();

		fphp->payload_len = 0;
		break;

	default:
		error = -1;
		fphp->payload_len = 0;
		break;
	}

	fphp->fp_res = error;
	tx_frame();
}


int
main(void)
{
	int error;
	fph_t *fphp = (fph_t *) buf;

	/* Set baudrate - divisors valid for 75 MHz main clock */
//	OUTW(IO_SIO + 2, 632);	/*  115200 */
//	OUTW(IO_SIO + 2, 316);	/*  230400 */
	OUTW(IO_SIO + 2, 158);	/*  460800 */
//	OUTW(IO_SIO + 2, 78);	/*  921600 */
//	OUTW(IO_SIO + 2, 47);	/* 1500000 */
//	OUTW(IO_SIO + 2, 35);	/* 2000000 */
//	OUTW(IO_SIO + 2, 23);	/* 3000000 */

	do {
		error = rx_frame();
		if (error) {
			fphp->fp_res = error;
			fphp->payload_len = 0;
			tx_frame();
			continue;
		}

		dispatch();
	} while (1);

	return (0);
}
#endif

#ifdef X
int
main(int argc, char *argv[])
{
	int i, j, error, maxpages = 0;
	fph_t *fphp = (fph_t *) buf;
	char *cp;
	int f;

	/* XXX replace with cfmakeraw() and tcsetattr() */
	error = system("stty -f /dev/cuaU0.init cs8 raw speed 460800 >/dev/null");
        if (error < 0)
                return (error);
	sioid = open("/dev/cuaU0", O_RDWR|O_NONBLOCK|O_DIRECT|O_TTY_INIT);
        if (sioid < 0)
                return (sioid);

	if (argc < 2) {
		fprintf(stderr, "Must provide file name\n");
		return(1);
	}
	f = open(argv[1], O_RDONLY);
	if (f < 0) {
		fprintf(stderr, "cannot open file %s\n", argv[1]);
		return(1);
	}

	fphp->fp_cmd = FP_CMD_READID;
	fphp->fp_addr = 0;
	fphp->payload_len = 0;
	tx_frame();
	if (rx_frame()) {
		fprintf(stderr, "FP_CMD_READID: rx_frame() failed\n");
		return(1);
	}
	if (fphp->fp_res) {
		fprintf(stderr, "FP_CMD_READID failed\n");
		return(1);
	}
	cp = &buf[sizeof(*fphp)];
	printf("JEDEC ID:");
	for (i = 0; i < fphp->payload_len; i++)
		printf(" %02x", *cp++ & 0xff);
	printf("\n");
	if ((*--cp & 0xff) == 0x4a)
		maxpages = 1024;
	else
		maxpages = 512;
maxpages = 1024;

	fphp->fp_cmd = FP_CMD_ENABLE_WRITE;
	fphp->fp_addr = 0;
	fphp->payload_len = 0;
	tx_frame();
	if (rx_frame()) {
		fprintf(stderr, "FP_CMD_ENABLE_WRITE: rx_frame() failed\n");
		return(1);
	}
	if (fphp->fp_res) {
		fprintf(stderr, "FP_CMD_ENABLE_WRITE failed\n");
		return(1);
	}
	printf("Write mode enabled\n");

	for (i = 0; i < maxpages; i++) {
		fphp->fp_cmd = FP_CMD_WRITE_SECTOR;
		fphp->fp_addr = i * FP_PAGESIZE;
		fphp->payload_len = FP_PAGESIZE;

		j = read(f, &buf[sizeof(*fphp)], FP_PAGESIZE);
		if (j != FP_PAGESIZE)
			break;

		printf("Writing page %d\n", i);

		tx_frame();
		if (rx_frame()) {
			fprintf(stderr,
			    "FP_CMD_WRITE_SECTOR: rx_frame() failed\n");
			return(1);
		}
		if (fphp->fp_res) {
			fprintf(stderr, "FP_CMD_WRITE_SECTOR failed\n");
			return(1);
		}
	}
	printf("Wrote %d pages\n", i);

	fphp->fp_cmd = FP_CMD_DISABLE_WRITE;
	fphp->fp_addr = 0;
	fphp->payload_len = 0;
	tx_frame();
	if (rx_frame()) {
		fprintf(stderr, "FP_CMD_DISABLE_WRITE: rx_frame() failed\n");
		return(1);
	}
	if (fphp->fp_res) {
		fprintf(stderr, "FP_CMD_DISABLE_WRITE failed\n");
		return(1);
	}
	printf("Write mode disabled\n");

	return (0);
}
#endif
