
#define	_ioctl(fd, cmd, arg) fcntl((fd), (cmd), (arg))
#define	ioctl(fd, cmd, arg) _ioctl((fd), (cmd), (arg))

#define	IOCTL_MAJOR_MASK	0xFF00
#define	IOCTL_TERMIOS		0x0100

#define	IOCTL_TIOC(i)		(IOCTL_TERMIOS | (i))

#define	TIOCGETA		IOCTL_TIOC(0x01)
#define	TIOCSETA		IOCTL_TIOC(0x02)
#define	TIOCSETAF		IOCTL_TIOC(0x03)
#define	TIOCSETAW		IOCTL_TIOC(0x04)

int termios_ioctl(struct file *, int, long);
