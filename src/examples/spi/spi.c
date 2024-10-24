/*
 * Scan SPI ports and report responses from attached devices
 */

#include <stdio.h>

#include <dev/io.h>
#include <dev/spi.h>

#define	SPI_CMD_REMS		0x90	/* Macronix */
#define	SPI_CMD_JEDEC_ID	0x9F	/* JEDEC standard */
#define	SPI_CMD_RDID		0xab	/* Microchip */

#define	SPI_PORTS	2

static const int spi_port[SPI_PORTS] = {
	IO_SPI_0,
#if SPI_PORTS > 1
	IO_SPI_1,
#endif
#if SPI_PORTS > 2
	IO_SPI_2,
#endif
#if SPI_PORTS > 3
	IO_SPI_3,
#endif
};

#define	SPI_MFR_CYPRESS		0x01
#define	SPI_MFR_FUJITSU		0x04
#define	SPI_MFR_ONSEMI		0x62
#define	SPI_MFR_PUYA		0x85
#define	SPI_MFR_ISSI		0x9d
#define	SPI_MFR_MICROCHIP	0xbf
#define	SPI_MFR_MACRONIX	0xc2
#define	SPI_MFR_WINBOND		0xef

static const struct jedec_mfr {
	uint8_t	id;
	char	*name;
} jedec_mfr_tbl[] = {
	{SPI_MFR_CYPRESS,	"Cypress / Infineon"},
	{SPI_MFR_FUJITSU,	"Fujitsu"},
	{SPI_MFR_ONSEMI,	"Onsemi"},
	{SPI_MFR_PUYA,		"PUYA"},
	{SPI_MFR_ISSI,		"ISSI"},
	{SPI_MFR_MICROCHIP,	"SST / Microchip"},
	{SPI_MFR_MACRONIX,	"Macronix"},
	{SPI_MFR_WINBOND,	"Winbond"},
	{0, "Unknown"}
};

#define	SPI_QUIRK_CAPACITY_1R	(1 << 0) /* shift cap right 1 bit */
#define	SPI_QUIRK_CAPACITY_10L	(1 << 1) /* shift cap left 10 bits */
#define	SPI_QUIRK_FLAT		(1 << 2) /* flat / sectorless addressing */

static const uint8_t spi_quirks[] = {
	SPI_MFR_CYPRESS,
		0x02,	/* S25FL032P / S25FL064P */
			SPI_QUIRK_CAPACITY_1R,
		0,	/* SPI_MFR_CYPRESS quirks end */
	SPI_MFR_FUJITSU,
		0x7f,	/* MB85RS4MTY */
			SPI_QUIRK_CAPACITY_10L | SPI_QUIRK_FLAT,
		0,	/* SPI_MFR_FUJITSU quirks end */
	0
};

static const char *
mfrid_to_str(int mfrid)
{
	int i;

	for (i = 0; jedec_mfr_tbl[i].id != mfrid
	    && jedec_mfr_tbl[i].id != 0; i++) {}

	return (jedec_mfr_tbl[i].name);
}

void
main(void)
{
	int i, j, port;
	int mfrid, devid, capid;
	int mfr_i, dev_i, quirk_i;
	const uint8_t *qp;
	int cap;

	for (i = 0; i < SPI_PORTS; i++) {
		port = spi_port[i];
		printf("Probing SPI port #%d @ 0x%08x:\n", i, port);
		spi_start_transaction(port);
		spi_byte(port, SPI_CMD_JEDEC_ID);
		mfrid = spi_byte(port, 0);
		if (mfrid == 0) {
			spi_start_transaction(port);
			spi_byte(port, SPI_CMD_REMS);
			for (j = 0; j < 3; j++)
				spi_byte(port, 0);
			mfrid = spi_byte(port, 0);
		}
		if (mfrid == 0)
			continue;
		devid = spi_byte(port, 0);
		capid = spi_byte(port, 0);
		cap = 1 << (capid & 0x1f);
		printf("  mfr 0x%02x (%s)", mfrid, mfrid_to_str(mfrid));
		printf(" dev 0x%02x cap 0x%02x", devid, capid);

		for (qp = spi_quirks; *qp != 0; qp++) {
			mfr_i = *qp++;
			for (dev_i = *qp++; *qp != 0; qp++) {
				quirk_i = *qp;
				if (mfr_i != mfrid || dev_i != devid)
					continue;
				if (quirk_i & SPI_QUIRK_CAPACITY_1R)
					cap >>= 1;
				if (quirk_i & SPI_QUIRK_CAPACITY_10L)
					cap <<= 10;
			}
		}
		printf(" (%d Bytes)\n", cap);
	}
}
