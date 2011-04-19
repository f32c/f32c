
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
#define	FP_CMD_ERASE_CHIP	5
#define	FP_CMD_ERASE_SECTOR	6
#define	FP_CMD_WRITE_SECTOR	7
#define	FP_CMD_SET_BAUD		8
#define	FP_CMD_DONE		9

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
	int csum;

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

	/* Just in case we got here w/o proper SPI init */
	spi_stop_transaction();

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
main(void)
{
	int i, j, error;
	fph_t *fphp = (fph_t *) buf;
	char *cp;

	/* XXX replace with cfmakeraw() and tcsetattr() */
	error = system("stty -f /dev/cuaU0.init cs8 raw speed 460800 >/dev/null");
        if (error < 0)
                return (error);
	sioid = open("/dev/cuaU0", O_RDWR|O_NONBLOCK|O_DIRECT|O_TTY_INIT);
        if (sioid < 0)
                return (sioid);

	fphp->fp_cmd = FP_CMD_READID;
	fphp->fp_addr = 0;
	fphp->fp_addr++;
	fphp->payload_len = 0;
	tx_frame();

	error = rx_frame();
	if (error) {
		fprintf(stderr, "rx_frame() failed\n");
		return(1);
	}
#if 0
	printf("fp_cmd: %d\n", fphp->fp_cmd);
	printf("fp_res: %d\n", fphp->fp_res);
	printf("fp_addr: %d\n", fphp->fp_addr);
#endif
	cp = &buf[sizeof(*fphp)];
	printf("JEDEC ID:");
	for (i = 0; i < fphp->payload_len; i++)
		printf(" %02x", *cp++ & 0xff);
	printf("\n");

	return (0);
}
#endif
