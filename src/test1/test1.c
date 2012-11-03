
#include <sys/param.h>
#include <io.h>
#include <stdlib.h>
#include <stdio.h>


typedef int fn1_t(int, uint32_t *);
fn1_t fn1;

void
main(void)
{
	uint8_t *p8;
	uint16_t *p16;
	uint32_t *p32, *fn1_rom;
	fn1_t *fn1_ram;
	int i;

	printf("\nuint8_t *:  ");
	p8 = (void *) 0x80000000;
	for (i = 0; i < 32; i++, p8 += 333)
		*p8 = i;
	p8 = (void *) 0x80000000;
	for (i = 0; i < 32; i++, p8 += 333)
		printf("%d ", *p8);
	printf("\n");

	printf("uint16_t *: ");
	p16 = (void *) 0x80000000;
	for (i = 0; i < 32; i++, p16 += 333)
		*p16 = i;
	p16 = (void *) 0x80000000;
	for (i = 0; i < 32; i++, p16 += 333)
		printf("%d ", *p16);
	printf("\n");

	printf("uint32_t *: ");
	p32 = (void *) 0x80000000;
	for (i = 0; i < 32; i++, p32 += 333)
		*p32 = i;
	p32 = (void *) 0x80000000;
	for (i = 0; i < 32; i++, p32 += 333)
		printf("%d ", *p32);
	printf("\n");

	/* Kopiraj fn1() iz BRAM u SRAM */
	fn1_rom = (void *) &fn1;
        fn1_ram = (void *) 0x80001000;
        p32 = (void *) fn1_ram;
	for (i = 0; i < 512; i++)
		*p32++ = *fn1_rom++;

	/* Izvedi fn1() u BRAM */
        p32 = (void *) 0x80000000;
	*p32 = 0;
	printf("BRAM: %08x\n", *p32);
	i = fn1(1, p32);
	printf("%08x %08x\n", i, *p32);

	/* Izvedi fn1() u SRAM */
        p32 = (void *) 0x80000000;
	*p32 = 0;
	printf("SRAM: %08x\n", *p32);
#if 0
	printf("Prebaci sw(2) i sw(3) u '1' (tocno tim redom)!\n");
	do {
		INB(i, IO_PUSHBTN + 1);
	} while ((i & 0xc) != 0xc);
#endif
	i = fn1_ram(1, p32);
	printf("%08x %08x\n", i, *p32);
}

int
fn1(int a, uint32_t *p32)
{

	a += *p32 + 0x100;
	*p32 = a++;
	return (a);
}
