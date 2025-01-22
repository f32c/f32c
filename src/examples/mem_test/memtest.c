/*
 * Write and read back various random patterns to / from memory, while
 * performing a bit of correctness checking and throughput measurements.
 */

#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#if CLOCKS_PER_SEC != 1000000
#error "CLOCKS_PER_SEC is not 1000000, aborting build"
#endif

extern int _end;
char *buf;


void
sig_h(int sig)
{

	printf("^C\n");
	exit(0);
}


int
main(void)
{
	volatile int *mem_base = &_end;
	volatile int *mem_end;
	int i, len, speed, iter, tot_err;
	int a = 0, b = 0, c, d;
	int size, tmp, freq_khz, start, end, seed, val, lval;
	int score;
	volatile uint8_t *p8;
	volatile uint16_t *p16;
	volatile uint32_t *p32;

	signal(SIGINT, sig_h);
	siginterrupt(SIGINT, 1);

	buf = (void *) mem_base;

	tot_err = 0;
	iter = 1;
again:
	score = 0;

	freq_khz = (get_cpu_freq() + 499) / 1000;
	printf("Detected %d.%03d MHz CPU\n\n",
	    freq_khz / 1000, freq_khz % 1000);

	if (mem_base < (int *) 0x80000000)
		mem_base = (int *) 0x80000000;
	mem_end = mem_base;

	/* Attempt to guess memory size */
	do {
		mem_end = &mem_end[4096];
		*mem_end = 0xdeadbeef;
		*mem_base = 0;
	} while (*mem_end != 0 && mem_end < (int *) 0xb0000000);
	mem_end = (int *) (((int) mem_end) & 0xffff8000);
	/* Don't touch the top 4 KB, the stack lives there */
	mem_end -= 0x400;
	size = (int) mem_end - (int) mem_base;
	
	printf("base %p end %p (size %d.%03d MB)\n", mem_base, mem_end,
	    size >> 20, ((size & 0xfffff) * 1000) >> 20);

	size = 128 * 1024 * 1024;
	start = clock();
	for (i = 0; i < size / (512 * 4); i++)
		for (p32 = (uint32_t *) mem_base;
		    p32 < (uint32_t *) &mem_base[512];) {
			val = *p32++; val = *p32++; val = *p32++; val = *p32++;
			val = *p32++; val = *p32++; val = *p32++; val = *p32++;
			val = *p32++; val = *p32++; val = *p32++; val = *p32++;
			val = *p32++; val = *p32++; val = *p32++; val = *p32++;
		}
	end = clock();
	len = (end - start) / 1000;
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

	seed = clock();
	val = seed;

	start = clock();
	for (i = 0; i < (1 << 26) / size; i++) {
		lval = val;
		for (p32 = (uint32_t *) mem_base; p32 < (uint32_t *) mem_end;
		    val += 0x137b5d51) {
			*p32++ = val; *p32++ = val; *p32++ = val; *p32++ = val;
			*p32++ = val; *p32++ = val; *p32++ = val; *p32++ = val;
			*p32++ = val; *p32++ = val; *p32++ = val; *p32++ = val;
			*p32++ = val; *p32++ = val; *p32++ = val; *p32++ = val;
		}
	}
	end = clock();
	len = (end - start) / 1000;
	speed = size * i / len;
	score += speed;
	printf("32-bit write done in %d.%03d s (%d.%03d MB/s)\n",
	    len / 1000, len % 1000, speed / 1000, speed % 1000);
	
	start = clock();
	for (i = 0; i < (1 << 26) / size; i++)
		for (p32 = (uint32_t *) mem_base; p32 < (uint32_t *) mem_end;) {
			val = *p32++; val = *p32++; val = *p32++; val = *p32++;
			val = *p32++; val = *p32++; val = *p32++; val = *p32++;
			val = *p32++; val = *p32++; val = *p32++; val = *p32++;
			val = *p32++; val = *p32++; val = *p32++; val = *p32++;
		}
	end = clock();
	len = (end - start) / 1000;
	speed = size * i / len;
	score += speed;
	printf("32-bit read done in %d.%03d s (%d.%03d MB/s), ",
	    len / 1000, len % 1000, speed / 1000, speed % 1000);
	val = lval;
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
	start = clock();
	for (i = 0; i < (1 << 26) / size; i++) {
		lval = val;
		for (p16 = (uint16_t *) mem_base; p16 < (uint16_t *) mem_end;
		    val += 0x137b5d51) {
			*p16++ = val; *p16++ = ~val;
			*p16++ = val; *p16++ = ~val;
			*p16++ = val; *p16++ = ~val;
			*p16++ = val; *p16++ = ~val;
			*p16++ = val; *p16++ = ~val;
			*p16++ = val; *p16++ = ~val;
			*p16++ = val; *p16++ = ~val;
			*p16++ = val; *p16++ = ~val;
		}
	}
	end = clock();
	len = (end - start) / 1000;
	speed = size * i / len;
	score += speed / 2;
	printf("16-bit write done in %d.%03d s (%d.%03d MB/s)\n",
	    len / 1000, len % 1000, speed / 1000, speed % 1000);
	
	start = clock();
	for (i = 0; i < (1 << 26) / size; i++)
		for (p16 = (uint16_t *) mem_base; p16 < (uint16_t *) mem_end;) {
			val = *p16++; val = *p16++; val = *p16++; val = *p16++;
			val = *p16++; val = *p16++; val = *p16++; val = *p16++;
			val = *p16++; val = *p16++; val = *p16++; val = *p16++;
			val = *p16++; val = *p16++; val = *p16++; val = *p16++;
		}
	end = clock();
	len = (end - start) / 1000;
	speed = size * i / len;
	score += speed / 2;
	printf("16-bit read done in %d.%03d s (%d.%03d MB/s), ",
	    len / 1000, len % 1000, speed / 1000, speed % 1000);
	val = lval;
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
	start = clock();
	for (i = 0; i < (1 << 26) / size; i++) {
		lval = val;
		for (p8 = (uint8_t *) mem_base; p8 < (uint8_t *) mem_end;
		    val += 0x137b5d51) {
			*p8++ = val; *p8++ = val; *p8++ = ~val; *p8++ = ~val;
			*p8++ = val; *p8++ = val; *p8++ = ~val; *p8++ = ~val;
			*p8++ = val; *p8++ = val; *p8++ = ~val; *p8++ = ~val;
			*p8++ = val; *p8++ = val; *p8++ = ~val; *p8++ = ~val;
		}
	}
	end = clock();
	len = (end - start) / 1000;
	speed = size * i / len;
	score += speed / 2;
	printf("8-bit write done in %d.%03d s (%d.%03d MB/s)\n",
	    len / 1000, len % 1000, speed / 1000, speed % 1000);
	
	start = clock();
	for (i = 0; i < (1 << 26) / size; i++)
		for (p8 = (uint8_t *) mem_base; p8 < (uint8_t *) mem_end;) {
			val = *p8++; val = *p8++; val = *p8++; val = *p8++;
			val = *p8++; val = *p8++; val = *p8++; val = *p8++;
			val = *p8++; val = *p8++; val = *p8++; val = *p8++;
			val = *p8++; val = *p8++; val = *p8++; val = *p8++;
		}
	end = clock();
	len = (end - start) / 1000;
	speed = size * i / len;
	score += speed / 2;
	printf("8-bit read done in %d.%03d s (%d.%03d MB/s), ",
	    len / 1000, len % 1000, speed / 1000, speed % 1000);
	val = lval;
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
	
	if (size > 65536)
		size = 65536;
	start = clock();
	for (i = 0; i < 256; i++)
		memcpy(buf, buf + size, size);
	end = clock();
	len = (end - start) / 1000;
	speed = i * size / len;
	printf("%d * memcpy(aligned %d KB) done in %d.%03d s (%d.%03d MB/s)\n",
	    i, size / 1024, len / 1000, len % 1000, speed / 1000,
	    speed % 1000);

	start = clock();
	for (i = 0; i < 128; i++)
		memcpy(buf + 1, buf + size + 3, size - 1);
	end = clock();
	len = (end - start) / 1000;
	speed = i * size / len;
	printf("%d * memcpy(unaligned %d KB) done in %d.%03d s (%d.%03d MB/s)"
	    "\n", i, size / 1024, len / 1000, len % 1000, speed / 1000,
	    speed % 1000);

	printf("Accumulated %d errors after %d iterations\n\n",
	    tot_err, iter);

	score /= 4;
	printf("Weighted average throughput: %d.%03d MB/s\n", score / 1000,
	    score % 1000);
	score = score * 1000 / freq_khz;
	printf("Weighted avg per clock freq: %d.%03d MB/s/MHz\n\n",
	    score / 1000, score % 1000);

	iter++;
	goto again;
}
