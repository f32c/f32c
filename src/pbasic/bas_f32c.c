
#include <sys/param.h>

#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <fatfs/ff.h>

#include <io.h>
#include <spi.h>

#include "bas.h"


#define	SRAM_BASE	0x80000000
#define	LOADER_BASE	0x800f8000

#define	LOAD_COOKIE	0x10adc0de
#define	LOADADDR	SRAM_BASE


static void
flash_read_block(char *buf, uint32_t addr, uint32_t len)
{

	spi_start_transaction(SPI_PORT_FLASH);
	spi_byte(SPI_PORT_FLASH, 0x0b); /* High-speed read */
	spi_byte(SPI_PORT_FLASH, addr >> 16);
	spi_byte(SPI_PORT_FLASH, addr >> 8);
	spi_byte(SPI_PORT_FLASH, addr);
	spi_byte(SPI_PORT_FLASH, 0xff); /* dummy byte, ignored */
	spi_block_in(SPI_PORT_FLASH, buf, len);
}


int
bauds(void)
{
	int bauds;

	bauds = evalint();
	check();
	if (bauds < 300 || bauds > 3000000)
		error(33);	/* argument error */
	sio_setbaud(bauds);
	normret;
}


int
bas_sleep(void)
{
	uint64_t start, end, now;
	int c;

	start = tsc_hi;
	start = (start << 32) + tsc_lo;

	evalreal();
	check();
	if (res.f < ZERO)
		error(33);	/* argument error */
	end = start + (uint64_t) (res.f * 1000.0 * freq_khz);

	do {
		now = tsc_hi;
		now = (now << 32) + tsc_lo;
		c = sio_getchar(0);
	} while (c != 3 && now <= end);

	if (c == 3)
		trapped = 1;
	normret;
}


int
bas_exec(void)
{
	char name[128];
	STR st;
	uint32_t *up = (void *) SRAM_BASE;
	uint8_t *cp = (void *) LOADER_BASE;
	int res_sec, sec_size, len;

	st = stringeval();
	NULL_TERMINATE(st);
	strcpy(name, st->strval);
	FREE_STR(st);
	check();
	if (open(name, O_RDONLY) < 0)
		error(15);

	*up = LOAD_COOKIE;
	strcpy((void *) &up[1], name);
	printf("Executing %s\n", (char *) &up[1]);

	flash_read_block((void *) cp, 0, 512);
	sec_size = (cp[0xc] << 8) + cp[0xb];
	res_sec = (cp[0xf] << 8) + cp[0xe];
	if (cp[0x1fe] != 0x55 || cp[0x1ff] != 0xaa || sec_size != 4096
	    || res_sec < 2) {
		printf("Invalid boot sector\n");
		error(15);
	}

	len = sec_size * res_sec - 512;
	flash_read_block((void *) cp, 512, len);

	__asm __volatile__(
		".set noreorder;"
		"lui $4, 0x8000;"       /* stack mask */
		"lui $5, 0x0010;"       /* top of the initial stack */
		"and $29, %0, $4;"      /* clear low bits of the stack */
		"move $31, $0;"         /* return to ROM loader when done */
		"jr %0;"
		"or $29, $29, $5;"      /* set the stack pointer */
		".set reorder;"
		:
		: "r" (cp)
	);

	/* Actually, not reached */
	normret;
}
