
#ifndef _STDLIB_H_
#define	_STDLIB_H_


double strtod(const char * __restrict, char ** __restrict);
long strtol(const char * __restrict, char ** __restrict, int);
unsigned long strtoul(const char * __restrict, char ** __restrict, int);

#define rand() random()
uint32_t random(void);
void srand(unsigned);

int atoi(const char *);

void *malloc(size_t size);
void *realloc(void *ptr, size_t size);
void free(void *ptr);

#define RAND_MAX        0x7fffffff

char    *getenv(const char *);

/* XXX exit() works only on CPU #0 - fixme! */
#define	exit(x)								\
	do {								\
		__asm __volatile ("jr $0; nop");			\
	} while (0);

#endif /* !_STDLIB_H_ */
