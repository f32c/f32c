
#ifndef XXX
#include <io.h>
#include <sio.h>
#include <stdio.h>
#include <types.h>
#else
#include <stdio.h>
#define sio_getchar() getchar()
#define sio_putchar(c) putchar(c)
#endif


int
main(void)
{
	int cnt = 0;
	int c;
	
	do {
		c = sio_getchar();

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
			cnt++;
			continue;
		}

		sio_putchar(c);
	} while (cnt < 100);
}

