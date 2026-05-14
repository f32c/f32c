/*-
 * Copyright (c) 2013 - 2026 Marko Zec
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#include <sys/exec.h>

#include <dev/io.h>
#include <dev/spi.h>


void *sio_boot(void);

#define	FLASH_ADDR_INC	0x00010000
#define	FLASH_ADDR_LIM	0x00800000

#define	IO_SIO_DATA	(IO_SIO_0 + 0x0)
#define	IO_SIO_STATUS	(IO_SIO_0 + 0x4)
#define	IO_SIO_BAUD	(IO_SIO_0 + 0x8)

void
flash_byte(int out)
{
	uint32_t in;

	SB(out, SPI_DATA, IO_SPI_FLASH);
	do {
		LB(in, SPI_CTRL1, IO_SPI_FLASH);
	} while ((in & 1) == 0);
}

static void
flash_read_block(uint8_t *buf, uint32_t addr, uint32_t len)
{

	spi_slave_select(IO_SPI_FLASH, 0);
	spi_start_transaction(IO_SPI_FLASH);
	flash_byte(0x0b); /* High-speed read */
	flash_byte(addr >> 16);
	flash_byte(addr >> 8);
	flash_byte(addr);
	flash_byte(0xff); /* dummy byte, ignored */
	spi_block_in(IO_SPI_FLASH, buf, len);
}


static void
pchar(char c)
{
	int s;

	do {
		INB(s, IO_SIO_STATUS);
	} while (s & SIO_TX_BUSY);
	OUTB(IO_SIO_DATA, (c));
}


#ifndef ONLY_I_ROM
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
#else /* ONLY_I_ROM */
#define	puts(c)
#define	phex32(c)
#endif /* !ONLY_I_ROM */


static uint8_t
sio_getch()
{
	uint8_t c;

	do {
		INB(c, IO_SIO_STATUS);
	} while ((c & SIO_RX_FULL) == 0);
	INB(c, IO_SIO_DATA);
	return (c & 0xff);
}


static void *
sio_load_binary(void)
{
	uint32_t i, t;
	uint32_t crc = 0, base = 0, len = 0;
	char *cp;

	do {
		OUTB(IO_LED, (base) >> 10);
		i = sio_getch();
		switch (i) {
		case 0x80:	/* Set base addr */
			for (i = 0; i < 4; i++)
				base = (base << 8) + sio_getch();
			break;
		case 0x81:	/* Read crc */
			t = crc;
			for (i = 0; i < 4; i++) {
				pchar(t >> 24);
				t <<= 8;
			}
			break;
		case 0x90:	/* Set len = base */
			len = base;
			break;
		case 0x91:	/* Set crc = base */
			crc = base;
			break;
		case 0xa0:	/* Write block */
			cp = (void *) base;
			crc = 0;
			for (i = 0; i < len; i++) {
				crc = (crc >> 31) | (crc << 1);
				t = sio_getch();
				cp[i] = t;
				crc += t;
			}
			break;
		case 0xa1:	/* Read block */
			cp = (void *) base;
			crc = 0;
			for (i = 0; i < len; i++) {
				crc = (crc >> 31) | (crc << 1);
				t = cp[i];
				pchar(t);
				crc += t;
			}
			break;
		case 0xb0:	/* Set baudrate, abuse base as speed */
			if (base == 3000000)
				OUTB(IO_SIO_BAUD, 15);
			else if (base == 1000000)
				OUTB(IO_SIO_BAUD, 13);
			else if (base == 921600)
				OUTB(IO_SIO_BAUD, 12);
			else
				OUTB(IO_SIO_BAUD, 9); // 115200
			break;
		case 0xb1:	/* Done, jump to base */
			return ((void *) base);
			break;
		default:
			break;
		}
	} while (1);
}


static int
is_fat_volume(uint8_t *buf)
{
	int i;

	if (buf[0] != 0xeb || buf[2] != 0x90 ||
	    buf[0xb] != 0 || buf[0xc] != 0x10 ||
	    buf[0x1fe] != 0x55 || buf[0x1ff] != 0xaa)
		return (0);
	for (i = 0x92; i < 0x1fe; i++)
		if (buf[i] != 0)
			return (0);
	return (1);
}


static int
is_f32c_exec(uint8_t *buf)
{
	int32_t *longp = (void *) buf;
#ifdef __mips__
	int16_t *shortp = (void *) buf;
#endif

#ifdef __mips__
	if (longp[0] == 0x3c00f32c &&
	    shortp[3] == 0x3c10 && shortp[5] == 0x2610 &&
	    shortp[7] == 0x3c1b && shortp[9] == 0x277b &&
	    shortp[11] == 0x3c10 && shortp[13] == 0x2610 &&
	    shortp[15] == 0x3c11 && shortp[17] == 0x2631)
#else /* riscv */
	if (longp[0] == 0xf32c0037 &&
	    buf[4] == 0x37 && (buf[5] & 0xf) == 0x4 &&
	    buf[8] == 0x13 && buf[9] == 0x04 &&
	    buf[12] == 0x37 && (buf[13] & 0xf) == 0x2 &&
	    buf[16] == 0x13 && buf[17] == 0x02 &&
	    buf[20] == 0x37 && (buf[21] & 0xf) == 0x4 &&
	    buf[24] == 0x13 && buf[25] == 0x04 &&
	    buf[28] == 0xb7 && (buf[29] & 0xf) == 0x4 &&
	    buf[32] == 0x93 && buf[33] == 0x84)
#endif
		return (1);
	return (0);
}


void
main(void)
{
	uint8_t buf[512];
	uint8_t *cp = buf;
	int len, i, c, addr;
	char *start, *end;
	struct f32c_execinfo *f32c_eip = (void *) F32C_EXECINFO_ADDR;
	int verbose_boot = 1 << 21;
#ifdef __mips__
	int16_t *shortp = (void *) buf;
#else /* riscv */
	int32_t *longp = (void *) buf;
#endif

	/* Reset all CPU cores except CPU #0 */
	OUTW(IO_CPU_RESET, ~1);

	/* Check whether there are parameters for the loader at RAM_START */
	if (f32c_eip->cookie == F32C_EXECINFO_COOKIE && f32c_eip->tries++ == 0)
		verbose_boot = 0;

	/* Search for a FAT partition signature */
	for (addr = 0; addr < FLASH_ADDR_LIM; addr += FLASH_ADDR_INC) {
		if (verbose_boot)
			pchar('.');
		flash_read_block(buf, addr, sizeof(buf));
		if (!is_fat_volume(buf))
			continue;
		puts("\nFAT partition found at 0x");
		phex32(addr);

		/* Search for boot code in front of the FAT partition */
		do {
			if (verbose_boot)
				pchar('*');
			addr -= FLASH_ADDR_INC;
			flash_read_block(buf, addr, 40);
		} while (addr >= 0 && !is_f32c_exec(buf));
		break;
	}

	if (verbose_boot) {
		pchar('\r');
		pchar('\n');
	}

	if (addr < 0 || addr == FLASH_ADDR_LIM) {
		puts("Boot sector not found.\n");
		cp = sio_boot();
		if (cp == NULL)
			cp = sio_load_binary();
		goto boot;
	}

#ifndef ONLY_I_ROM
	puts("Boot code found at 0x");
	phex32(addr);
	puts("\n");
#endif

#ifdef __mips__
	start = (void *) ((shortp[2] << 16) + shortp[4]);
	end = (void *) ((shortp[14] << 16) + shortp[16]);
#else /* riscv */
	start = (void *) ((longp[1] & 0xfffff000) + (longp[2] >> 20));
	end = (void *) ((longp[7] & 0xfffff000) + (longp[8] >> 20));
#endif

	len = end - start;
	cp = (void *) start;
	puts("Loading at 0x");
	phex32((uint32_t) cp);
	puts(" len 0x");
	phex32(len);
	puts("\n\n");
	flash_read_block((void *) cp, addr, len);

	/* Wait briefly for an interrupt char from SIO */
	for (i = verbose_boot; i >= 0; i--) {
		OUTB(IO_LED, i >> 13);

		/* Check SIO RX buffer */
		INB(c, IO_SIO_STATUS);
		if (c & SIO_RX_FULL) {
			INB(c, IO_SIO_DATA);
			if (c == ' ')
				break;
		}
	}

	if (i > 0 || f32c_eip->cookie == F32C_EXECINFO_NOBOOT) {
		f32c_eip->cookie = 0;
		cp = sio_boot();
		if (cp == NULL)
			cp = sio_load_binary();
	}
	
boot:
	/* Turn off LEDs */
	OUTB(IO_LED, 0);

#ifdef __mips__
	__asm __volatile__(
		".set noreorder;"
		".set noat;"
		"move $1, %0;"
		"lui $4, 0x8000;"	/* stack mask */
		"lui $5, 0x1000;"	/* top of the initial stack */
		"and $29, %0, $4;"	/* clear low bits of the stack */

		"beqz $29, cache_skip;"	/* skip cache invalidate for BRAM */
		"li $2, 0x4000;"	/* max. I-cache size: 16 K */
		"icache_flush:;"
		"cache 0, 0($2);"
		"bnez $2, icache_flush;"
		"addiu $2, $2, -4;"
		"cache_skip:;"

		"or $29, $29, $5;"	/* set the stack pointer */
		"move $4, $0;"		/* clear a0 / argc */
		"move $5, $0;"		/* clear a1 / argv */
		"move $6, $0;"		/* clear a2 / envp */
		"jr $1;"
		"move $31, $0;"		/* return to ROM loader when done */
		".set at;"
		".set reorder;"
		:
		: "r" (cp)
	);
#else /* riscv */
	__asm __volatile__(
		"fence.i;"		/* flush I-cache */
		"move s2, %0;"		/* pull cp into s2 */
		"lui s0, 0x80000;"	/* stack mask */
		"lui s1, 0x10000;"	/* top of the initial stack */
		"and sp, s2, s0;"	/* clr low bits of the stack */
		"or sp, sp, s1;"	/* set stack */
		"mv a0, zero;"		/* clear argc */
		"mv a1, zero;"		/* clear argv */
		"mv a2, zero;"		/* clear envp */
		"mv ra, zero;"		/* return to ROM loader when done */
		"jr s2;"
		:
		: "r" (cp)
	);
#endif
}
