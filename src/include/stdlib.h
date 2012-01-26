
#ifndef _STDLIB_H_
#define	_STDLIB_H_

#include <types.h>


uint32_t random(void);
int atoi(const char *);

#define	exit(x)								\
	do {								\
		__asm __volatile ("j 0");				\
	} while (0);

#endif /* !_STDLIB_H_ */
