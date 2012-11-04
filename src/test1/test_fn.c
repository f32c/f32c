
#include <sys/param.h>
#include <io.h>
#include <stdlib.h>
#include <stdio.h>


typedef int fn1_t(int, uint32_t *);
fn1_t fn1;

int
fn1(int a, uint32_t *p32)
{
	volatile uint32_t *p = p32;

	/* Ovo radi krivo bez (utreniranog) branch predictora */
	for (int i = 0; i < 3; i++)
		*p += a + (*p >> 3);
	return (a);
}
