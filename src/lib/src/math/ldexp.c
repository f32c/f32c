#include <sys/cdefs.h>
/*
 * ldexp() and scalbn() are defined to be identical, but ldexp() lives in libc
 * for backwards compatibility.
 */
#define scalbn ldexp
#include "scalbn.c"
#undef scalbn
