#ifndef _TERMIOS_H_
#define _TERMIOS_H_

/* Input flags */
#define	INLCR	0x01
#define	IGNCR	0x02
#define	ICRNL	0x04
#define	ISTRIP	0x08
#define	IXON	0x10
#define	IXOFF	0x20

/* Output flags */
#define	OPOST	0x01
#define	ONLCR	0x02
#define	OCRNL	0x04

struct termios {
	uint8_t		c_iflags;	/* input processing config */
	uint8_t		c_oflags;	/* output processing config */
	uint8_t		c_lflags;	/* local processing config */
	uint8_t		iflags;		/* input processing active flags */
	uint8_t		oflags;		/* output processing active flags */
	uint8_t		lflags;		/* local processing active flags */
	uint8_t		rows;
	uint8_t		columns;
};

#endif /* !_TERMIOS_H_ */
