
#include <types.h>
#include <sdcard.h>
#include <stdio.h>


void
main(void)
{

	printf("\ncalling sdcard_init()\n");

	printf("sdcard_init() returned %d \n", sdcard_init());

	printf("Done\n");
}
