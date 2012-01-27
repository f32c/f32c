
#ifndef _SDCARD_H_
#define	_SDCARD_H_

int sdcard_init(void);
int sdcard_read(char *, int);
int sdcard_cmd(int , uint32_t);

#define	SDCARD_CMD_GO_IDLE_STATE	0
#define	SDCARD_CMD_SEND_OP_COND		1
#define	SDCARD_CMD_SEND_IF_COND		8
#define	SDCARD_CMD_SEND_CSD		9
#define	SDCARD_CMD_SEND_CID		10
#define	SDCARD_CMD_SET_BLOCKLEN		16
#define	SDCARD_CMD_READ_BLOCK		17
#define	SDCARD_CMD_READ_MULTI_BLOCK	18
#define	SDCARD_CMD_WRITE_BLOCK		24
#define	SDCARD_CMD_WRITE_MULTI_BLOCK	25

#define	SDCARD_CMD_APP_CMD		55
#define	SDCARD_CMD_APP_SEND_OP_COND	41

#define	SDCARD_BLOCK_SIZE		512

#endif /* !_SDCARD_H_ */

