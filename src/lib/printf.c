
#include <sio.h>
#include <stdarg.h>
#include <types.h>


#define PCHAR(c) {sio_putchar(c);}
#define	MAXNBUF	32


static int
vprintf(char const *fmt, va_list ap)
{
	char nbuf[MAXNBUF];
	char *cp;
	u_int num;
	int ch;
	int base, sign, neg, n;
	int retval = 0;

	for (;;) {
		while ((ch = (u_char)*fmt++) != '%') {
			if (ch == 0)
				return (retval);
			/* Translate CR -> CR + LF */
			if (ch == '\n')
				PCHAR('\r');
			PCHAR(ch);
		}

		sign = 0;
		neg = 0;
		base = 10;
		
		switch (ch = (u_char)*fmt++) {
		case 0:
			return (-1);	/* XXX use proper errno */
		case '%':
			PCHAR(ch);
			break;
		case 's':
			cp = va_arg(ap, char *);
			if (cp == NULL)
				cp = "(null)";
			for (;(ch = *cp++);)
				PCHAR(ch);
			break;
		case 'c':
			PCHAR(va_arg(ap, int));
			break;
		case 'd':
		case 'i':
			goto handle_sign;
		case 'b':
			base = 2;
			goto handle_nosign;
		case 'o':
			base = 8;
			goto handle_nosign;
		case 'u':
			goto handle_nosign;
		case 'p':
			/* XXX fixme */
		case 'x':
			base = 16;
			goto handle_nosign;
		case 'y':
			base = 16;
			goto handle_sign;
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
			if (neg)
				PCHAR('-');
			for (; n > 0;) {
				PCHAR(nbuf[--n]);
			}
			break;
		default:
			break;
		}
	}

	return (retval);
}


int
printf(const char *fmt, ...)
{
	va_list ap;
	int retval;
 
	va_start(ap, fmt);
	retval = vprintf(fmt, ap);
	va_end(ap);
 
	return (retval);
}

