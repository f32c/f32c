/*-
 * Copyright (c) 2014 Marko Zec, University of Zagreb
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _STDIO_H_
#define	_STDIO_H_

#include <sys/stdint.h>
#include <sys/task.h>

#include <dev/sio.h>

#define	EOF	(-1)

struct __sFILE {
	int16_t _fd;		/* file descriptor, or -1 */
	int16_t _flags;		/* flags */
};

typedef struct __sFILE FILE;

#define	stdin	((FILE *) TD_TASK(curthread)->ts_stdin)
#define	stdout	((FILE *) TD_TASK(curthread)->ts_stdout)
#define	stderr	((FILE *) TD_TASK(curthread)->ts_stderr)

int	printf(const char * __restrict, ...) \
	    __attribute__((format (printf, 1, 2)));
int	fprintf(FILE *, const char * __restrict, ...) \
	    __attribute__((format (printf, 2, 3)));
int	sprintf(char * __restrict, const char * __restrict, ...) \
	    __attribute__((format (printf, 2, 3)));
int	snprintf(char * __restrict, size_t, const char * __restrict, ...) \
	    __attribute__((format (printf, 3, 4)));
int	vprintf(const char * __restrict, __va_list);
int	vsprintf(char * __restrict, const char * __restrict, __va_list);

#if __ISO_C_VISIBLE >= 1999
int	snprintf(char * __restrict, size_t, const char * __restrict,
	    ...) __printflike(3, 4);
int	vscanf(const char * __restrict, __va_list) __scanflike(1, 0);
int	vsnprintf(char * __restrict, size_t, const char * __restrict,
	    __va_list) __printflike(3, 0);
int	vsscanf(const char * __restrict, const char * __restrict, __va_list)
	    __scanflike(2, 0);
#endif

char *strerror(int);
int strerror_r(int, char *, size_t);
void perror(const char *);

FILE	*fopen(const char * restrict, const char * restrict);
FILE	*fdopen(int, const char *);
int	fclose(FILE *);
int	fputc(int, FILE *);
int	putchar(int);
int	fputs(const char *, FILE *);
int	puts(const char *);

int	gets(char *, int);
int	fgetc(FILE *);
#define	getc(f) fgetc(f)
#define	getchar() getc(stdin)
ssize_t getdelim(char ** restrict, size_t * restrict, int,  FILE * restrict);
ssize_t getline(char ** restrict, size_t * restrict, FILE * restrict);

int	rename(const char *, const char *);

#endif /* !_STDIO_H_ */
