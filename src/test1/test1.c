
#ifndef XXX
#include <io.h>
#include <types.h>
#endif
#include <stdio.h>


extern void pcm_play(void);


int
main(void)
{
	int c, cnt;
	int *tsc = (int *) 0x000001fc;
	
	/* Register PCM output function as idle loop handler */
	sio_idle_fn = pcm_play;


	/*
	 *  12.5 MHz tsc = 62508 div =  106
	 *  25.0 MHz tsc = 31254 div =  211
	 *  75.0 MHz tsc = 10418 div =  632
	 * 150.0 MHz tsc =  5209 div = 1264
	 */

	for (cnt = 0, c = '\r'; cnt < 100000; cnt++) {
		if (c == '\r' || c == '\n') {

			printf("\n");
			printf("Hello, world!\n");
			printf("\n\n f32c CPU running at %d Hz\n",
			    (75000000 / *tsc) * 10418);
			printf("\n\n tsc = %d\n", *tsc);
			printf("  %%\n");
			c = 0;
			printf("  s: %s (null %s)\n", "Hello, world!",
			    (char *) c);
			printf("  c: %c\n", '0' + (cnt & 0x3f));
			printf("  d: cnt = %d (neg %d)\n", cnt, -cnt);
			printf(" 8d: cnt = %8d (neg %8d)\n", cnt, -cnt);
			printf("08d: cnt = %08d (neg %08d)\n", cnt, -cnt);
			printf("  u: cnt = %u (neg %u)\n", cnt, -cnt);
			printf("  x: cnt = %x (neg %x)\n", cnt, -cnt);
			printf(" 8x: cnt = %8x (neg %8x)\n", cnt, -cnt);
			printf("08x: cnt = %08x (neg %08x)\n", cnt, -cnt);
			printf("  p: cnt = %p (neg %p)\n", (void *) cnt,
			    (void *) -cnt);
			printf("  o: cnt = %o (neg %o)\n", cnt, -cnt);
		}

		c = getchar();

		/* Exit to bootloader on CTRL+C */
		if (c == 3)
			return(0);

		putchar(c);

		if (c == 'r')
			for (c = 0; c < 10000; c++)
				putchar('.');
	}

	return (0);
}
