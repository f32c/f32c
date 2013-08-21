
#ifndef _SDCARD_H_
#define	_SDCARD_H_

#include <sys/stdint.h>

int sdcard_init(void);
int sdcard_cmd(int, uint32_t);

int sdcard_disk_initialize(void);
int sdcard_disk_status(void);
int sdcard_disk_read(uint8_t *, uint32_t, uint32_t);
int sdcard_disk_write(uint8_t *, uint32_t, uint32_t);

#define	SD_CMD_GO_IDLE_STATE		0
#define	SD_CMD_SEND_OP_COND		1
#define	SD_CMD_SEND_IF_COND		8
#define	SD_CMD_SEND_CSD			9
#define	SD_CMD_SEND_CID			10
#define	SD_CMD_STOP_TRANSMISSION	12
#define	SD_CMD_SET_BLOCKLEN		16
#define	SD_CMD_READ_BLOCK		17
#define	SD_CMD_READ_MULTI_BLOCK		18
#define	SD_CMD_WRITE_BLOCK		24
#define	SD_CMD_WRITE_MULTI_BLOCK	25
#define	SD_CMD_APP_CMD			55
#define	SD_CMD_READ_OCR			58

/* ACMD commands which require SD_CMD_APP_CMD prefix */
#define	SD_CMD_SET_WR_BLOCK_ERASE_COUNT	23
#define	SD_CMD_APP_SEND_OP_COND		41

#define	SD_BLOCKLEN			512

#endif /* !_SDCARD_H_ */

