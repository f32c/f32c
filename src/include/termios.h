#ifndef _TERMIOS_H_
#define _TERMIOS_H_

/*
 * Input flags - software input processing
 */
#define	IGNBRK		0x0001	/* ignore BREAK condition */
#define	BRKINT		0x0002	/* map BREAK to SIGINTR */
#define	IGNPAR		0x0004	/* ignore (discard) parity errors */
#define	PARMRK		0x0008	/* mark parity and framing errors */
#define	INPCK		0x0010	/* enable checking of parity errors */
#define	ISTRIP		0x0020	/* strip 8th bit off chars */
#define	INLCR		0x0040	/* map NL into CR */
#define	IGNCR		0x0080	/* ignore CR */
#define	ICRNL		0x0100	/* map CR to NL (ala CRMOD) */
#define	IXON		0x0200	/* enable output flow control */
#define	IXOFF		0x0400	/* enable input flow control */

/*
 * Control flags - hardware control of terminal
 */
#define	CIGNORE		0x0001	/* ignore control flags */
#define	CSIZE		0x0030	/* character size mask */
#define	CS7		0x0010	/* 7 bits */
#define	CS8		0x0020	/* 8 bits */
#define	CSTOPB		0x0040	/* send 2 stop bits */
#define	CREAD		0x0080	/* enable receiver */
#define	PARENB		0x0100	/* parity enable */
#define	PARODD		0x0200	/* odd parity, else even */
#define	HUPCL		0x0400	/* hang up on last close */
#define	CLOCAL		0x0800	/* ignore modem status lines */

/*
 * "Local" flags - dumping ground for other state
 */
#define	ECHOKE		0x0001	/* visual erase for line kill */
#define	ECHOE		0x0002	/* visually erase chars */
#define	ECHOK		0x0004	/* echo NL after line kill */
#define	ECHO		0x0008	/* enable echoing */
#define	ECHONL		0x0010	/* echo NL even if ECHO is off */
#define	ECHOPRT		0x0020	/* visual erase mode for hardcopy */
#define	ECHOCTL		0x0040	/* echo control chars as ^(Char) */
#define	ISIG		0x0080	/* enable signals INTR, QUIT, [D]SUSP */
#define	ICANON		0x0100	/* canonicalize input lines */
#define	ALTWERASE	0x0200	/* use alternate WERASE algorithm */
#define	IEXTEN		0x0400	/* enable DISCARD and LNEXT */
#define	EXTPROC		0x0800	/* external processing */
#define	TOSTOP		0x1000	/* stop background jobs from output */
#define	NOKERNINFO	0x2000	/* no kernel output from VSTATUS */
#define	NOFLSH		0x4000	/* don't flush after interrupt */

/* Output flags */
#define	OPOST		0x0001
#define	ONLCR		0x0002
#define	OCRNL		0x0004

/* Special control characters */
#define	VEOF	0	/* ICANON, CTRL-D */
#define	VEOL	1	/* ICANON */
#define	VINTR	2	/* ISIG, CTRL+C */
#define	VSUSP	3	/* ISIG, CTRL+Z */
#define	VKILL	4	/* ICANON, CTRL+U */
#define	VERASE	5	/* ICANON, CTRL-H */
#define	VMIN	6	/* !ICANON */
#define	VTIME	7	/* !ICANON */
#define	NCCS	8

struct termios {
	uint16_t	c_iflag;	/* input config */
	uint16_t	c_oflag;	/* output config */
	uint16_t	c_cflag;	/* control config */
	uint16_t	c_lflag;	/* local config */
	uint8_t		c_cc[NCCS];	/* control chars */
};

struct winsize {
	uint8_t		ws_row;		/* rows, in characters */
	uint8_t		ws_col;		/* columns, in characters */
};

#endif /* !_TERMIOS_H_ */
