#ifndef _TERMIOS_H_
#define _TERMIOS_H_

/* Input flags */
#define	INLCR	0x01
#define	IGNCR	0x02
#define	ICRNL	0x04
#define	ISTRIP	0x08
#define	IXON	0x10
#define	IXOFF	0x20

/* Local flags */
#define	ISIG	0x01

/* Output flags */
#define	OPOST	0x01
#define	ONLCR	0x02
#define	OCRNL	0x04

/* Special control characters */

#define	VEOF	0	/* CTRL-D */
#define	VINTR	1	/* CTRL-C */
#define	VERASE	2	/* CTRL-H */
#define	VSUSP	3	/* CTRL-S */
#define	NCCS	4

struct termios {
	uint8_t		c_iflags;	/* input config */
	uint8_t		c_oflags;	/* output config */
	uint8_t		c_cflags;	/* control config */
	uint8_t		c_lflags;	/* local config */
	uint8_t		c_cc[NCCS];	/* control chars */
};

#endif /* !_TERMIOS_H_ */
