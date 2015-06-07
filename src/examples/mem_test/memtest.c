/*
 * Write and read back random patterns to / from memory.
 */

#include <stdio.h>
#include <stdlib.h>
#include <io.h>

#include <mips/asm.h>
#include <mips/cpuregs.h>

extern int _end;


int
main(void)
{
	volatile int *mem_base = &_end;
	volatile int *mem_end;
	int i, len, speed, iter, tot_err;
	int size, tmp, freq_khz, start, end, seed, val;
	volatile uint8_t *p8;
	volatile uint16_t *p16;
	volatile uint32_t *p32;

	mfc0_macro(tmp, MIPS_COP_0_CONFIG);
	freq_khz = ((tmp >> 16) & 0xfff) * 1000 / ((tmp >> 29) + 1);
	printf("Detected %d.%03d MHz CPU\n\n",
	    freq_khz / 1000, freq_khz % 1000);

	if (mem_base < (int *) 0x80000000)
		mem_base = (int *) 0x80000000;
	mem_end = mem_base;

	/* Attempt to guess memory size */
	do {
		mem_end = &mem_end[65536];
		*mem_end = 0xdeadbeef;
		*mem_base = 0;
	} while (*mem_end != 0 && mem_end < (int *) 0xb0000000);
	mem_end = (int *) (((int) mem_end) & 0xfff80000);
	size = (int) mem_end - (int) mem_base;
	
	printf("base %p end %p (size %d.%03d MB)\n", mem_base, mem_end,
	    size >> 20, ((size & 0xfffff) * 1000) >> 20);

	iter = 0;
	tot_err = 0;

again:
	RDTSC(seed);

	val = seed;
	RDTSC(start);
	for (p8 = (uint8_t *) mem_base; p8 < (uint8_t *) mem_end;
	    val += 0x137b5d51) {
		*p8++ = val; *p8++ = val; *p8++ = ~val; *p8++ = ~val;
		*p8++ = val; *p8++ = val; *p8++ = ~val; *p8++ = ~val;
		*p8++ = val; *p8++ = val; *p8++ = ~val; *p8++ = ~val;
		*p8++ = val; *p8++ = val; *p8++ = ~val; *p8++ = ~val;
	}
	RDTSC(end);
	len = (end - start) / freq_khz;
	speed = size / len;
	printf("8-bit write done in %d.%03d s (%d.%03d MB/s)\n",
	    len / 1000, len % 1000, speed / 1000, speed % 1000);
	
	RDTSC(start);
	for (p8 = (uint8_t *) mem_base; p8 < (uint8_t *) mem_end;) {
		val = *p8++; val = *p8++; val = *p8++; val = *p8++;
		val = *p8++; val = *p8++; val = *p8++; val = *p8++;
		val = *p8++; val = *p8++; val = *p8++; val = *p8++;
		val = *p8++; val = *p8++; val = *p8++; val = *p8++;
	}
	RDTSC(end);
	len = (end - start) / freq_khz;
	speed = size / len;
	printf("8-bit read done in %d.%03d s (%d.%03d MB/s), ",
	    len / 1000, len % 1000, speed / 1000, speed % 1000);
	val = seed;
	tmp = 0;
	for (p8 = (uint8_t *) mem_base; p8 < (uint8_t *) mem_end; 
	    val += 0x137b5d51)
		for (i = 0; i < 16; i++)
			if ((i & 2) == 0) {
				if (*p8++ != (val & 0xff))
					tmp++;
			} else {
				if (*p8++ != ((~val) & 0xff))
					tmp++;
			}
	printf("%d errors\n", tmp);
	tot_err += tmp;
	
	val = seed;
	RDTSC(start);
	for (p16 = (uint16_t *) mem_base; p16 < (uint16_t *) mem_end;
	    val += 0x137b5d51) {
		*p16++ = val; *p16++ = ~val; *p16++ = val; *p16++ = ~val;
		*p16++ = val; *p16++ = ~val; *p16++ = val; *p16++ = ~val;
		*p16++ = val; *p16++ = ~val; *p16++ = val; *p16++ = ~val;
		*p16++ = val; *p16++ = ~val; *p16++ = val; *p16++ = ~val;
	}
	RDTSC(end);
	len = (end - start) / freq_khz;
	speed = size / len;
	printf("16-bit write done in %d.%03d s (%d.%03d MB/s)\n",
	    len / 1000, len % 1000, speed / 1000, speed % 1000);
	
	RDTSC(start);
	for (p16 = (uint16_t *) mem_base; p16 < (uint16_t *) mem_end;) {
		val = *p16++; val = *p16++; val = *p16++; val = *p16++;
		val = *p16++; val = *p16++; val = *p16++; val = *p16++;
		val = *p16++; val = *p16++; val = *p16++; val = *p16++;
		val = *p16++; val = *p16++; val = *p16++; val = *p16++;
	}
	RDTSC(end);
	len = (end - start) / freq_khz;
	speed = size / len;
	printf("16-bit read done in %d.%03d s (%d.%03d MB/s), ",
	    len / 1000, len % 1000, speed / 1000, speed % 1000);
	val = seed;
	tmp = 0;
	for (p16 = (uint16_t *) mem_base; p16 < (uint16_t *) mem_end; 
	    val += 0x137b5d51)
		for (i = 0; i < 16; i++)
			if ((i & 1) == 0) {
				if (*p16++ != (val & 0xffff))
					tmp++;
			} else {
				if (*p16++ != ((~val) & 0xffff))
					tmp++;
			}
	printf("%d errors\n", tmp);
	tot_err += tmp;
	
	val = seed;
	RDTSC(start);
	for (p32 = (uint32_t *) mem_base; p32 < (uint32_t *) mem_end;
	    val += 0x137b5d51) {
		*p32++ = val; *p32++ = val; *p32++ = val; *p32++ = val;
		*p32++ = val; *p32++ = val; *p32++ = val; *p32++ = val;
		*p32++ = val; *p32++ = val; *p32++ = val; *p32++ = val;
		*p32++ = val; *p32++ = val; *p32++ = val; *p32++ = val;
	}
	RDTSC(end);
	len = (end - start) / freq_khz;
	speed = size / len;
	printf("32-bit write done in %d.%03d s (%d.%03d MB/s)\n",
	    len / 1000, len % 1000, speed / 1000, speed % 1000);
	
	RDTSC(start);
	for (p32 = (uint32_t *) mem_base; p32 < (uint32_t *) mem_end;) {
		val = *p32++; val = *p32++; val = *p32++; val = *p32++;
		val = *p32++; val = *p32++; val = *p32++; val = *p32++;
		val = *p32++; val = *p32++; val = *p32++; val = *p32++;
		val = *p32++; val = *p32++; val = *p32++; val = *p32++;
	}
	RDTSC(end);
	len = (end - start) / freq_khz;
	speed = size / len;
	printf("32-bit read done in %d.%03d s (%d.%03d MB/s), ",
	    len / 1000, len % 1000, speed / 1000, speed % 1000);
	val = seed;
	tmp = 0;
	for (p32 = (uint32_t *) mem_base; p32 < (uint32_t *) mem_end; 
	    val += 0x137b5d51)
		for (i = 0; i < 16; i++)
			if (*p32++ != val)
				tmp++;
	printf("%d errors\n", tmp);
	tot_err += tmp;

	printf("Accumulated %d errors after %d iterations\n\n",
	    tot_err, iter);

	iter++;
	if (sio_getchar(0) != 3)
		goto again;

	return(0);
}
