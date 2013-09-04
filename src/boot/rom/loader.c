
#include <sys/param.h>

#include <spi.h>
#include <stdio.h>


#define	SRAM_BASE	0x80000000
#define	SRAM_TOP	0x80100000
#define	LOADER_BASE	0x800f8000


#if _BYTE_ORDER == _BIG_ENDIAN
static const char *msg = "ULX2S ROM bootloader v 0.1 (f32c/be)\n";
#else
static const char *msg = "ULX2S ROM bootloader v 0.1 (f32c/le)\n";
#endif


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


static void
pchar(char c)
{
	int s;

	do {
		INB(s, IO_SIO_STATUS);
	} while (s & SIO_TX_BUSY);
	OUTB(IO_SIO_BYTE, (c));
}


static void
phex(uint8_t c)
{
	int hc = (((c) >> 4) & 0xf) + '0';

	if (hc > '9')
		hc += 'a' - '9' - 1;
	pchar(hc);
	hc = ((c) & 0xf) + '0';
	if (hc > '9')
		hc += 'a' - '9' - 1;
	pchar(hc);
}


static void
phex32(uint32_t c)
{

	phex(c >> 24);
	phex(c >> 16);
	phex(c >> 8);
	phex(c);
}


static void
puts(const char *cp)
{

	for (; *cp != 0; cp++) {
		if (*cp == '\n')
			pchar('\r');
		pchar(*cp);
	}
}


void
main(void)
{
	uint8_t *cp = (void *) LOADER_BASE;
	int *p;
	int res_sec, sec_size, len, i;

	puts(msg);

	/* Turn off video framebuffer, just in case */
	OUTW(IO_FB, 3);

	/* SRAM init & self-test */
	for (i = -1; i <= 0; i++) {
		/* memset() SRAM */
		for (p = (int *) SRAM_BASE; p < (int *) SRAM_TOP; p++)
			*p = i;

		/* check SRAM */
		for (p = (int *) SRAM_BASE; p < (int *) SRAM_TOP; p++)
			if (*p != i) {
				puts("SRAM BIST failed\n");
				return;
			}
	}
	puts("SRAM BIST passed\n");

	flash_read_block((void *) cp, 0, 512);
	sec_size = (cp[0xc] << 8) + cp[0xb];
	res_sec = (cp[0xf] << 8) + cp[0xe];
	if (cp[0x1fe] != 0x55 || cp[0x1ff] != 0xaa || sec_size != 4096
	    || res_sec < 2) {
		puts("Invalid boot sector\n");
		return;
	}

	len = sec_size * res_sec - 512;
	flash_read_block((void *) cp, 512, len);
	puts("Boot block loaded from SPI flash at 0x");
	phex32((uint32_t) cp);
	puts(" len 0x");
	phex32(len);
	puts("\n\n");

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
}
