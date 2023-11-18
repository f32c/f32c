/*
 * Write and read back random patterns to / from memory.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <dev/io.h>

#include <mips/asm.h>
#include <mips/cpuregs.h>

extern int _end;
char *buf;


int
main(void)
{
	volatile int *mem_base = &_end;
	volatile int *mem_end;
	int i, len, speed, iter, tot_err;
	int a = 0, b = 0, c, d;
	int size, tmp, freq_khz, start, end, seed, val;
	volatile uint8_t *p8;
	volatile uint16_t *p16;
	volatile uint32_t *p32;

	buf = (void *) mem_base;

	tot_err = 0;
	iter = 1;
again:

#if 0
#define N 4
#define K 16385
	p32 = (void *) 0x80000000;
	for (i = 0; i < N * K; i += K) {
		p32[i] = i + (i << 24);
	}
	for (i = 0; i < N * K; i += K) {
		printf("%08x\n", p32[i]);
	}
	printf("\n");
#endif

	freq_khz = (get_cpu_freq() + 499) / 1000;
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
	/* Don't touch the top 4 KB, the stack lives there */
	mem_end -= 0x1000;
	size = (int) mem_end - (int) mem_base;
	
	printf("base %p end %p (size %d.%03d MB)\n", mem_base, mem_end,
	    size >> 20, ((size & 0xfffff) * 1000) >> 20);

	size = 128 * 1024 * 1024;
	RDTSC(start);
	for (i = 0; i < size / (512 * 4); i++)
		for (p32 = (uint32_t *) mem_base;
		    p32 < (uint32_t *) &mem_base[512];) {
			val = *p32++; val = *p32++; val = *p32++; val = *p32++;
			val = *p32++; val = *p32++; val = *p32++; val = *p32++;
			val = *p32++; val = *p32++; val = *p32++; val = *p32++;
			val = *p32++; val = *p32++; val = *p32++; val = *p32++;
		}
	RDTSC(end);
	len = (end - start) / freq_khz;
	speed = size / len;
	printf("Cache speed: %d MB 32-bit read done in"
	    " %d.%03d s (%d.%03d MB/s)\n", size / 1024 / 1024,
	    len / 1000, len % 1000, speed / 1000, speed % 1000);

	size = (int) mem_end - (int) mem_base;

	int csum = 0;
	for (i = 0; i < size / 4; i++) {
		mem_base[i] = i;
		csum += i;
	}
	tmp = 0;
	for (i = 0; i < size / 4; i++) {
		tmp += mem_base[i];
	}
	if (csum == tmp)
		printf("CSUM OK\n");
	else
		printf("CSUM mismatch: %08x %08x\n", csum, tmp);

	tmp = 0;
	for (i = 0; i < size / 4 - 1; i++) {
		a = mem_base[i];
		b = mem_base[i + 1];
		if (b != a + 1) {
			printf("%08x:%08x %08x:%08x\n", i, a, i + 1, b);
			tmp++;
		}
	}
	printf("read errors: %d\n", tmp);

	RDTSC(seed);
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
		for (i = 0; i < 8; i++) {
			a = *p32++;
			b = *p32++;
			if (a != val)
				tmp++;
			if (b != val)
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
	    val += 0x137b5d51) {
		c = val & 0xffff;
		d = (~val) & 0xffff;
		for (i = 0; i < 8; i++) {
			*p16; // dummy read, provoke consecutive read bug
			a = *p16++;
			b = *p16++;
			if (a != c)
				tmp++;
			if (b != d)
				tmp++;
		}
	}
	printf("%d errors\n", tmp);
	tot_err += tmp;
	
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
	
	size = 256 * 1024;
	RDTSC(start);
	for (i = 0; i < 100; i++)
		memcpy(buf + i * 4, buf + size - i * 16, size);
	RDTSC(end);
	len = (end - start) / freq_khz;
	speed = i * size / len;
	printf("%d * memcpy(aligned %d KB) done in %d.%03d s (%d.%03d MB/s)\n",
	    i, size / 1024, len / 1000, len % 1000, speed / 1000,
	    speed % 1000);

	size = 256 * 1024;
	RDTSC(start);
	for (i = 0; i < 100; i++)
		memcpy(buf + i * 4 + 1 + (i & 2), buf + size - i * 16 - 1,
		    size);
	RDTSC(end);
	len = (end - start) / freq_khz;
	speed = i * size / len;
	printf("%d * memcpy(unaligned %d KB) done in %d.%03d s (%d.%03d MB/s)"
	    "\n", i, size / 1024, len / 1000, len % 1000, speed / 1000,
	    speed % 1000);

	printf("Accumulated %d errors after %d iterations\n\n",
	    tot_err, iter);

	iter++;
	if (sio_getchar(0) != 3)
		goto again;

	return(0);
}
