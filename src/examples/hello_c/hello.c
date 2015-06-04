/*
 * Print a message on serial console and blink LEDs until a button is pressed.
 *
 * $Id$
 */

#include <stdio.h>
#include <string.h>
#include <io.h>

#ifdef __mips__
static const char *arch = "mips";
#elif defined(__riscv__)
static const char *arch = "riscv";
#else
static const char *arch = "unknown";
#endif

#define	BTN_ANY	(BTN_CENTER | BTN_UP | BTN_DOWN | BTN_LEFT | BTN_RIGHT)


void
main(void)
{
	int i;
	volatile uint8_t *sdram = (void *) 0x80000000;
	volatile uint32_t *sdram32 = (void *) 0x80000000;

	printf("Hello, f32c/%s world!\n", arch);

	for (i = 0; i < 256; i++)
		sdram[i] = i;

	sdram32[0] = 0xFFFFFFFF;
	sdram32[1] = 0x00000000;
	sdram32[2] = 0x11111111;
	sdram32[3] = 0x88888888;

	for (i = 0; i < 4; i++) {
		printf("%08x ", sdram32[i]);
		printf("%08x ", sdram32[i]);
	}
	printf("\n");

	for (i = 0; i < 256; i++)
		if (i & 0xf)
			printf("%02x ", sdram[i]);
		else
			printf("\n%02x ", sdram[i]);
	printf("\n");
}
