
#include <io.h>
#include <sio.h>
#include <types.h>
#include <stdio.h>


/* Host -> board commands */
#define	FP_CMD_READID		1
#define	FP_CMD_ERASE_CHIP	2
#define	FP_CMD_ERASE_SECTORS	3
#define	FP_CMD_READ_SECTOR	4
#define	FP_CMD_WRITE_SECTOR	5
#define	FP_CMD_SET_BAUD		6
#define	FP_CMD_DONE		7

#define	FP_START_MARK		0x7e81

#define	FP_PAGESIZE		4096

#define	FP_MAX_BLOCKSIZE	(sizeof(struct fp_header) + FP_PAGESIZE)

typedef struct fp_header {
	uint16_t	start_mark;
	uint8_t		fp_cmd;
	uint8_t		fp_res;
	uint32_t	payload_csum;
	uint16_t	payload_len;
	uint16_t	header_csum;
} fph_t;


static char buf[FP_MAX_BLOCKSIZE];


#define	rxbyte()	getchar()
#define	txbyte(x)	putchar(x)


static int
rx_frame(void)
{
	char *cp;
	char c;
	fph_t *fphp = (fph_t *) buf;
	int csum;

	cp = buf;
	fphp = (fph_t *) buf;
	fphp->start_mark = FP_START_MARK;
	
	do {
		c = rxbyte();

		/* Detect start of record marker */
		if (cp < &buf[2]) {
			if (cp == &buf[0] && c == buf[0])
				cp++;
			else if (cp == &buf[1]) {
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
				csum += *cp;
			if (csum != ntohs(fphp->header_csum))
				return (-1);
			cp = &buf[sizeof(*fphp)];
		}

	} while (cp < &buf[sizeof(*fphp) + ntohs(fphp->payload_len)]);

	/* Payload checksum OK? */
	for (csum = 0; cp > &buf[sizeof(*fphp)];)
		csum += *--cp;
	if (csum != ntohl(fphp->payload_csum))
		return (-1);
	else
		return(0);
}


static void
tx_frame(void)
{
	char *cp;
	fph_t *fphp = (fph_t *) buf;
	int csum;
	int i;

	fphp->start_mark = FP_START_MARK;

	/* Compute payload checksum */
	for (csum = 0, cp = &buf[sizeof(*fphp)];
	    cp < &buf[sizeof(*fphp) + fphp->payload_len]; cp++)
		csum += *cp;
	fphp->payload_csum = csum;

	/* Compute header checsum */
	for (csum = 0, cp = buf; cp < (char *) &fphp->header_csum; cp++)
		csum += *cp;
	fphp->header_csum = csum;

	/* Send it */
	for (cp = buf; cp < &buf[sizeof(*fphp) + fphp->payload_len]; cp++)
		txbyte(*cp);

	/* Send a few padding bytes, just in case */
	for (i = 0; i < 4; i++)
		txbyte(0);
}


int
main(void)
{

	tx_frame();
	rx_frame();

	return (0);
}
