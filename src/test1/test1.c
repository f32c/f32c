
#ifndef XXX
#include <io.h>
#include <sio.h>
#include <types.h>
#endif
#include <stdio.h>


int
main(void)
{
#if 0
	int wav_stream_locked = 0;
	int pcm_out = 0;
#endif
	int i = 0;
	int c, cnt, led = 0x69;
	
	cnt = rdtsc();

	for (i = 0; i < 100000; i++)
		c = rdtsc();

	c -= cnt;
	if (c < 0)
		c = -c;
	printf("\n\n f32c CPU running at %d MHz\n", i * 1005 / c / 40);

#if 0
	OUTB(IO_LED, 0xf0);
	spi_stop_transaction();
	/* SPI: Read JEDEC ID */
	spi_start_transaction();
	spi_byte(0x9f);	/* JEDEC Read-ID */
	printf("%02x", spi_byte(0) & 0xff);
	printf("%02x", spi_byte(0) & 0xff);
	printf("%02x\n\n", spi_byte(0) & 0xff);
	spi_stop_transaction();

	/* SPI: Read a few bytes, starting at addr 0x000000 */
	spi_start_transaction();
	spi_byte(0x0b);	/* High-speed read */
	spi_byte(0x0);
	spi_byte(0x0);
	spi_byte(0x0);
	spi_byte(0x0);
	for (c = 0; c < 16; c++) {
		for (i = 0; i < 4; i++)
			printf("%02x", spi_byte(0) & 0xff);
		printf("\n");
	}
	spi_stop_transaction();

	/* SPI: Poll status */
	spi_start_transaction();
	spi_byte(0x05); /* RDSR */
	printf("%02x\n\n", spi_byte(0) & 0xff);
	spi_stop_transaction();

	/* SPI: Send WREN command */
	spi_start_transaction();
	spi_byte(0x06); /* WREN */
	spi_stop_transaction();

	/* SPI: Poll status */
	spi_start_transaction();
	spi_byte(0x05); /* RDSR */
	printf("%02x\n\n", spi_byte(0) & 0xff);
	spi_stop_transaction();

	/* SPI: Send AAI word-program command, starting at addr 0x000000 */
	spi_start_transaction();
	spi_byte(0xad); /* AAI */
	spi_byte(0x0);
	spi_byte(0x0);
	spi_byte(0x0);
	/* SPI: Send two dummy bytes */
	spi_byte(0x2);
	spi_byte(0x3);
	spi_stop_transaction();

	do {
		c = getchar();
		pcm_out <<= 8;
		pcm_out |= (c & 0xff);
		if (!wav_stream_locked) {
			/* Search for the "WAVE" pattern */
			if (pcm_out == 0x57415645) {
				wav_stream_locked = 1;
				OUTB(IO_LED, 0x0f);
				/* SPI: store two dummy bytes */
				spi_start_transaction();
				spi_byte(0xad); /* AAI */
				spi_byte(0x0);
				spi_byte(0x1);
				spi_stop_transaction();
			}
			continue;
		}

		/* Terminate AAI write sequence */
		spi_start_transaction();
		spi_byte(0x04); /* WRDI */
		spi_stop_transaction();
		OUTB(IO_LED, 0xff);

		i += 1;
		if (i == 4) {
			/* Byte swapping */
			pcm_out = ((pcm_out >> 8) & 0x00ff00ff) |
			    ((pcm_out << 8) & 0xff00ff00);
			pcm_out = pcm_out ^ 0x80008000;
			OUTW(IO_PCM, pcm_out);
			i = 0;
		}
	} while (1);

	cnt = 0;
	do {
		i = c;
		c = getchar();
		if (i == c)
			cnt++;
		else
			cnt = 0;
	} while (cnt < 5);

	return (0);
}
#endif

#if 1
	for (cnt = 0, c = '\r'; cnt < 100; cnt++) {

		if (c == '\r' || c == '\n') {
			printf("\n");
			printf("Hello, world!\n");
			printf("  %%\n");
			printf("  s: %s (null %s)\n", "Hello, world!", NULL);
			printf("  c: %c\n", '0' + (cnt & 0x3f));
			printf("  d: cnt = %d (neg %d)\n", cnt, -cnt);
			printf(" 8d: cnt = %8d (neg %8d)\n", cnt, -cnt);
			printf("08d: cnt = %08d (neg %08d)\n", cnt, -cnt);
			printf("  u: cnt = %u (neg %u)\n", cnt, -cnt);
			printf("  y: cnt = %y (neg %y)\n", cnt, -cnt);
			printf("  x: cnt = %x (neg %x)\n", cnt, -cnt);
			printf(" 8x: cnt = %8x (neg %8x)\n", cnt, -cnt);
			printf("08x: cnt = %08x (neg %08x)\n", cnt, -cnt);
			printf("  p: cnt = %p (neg %p)\n", cnt, -cnt);
			printf("  o: cnt = %o (neg %o)\n", cnt, -cnt);
			printf("  b: cnt = %b (neg %b)\n", cnt, -cnt);
		}

#if 0
		vol = 100;
		pcm_out = 0x4000;
		for (c = 0; c < 30000; c++) {
			pcm_out = -pcm_out;
			i = (c / 5000) + 9;
			if (vol != i) {
				vol = i;
				printf("Vol: %d\n", i);
				i = getchar();
				/* Exit to bootloader on CTRL+C */
				if (i == 3)
					return(0);
			}
			i = (((pcm_out << 16) + 0x80000000) >> (vol + 16)) & 0xffff;
			OUTW(IO_PCM, i + (i << 16));
			i = rdtsc();
			do {
				j = rdtsc() - i;
				if (j < 0)
					j = -j;
			} while (j < 40000);
		}
continue;
		printf("Done.\n");
#endif

		do {
			c = i - rdtsc();
			if (c < 0)
				c = -c;
			if (c > 1000000) {
				led ^= 0xff;
				OUTB(IO_LED, led);
				i = rdtsc();
			}
			c = sio_getchar(0);
		} while (c < 0);

		/* Exit to bootloader on CTRL+C */
		if (c == 3)
			return(0);

		putchar(c);
	}
}
#endif
