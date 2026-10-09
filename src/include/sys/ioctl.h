
#ifndef _SYS_IOCTL_H_
#define _SYS_IOCTL_H_

//#define	_ioctl(fd, cmd, arg) fcntl(fd, cmd, arg)
//#define	ioctl(fd, cmd, ...) fcntl(fd, cmd, ...)

#if 0
#define	IOCTL_MAJOR_MASK	0xFF00
#define	IOCTL_TERMIOS		0x0100

#define	IOCTL_TIOC(i)		(IOCTL_TERMIOS | (i))
#endif

int termios_ioctl(struct file *, int, long);

#endif /* !_SYS_IOCTL_H_ */
