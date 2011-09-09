
#include <io.h>
#include <types.h>
#include <stdio.h>
#include <stdlib.h>


void sram_wr(int a, int d)
{

	a <<= 2;

	__asm(
		".set noreorder\n"
		"lui	$3, 0x8000\n"
		"addu	$3, $3, %1\n"
		"sw %0, 0($3)\n"
		"sw %0, 0($3)\n"
		"sw %0, 0($3)\n"
		".set reorder\n"
		:
		: "r" (d), "r" (a)
	);
}


int sram_rd(int a)
{
	int r;

	a <<= 2;

	__asm(
		".set noreorder\n"
		"lui	$3, 0x8000\n"
		"addu	$3, $3, %1\n"
		"lw %0, 0($3)\n"
		"lw %0, 0($3)\n"
		"lw %0, 0($3)\n"
		"lw %0, 0($3)\n"
		".set reorder\n"
		: "=r" (r)
		: "r" (a)
	);

	return (r);
}


int atoi(const char *buf)
{
	int i = 0;
	const char *c;

	for (c = buf; *c != '\0'; c++) {
		if (*c >= '0' && *c <= '9') {
			i = i * 10 + (*c - '0');
		} else
			break;
	}

	return (i);
}


#define BUFSIZE 64
#define	MEMSIZE 5000
#define MEM_OFFSET 333333

char buf[BUFSIZE];
uint16_t ibuf[MEMSIZE];


int
main(void)
{
	int i, j;
	
	for (i = 0; i < MEMSIZE; i++) {
		sram_wr(i + MEM_OFFSET, random());
	}
	for (i = 0; i < MEMSIZE; i++) {
		sram_wr(i + MEM_OFFSET, i);
	}
	for (i = 0; i < MEMSIZE; i++) {
		ibuf[i] = sram_rd(i + MEM_OFFSET);
	}
	for (i = 0; i < MEMSIZE; i++) {
		if (ibuf[i] != i)
			printf("%d: %d\n", i, ibuf[i]);
	}
	printf("\n");

	do {
		printf("Enter RD addr: ");
		if (gets(buf, BUFSIZE) != 0)
			return (0);	/* Got CTRL + C */
		i = atoi(buf);
		printf("sram(%06d): %08x\n", i, sram_rd(i));

		printf("Enter WR addr: ");
		if (gets(buf, BUFSIZE) != 0)
			return (0);	/* Got CTRL + C */
		i = atoi(buf);
		printf("Enter WR data: ");
		if (gets(buf, BUFSIZE) != 0)
			return (0);	/* Got CTRL + C */
		j = atoi(buf);
		sram_wr(i, j);
	} while (1);

}
