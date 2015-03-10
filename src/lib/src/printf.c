/*-
 * Copyright (c) 1986, 1988, 1991, 1993
 *      The Regents of the University of California.  All rights reserved.
 * (c) UNIX System Laboratories, Inc.
 *
 * All or some portions of this file are derived from material licensed
 * to the University of California by American Telephone and Telegraph
 * Co. or Unix System Laboratories, Inc. and are reproduced herein with
 * the permission of UNIX System Laboratories, Inc.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 4. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *                      
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * $Id$
 */


#include <sio.h>
#include <stdarg.h>


#define	MAXNBUF	32

#define	PCHAR(c) {(*func)(c, arg); retval++;}


#ifndef NO_PRINTF_FLOAT
__attribute__((optimize("-Os"))) static int
pd(void(*func)(int, void *), void *arg, double x)
{
	double tx, one = 1.0, integ = 0, lim = 0.00000000001;
	char cb[128]; /* XXX hardcoded buffer size on stack - revisit!!! */
	int first = 0, last = 0, retval = 0, i, t;

	if (x == 0) {
		PCHAR('0');
		return(retval);
	}

	if (x < 0) {
		x = -x;
		PCHAR('-');
	}

	if (x < one) {
		PCHAR('0');
	} else {
		for (tx = x; tx >= one; tx /= 10, lim *= 10) {
			i = tx;
			i %= 10;
			cb[last++] = '0' + i;
		}
		if (last > first)
			last--;
		for (i = 0; i < (last - first + 1) / 2; i++) {
			t = cb[first + i];
			cb[first + i] = cb[last - i];
			cb[last - i] = t;
		}
		for (i = first; i <= last; i++) {
			PCHAR(cb[i]);
			integ = integ * 10 + (cb[i] - '0');
		}
		x = x - integ;
		if (x < lim)
			return(retval);
	}

	tx = x;
	PCHAR('.');
	while (integ == 0 || x > lim) {
		tx = tx * 10.0;
		x = x / 10.0;
		i = tx;
		if (integ == 0 && i == 0)
			lim /= 100;
		else
			integ = 1;
		PCHAR('0' + (i % 10));
	}
	return(retval);
}
#endif /* NO_PRINTF_FLOAT */


__attribute__((optimize("-Os"))) int
_xvprintf(char const *fmt, void(*func)(int, void *), void *arg, va_list ap)
{
	char nbuf[MAXNBUF];
	char *cp;
	u_int num;
	int ch;
	int base, sign, neg, n, width;
	char padc;
	int retval = 0;

	for (;;) {
		while ((ch = (u_char)*fmt++) != '%') {
			if (ch == 0)
				return (retval);
			PCHAR(ch);
		}

		sign = 0;
		neg = 0;
		base = 10;
		padc = ' ';
		width = 0;
		
reswitch:
		switch (ch = (u_char)*fmt++) {
		case 0:
			return (-1);	/* XXX use proper errno */
		case '%':
			PCHAR(ch);
			break;
		case '0':
			padc = '0';
			goto reswitch;
		case '1':
		case '2':
		case '3':
		case '4':
		case '5':
		case '6':
		case '7':
		case '8':
		case '9':
			for (n = 0;; ++fmt) {
				n = n * 10 + ch - '0';
				ch = *fmt;
				if (ch < '0' || ch > '9')
					break;
			}
			width = n;
			goto reswitch;
		case '*':
			width = va_arg(ap, int);
			/* fallthrough */
		case '.':
			goto reswitch;
		case 's':
			cp = va_arg(ap, char *);
			if (cp == NULL)
				cp = "(null)";
			while((ch = *cp++))
				PCHAR(ch);
			break;
		case 'c':
			PCHAR(va_arg(ap, int));
			break;
		case 'd':
		case 'i':
			goto handle_sign;
		case 'l':
			/* XXX quad modifier - fixme! */
			goto reswitch;
		case 'o':
			base = 8;
			goto handle_nosign;
		case 'u':
			goto handle_nosign;
		case 'p':
			width = 8;
			padc = '0';
			PCHAR(padc);
			PCHAR('x');
		case 'x':
			base = 16;
handle_nosign:
			num = va_arg(ap, u_int);
			goto number;
handle_sign:
			sign = 1;
			num = va_arg(ap, int);
number:
			if (sign && (int) num < 0) {
				neg = 1;
				num = - (int) num;
			}
			n = 0;
			do {
				ch = num % base;
				if (ch < 10)
					nbuf[n] = ch + '0';
				else
					nbuf[n] = ch + 'a' - 10;
				num /= base;
				n++;
			} while (num != 0);

			if (neg && padc == '0')
				PCHAR('-');

			for (;width > n + neg; width--)
				PCHAR(padc);

			if (neg && padc != '0')
				PCHAR('-');

			for (; n > 0;) {
				PCHAR(nbuf[--n]);
			}
			break;
#ifndef NO_PRINTF_FLOAT
		case 'f':
			retval += pd(func, arg, va_arg(ap, double));
			break;
#endif /* NO_PRINTF_FLOAT */
		default:
			break;
		}
	}

	return (retval);
}


static __attribute__((optimize("-Os"))) void
sio_pchar(int c, void *arg __unused)
{

	/* Translate CR -> CR + LF */
	if (c == '\n')
		sio_putchar('\r', 1);
	sio_putchar(c, 1);
}


__attribute__((optimize("-Os"))) int
printf(const char *fmt, ...)
{
	va_list ap;
	int retval;
 
	va_start(ap, fmt);
	retval = _xvprintf(fmt, sio_pchar, NULL, ap);
	va_end(ap);
 
	return (retval);
}
