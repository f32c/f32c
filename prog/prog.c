
#include "io.h"
#include "lcdfunc.h"
#include "libc.h"

/* Forward declarations for demo functions */
void demo_semafor(int);

void
platform_start() {
	int i;

	/* Clear screen */
	for (i = 0; i < 3; i++)
		memset(&lcdbuf[i][0], ' ', 20);

	demo_semafor(i);
}
