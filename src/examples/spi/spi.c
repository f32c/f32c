/*
 * Scan SPI ports and report responses from attached devices
 */

#include <stdio.h>
//#include <string.h>

#include <dev/io.h>
#include <dev/spi.h>

#define	SPI_CMD_REMS		0x90	/* Macronix */
#define	SPI_CMD_JEDEC_ID	0x9F	/* JEDEC standard */
#define	SPI_CMD_RDID		0xab	/* Microchip */

#define	SPI_PORTS	4

static const int spi_port[SPI_PORTS] = {
	IO_SPI_0, IO_SPI_1, IO_SPI_2, IO_SPI_3,
};

static const struct jedec_mfg {
	uint8_t	id;
	char	*name;
} jedec_mfg_tbl[] = {
	{0x01, "Cypress / Infineon"},
	{0x62, "SST / Microchip"},
	{0x85, "PUYA"},
	{0x9d, "ISSI"},
	{0xbf, "SST / Microchip"},
	{0xc2, "Macronix"},
	{0xef, "Winbond"},
	{0, "Unknown"}
};


static const char *
mfgid_to_str(int mfgid)
{
	int i;

	for (i = 0; jedec_mfg_tbl[i].id != mfgid
	    && jedec_mfg_tbl[i].id != 0; i++) {}

	return (jedec_mfg_tbl[i].name);
}

void
main(void)
{
	int i, j, port;
	int mfgid, dev, cap;

	for (i = 0; i < SPI_PORTS; i++) {
		port = spi_port[i];
		printf("Probing SPI port #%d @ 0x%08x:\n", i, port);
		spi_start_transaction(port);
		spi_byte(port, SPI_CMD_JEDEC_ID);
		mfgid = spi_byte(port, 0);
		if (mfgid == 0) {
			spi_start_transaction(port);
			spi_byte(port, SPI_CMD_REMS);
			for (j = 0; j < 3; j++)
				spi_byte(port, 0);
			mfgid = spi_byte(port, 0);
		}
		if (mfgid == 0)
			continue;
		printf("  vendor 0x%02x (%s)", mfgid, mfgid_to_str(mfgid));
		dev = spi_byte(port, 0);
		printf(" type 0x%02x", dev);
		cap = spi_byte(port, 0);
		printf(" capacity 0x%02x (%d Bytes)\n", cap,
		    0x10000 << (cap & 0xf));
	}
}
