
#ifndef X
#include <io.h>
#include <sio.h>
#include <types.h>
#else
#include <sys/types.h>
#include <ftdi.h>
#include <fcntl.h>
#endif
#include <stdio.h>


/* Host -> board commands */
#define	FP_CMD_READID		1
#define	FP_CMD_ERASE_CHIP	2
#define	FP_CMD_ERASE_SECTORS	3
#define	FP_CMD_READ_SECTOR	4
#define	FP_CMD_WRITE_SECTOR	5
#define	FP_CMD_SET_BAUD		6
#define	FP_CMD_DONE		7

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
#ifdef FTDI
static struct ftdi_context fc;  /* USB port handle */
static int
rxbyte(void)
{
	char b, res;
	
	do {
		res = ftdi_read_data(&fc, &b, 1);
	} while (res != 1);
	return(b);
}
#else
static int
rxbyte(void)
{
	char b, res;
	
	do {
		res = read(sioid, &b, 1);
	} while (res != 1);
	return(b);
}
#endif
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

#ifdef FTDI
	ftdi_usb_purge_buffers(&fc);
#endif

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
#ifdef FTDI
	ftdi_write_data(&fc, buf, len);
#else
	write(sioid, buf, len);
#endif
#endif

}


#ifndef X
int
main(void)
{
	int error;
	fph_t *fphp = (fph_t *) buf;

	/* Set baudrate */
//	OUTW(IO_SIO + 2, 632); /* 115200 */
//	OUTW(IO_SIO + 2, 316); /* 230400 */
	OUTW(IO_SIO + 2, 158); /* 460800 */
//	OUTW(IO_SIO + 2, 79); /* 921600 */
//	OUTW(IO_SIO + 2, 47); /* 1500000 */
//	OUTW(IO_SIO + 2, 23); /* 3000000 */

	do {
		error = rx_frame();
		OUTB(IO_LED, error);

		fphp->fp_cmd = 123;
		fphp->fp_res = error;
		fphp->payload_len = 4;
		tx_frame();
	} while (1);

	return (0);
}
#endif

#ifdef X
int
main(void)
{
	int i, j, error;
	int *ip;
	fph_t *fphp = (fph_t *) buf;

	error = system("stty -f /dev/cuaU0.init cs8 -parenb speed 115200 -crtscts clocal -cstopb -onlcr -opost -inlcr -igncr -icrnl -ixon -ixoff -echo -echoe -echoke -echoctl");
        if (error < 0)
                return (error);
	sioid = open("/dev/cuaU0", O_RDWR|O_NONBLOCK|O_DIRECT|O_TTY_INIT);
        if (sioid < 0)
                return (sioid);
#ifdef FTDI
	close(sioid);
	ftdi_init(&fc);
        error = ftdi_usb_open_desc(&fc, 0x0403, 0x6001,
            "FER ULXP2 board JTAG / UART", NULL);
        if (error < 0)
                return (error);
	ftdi_set_baudrate(&fc, 460800);
	ftdi_set_line_property(&fc, BITS_8, STOP_BIT_2, NONE);
	ftdi_set_latency_timer(&fc, 1);
#endif

	i = 0;
	do {
		ip = (int *) &buf[(sizeof *fphp)];
		for (j = 0; j < 1024; j++)
			*ip++ = random();
		ip = (int *) &buf[(sizeof *fphp)];
		*ip = i + 10000;

		fphp->fp_cmd = FP_CMD_READID;
		fphp->fp_addr = i++;
		fphp->payload_len = 4096;
		tx_frame();
		*ip = 0;

		error = rx_frame();
		if (error) {
			fprintf(stderr, "rx_frame() failed\n");
			return(1);
		}
		ip = (int *) &buf[(sizeof *fphp)];
		printf("fp_cmd: %d\n", fphp->fp_cmd);
		printf("fp_res: %d\n", fphp->fp_res);
		printf("fp_addr: %d\n", fphp->fp_addr);
		printf("seq: %d\n", *ip);
	} while (fphp->fp_res == 0);

	return (0);
}
#endif
