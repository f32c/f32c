
#include <types.h>
#include <sdcard.h>
#include <stdio.h>


void
main(void)
{

	printf("sdcard_init() returned %d \n", sdcard_init());

	printf("Done\n");
}
