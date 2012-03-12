
#ifndef _SIO_H_
#define	_SIO_H_

extern void (*sio_idle_fn)(void);

int sio_getchar(int);
int sio_putchar(int, int);
void sio_setbaud(int);

#endif /* !_IO_H_ */

