
#include <io.h>
#include <types.h>
#include <stdio.h>


extern void pcm_play(void);

int val = 0x12345678;


int
main(void)
{
	int c, cnt;
	int tsc;
	
	/* Register PCM output function as idle loop handler */
	sio_idle_fn = pcm_play;

	for (cnt = 0, c = '\r'; cnt < 100000; cnt++) {
		if (c == '\r' || c == '\n') {

			tsc = rdtsc();
			printf("\nHello, world!\n");
			printf("\n f32c CPU running at ");
			tsc = rdtsc() - tsc;
			if (tsc < 0)
				tsc = -tsc;

			/* XXX constant derived from 115200 bps */
			printf("%d Hz\n", 920237 / tsc);

			printf("\n tsc = %d\n", tsc);
			printf("val = %08x\n", val);
			printf("  %%\n");
			printf("  s: %s\n", "Hello, world!");
			printf("  c: %c\n", '0' + (cnt & 0x3f));
			printf("  d: cnt = %d (neg %d)\n", cnt, -cnt);
			printf(" 8d: cnt = %8d (neg %8d)\n", cnt, -cnt);
			printf("08d: cnt = %08d (neg %08d)\n", cnt, -cnt);
			printf("  u: cnt = %u (neg %u)\n", cnt, -cnt);
			printf("  x: cnt = %x (neg %x)\n", cnt, -cnt);
			printf(" 8x: cnt = %8x (neg %8x)\n", cnt, -cnt);
			printf("08x: cnt = %08x (neg %08x)\n", cnt, -cnt);
			printf("  o: cnt = %o (neg %o)\n", cnt, -cnt);
			printf("  p: cnt = %p\n", &cnt);
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
