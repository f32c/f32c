
#include <types.h>
#include <sdcard.h>
#include <spi.h>
#include <stdio.h>


int
main(void)
{
	int i, j, res;
	char buf[SDCARD_BLOCK_SIZE];

	printf("\n");

	printf("sdcard_init()\n");
	res = sdcard_init();
	if (res) {
		printf("sdcard_init() returned %d\n", res);
		return (1);
	}

	res = sdcard_cmd(SDCARD_CMD_SEND_CSD, 0);
	if (res) {
		printf("sdcard_cmd(9, 0) returned %d\n", res);
		return (1);
	}
	printf("CMD9: %d\n", sdcard_read(buf, 32));

	res = sdcard_cmd(SDCARD_CMD_SEND_CID, 0);
	if (res) {
		printf("sdcard_cmd(10, 0) returned %d\n", res);
		return (1);
	}
	printf("CMD10: %d\n", sdcard_read(buf, 32));

	printf("CMD16:\n");
	res = sdcard_cmd(SDCARD_CMD_SET_BLOCKLEN, SDCARD_BLOCK_SIZE);
	if (res) {
		printf("sdcard_cmd(16, %d) returned %d\n", SDCARD_BLOCK_SIZE, res);
		return (1);
	}

	for (i = 0; i < 2047 * (1 << 20); i += SDCARD_BLOCK_SIZE) {
		res = sdcard_cmd(SDCARD_CMD_READ_BLOCK, i);
		if (res) {
			printf("sdcard_cmd(17, %d) returned %d\n", i, res);
			return (1);
		}
		sdcard_read(buf, 512);
#if 1
		for (j = 0; j < SDCARD_BLOCK_SIZE; j++)
			if (buf[j] >= 32 && buf[j] < 127)
				putchar(buf[j]);
#else
		if ((i & 0xffe00) == 0)
			printf("CMD17 %08x\n", i);
#endif
		j = sio_getchar(0);
		if (j == 3)
			break;
		if (j == ' ')
			do {} while (sio_getchar(0) != ' ');
	}

	printf("Done\n");

	return (0);
}
