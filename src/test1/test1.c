
#ifndef XXX
#include <io.h>
#include <types.h>
#endif
#include <stdio.h>


extern void pcm_play(void);


int
main(void)
{
	int i = 0;
	int c, cnt;
	
	/* Register PCM output function as idle loop handler */
	sio_idle_fn = pcm_play;

	c = 0;
	for (i = 0; i <= 100; i++) {
		putchar('\r');
		if (i == 2 || i == 100)
			c = rdtsc() - c;
	}
	if (c < 0)
		c = -c;
	/*
	 * 150.0 MHz c = 13358	div = 1302
	 * 133.3 MHz c = 15026  div = 1157
	 *  75.0 MHz c = 26713  div = 651
	 *  66.7 MHz c = 30056  div = 579
	 *  25.0 MHz c = 80151  div = 217
	 *  12.5 MHz c = xxxxx  div = 109
	 */
	for (i = 0, cnt = 0; i < 100; i += c)
		cnt += 217;

	printf("\nc = %d\n", c);
	printf("cnt = %d\n", cnt);
	printf("div = %d\n", cnt >> 10);

	printf("\n\n f32c CPU running at %d MHz\n", 2003550000 / c);

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

		c = getchar();

		/* Exit to bootloader on CTRL+C */
		if (c == 3)
			return(0);

		putchar(c);
	}

	return (0);
}
