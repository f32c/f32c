
#ifndef _STDIO_H_
#define	_STDIO_H_

#include <sio.h>


#define	getchar()	sio_getchar(1)
#define	putchar(c)	sio_putchar(c, 1)

int	printf(const char * __restrict, ...) __attribute__((format (printf, 1, 2)));
int	gets(char *, int);

#endif /* !_STDIO_H_ */
