
#include <types.h>
#include <sdcard.h>
#include <spi.h>
#include <stdio.h>


static void
read_spi(int n)
{
	unsigned char buf[16];
	int i, j;

	for (i = 0; i < n; i++) {
		buf[i & 0xf] = spi_byte_in(SPI_PORT_SDCARD);
		if ((i & 0xf) == 0xf) {
			for (j = 0; j < 15; j++) {
				printf("%02x ", buf[j]);
			}
			printf("  ");
			for (j = 0; j < 15; j++) {
				if (buf[j] >= 31 && buf[j] < 127)
					putchar(buf[j]);
				else
					putchar('.');
			}
			printf("\n");
		}
	}
}


int
main(void)
{
	int res;

	printf("\n");

	res = sdcard_init();
	if (res) {
		printf("sdcard_init() returned %d\n", res);
		return (1);
	}

	res = sdcard_cmd(9, 0);
	if (res) {
		printf("sdcard_cmd(9, 0) returned %d\n", res);
		return (1);
	}
	printf("CMD09:\n");
	read_spi(32);

	res = sdcard_cmd(10, 0);
	if (res) {
		printf("sdcard_cmd(10, 0) returned %d\n", res);
		return (1);
	}
	printf("CMD10:\n");
	read_spi(32);

	res = sdcard_cmd(58, 0);
	if (res) {
		printf("sdcard_cmd(58, 0) returned %d\n", res);
		return (1);
	}
	printf("CMD58:\n");
	read_spi(32);

	res = sdcard_cmd(17, 0);
	if (res) {
		printf("sdcard_cmd(17, 0) returned %d\n", res);
		return (1);
	}
	printf("CMD17:\n");
	read_spi(1024);

	printf("Done\n");

	return (0);
}
