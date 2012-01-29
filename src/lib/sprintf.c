
#include <stdarg.h>
#include <types.h>


extern int _xvprintf(char const *, void(*)(int, void *), void *, va_list);

struct snprintf_arg {
	char    *str;
	size_t  remain;
};


static void
snprintf_pchar(int c, void *arg)
{
	struct snprintf_arg *const info = arg;

	if (info->remain != 1)
		*info->str++ = c;
	if (info->remain >= 2)
		info->remain--;
}


int
sprintf(char *str, const char *fmt, ...)
{
	va_list ap;
	struct snprintf_arg info;
	int retval;
 
	info.str = str;
	info.remain = 0;

	va_start(ap, fmt);
	retval = _xvprintf(fmt, snprintf_pchar, &info, ap);
	va_end(ap);
 
	*info.str = 0;
	return (retval);
}


int
snprintf(char *str, size_t size, const char *fmt, ...)
{
	va_list ap;
	struct snprintf_arg info;
	int retval;
 
	if (size == 0)
		return (0);

	info.str = str;
	info.remain = size;

	va_start(ap, fmt);
	retval = _xvprintf(fmt, snprintf_pchar, &info, ap);
	va_end(ap);
 
	*info.str = 0;
	return (retval);
}
