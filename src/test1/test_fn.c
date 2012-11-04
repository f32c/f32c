
#include <sys/param.h>
#include <io.h>
#include <stdlib.h>
#include <stdio.h>


typedef int fn1_t(int, uint32_t *);
fn1_t fn1;

int
fn1(int a, uint32_t *p32)
{

#if 0
	__asm __volatile__(
		".set noreorder;"
		"addiu %0, %1, 1;"
		"sw %0, 0(%2);"
		"lw %0, 0(%2);"
		"addiu %0, %0, 1;"
		"sll %0, %0, 1;"
		"lw %0, 0(%2);"
		"addiu %0, %0, 1;"
		"sll %0, %0, 2;"
		"addiu %0, %0, 1;"
		"sll %0, %0, 3;"
		"addiu %0, %0, 1;"
		".set reorder;"
		: "=r" (a)
		: "r" (a), "r" (p32)
        );
#else
	volatile uint32_t *p = p32;

#if 0
	/* Ovo radi OK */
	for (int j = 0; j < a + 10; j++) {
		for (int i = 0; i < 131943; i++)
			*p += a + (*p >> 3);
	}
#else
	/* Ovo NE RADI! */
	for (int i = 0; i < 1321943; i++)
		*p += a + (*p >> 3);
#endif
	a += *p;
#endif
	
	return (a);
}
