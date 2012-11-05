
#include <sys/param.h>
#include <io.h>
#include <stdlib.h>
#include <stdio.h>


typedef int fn1_t(int, uint32_t *);
fn1_t fn1;

int
fn1(int a, uint32_t *p32)
{

#if 1
	volatile uint32_t *p = p32;

	/* Ovo radi krivo iz SRAM-a bez (utreniranog) branch predictora */
	/* fix: r1094 */
	for (int i = 0; i < 3; i++)
		*p += a + (*p >> 3);
#endif

#if 0
	/* Ne cancelira se bnel delay slot */
	/* fix: r1095 */
	__asm __volatile (
		".set noreorder;"
		"li %0, 0;"
		"bnel $0, $0, 1f;"
		"li %0, 1;"
		"addiu %0, %0, 0x10;"
		"1:;"
		"addiu %0, %0, 0x100;"
		".set reorder;"
		: "=r" (a)
		: "r" (a), "r" (p32)
        );
#endif

#if 0
	/* Ne cancelira se instrukcija iza beql delay slota */
	/* fix: r1095 */
	__asm __volatile (
		".set noreorder;"
		"li %0, 0;"
		"beql $0, $0, 1f;"
		"li %0, 1;"
		"addiu %0, %0, 0x10;"
		"1:;"
		"addiu %0, %0, 0x100;"
		".set reorder;"
		: "=r" (a)
		: "r" (a), "r" (p32)
        );
#endif

	return (a);
}
