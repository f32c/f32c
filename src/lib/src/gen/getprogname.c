#include <stdlib.h>

extern char *__progname;

__weak_reference(_getprogname, getprogname);

const char *
_getprogname(void)
{

	return (__progname);
}
