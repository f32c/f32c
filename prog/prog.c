
#include "demo.h"
#include "io.h"
#include "lcdfunc.h"
#include "libc.h"

/* Forward declarations for demo functions */
void demo_semafor(int);

static int prog;

void
platform_start() {
	int i;

	/* Check out whether reset works */
	prog = 0;

again:
	/* Clear screen */
	for (i = 0; i < 4; i++)
		memset(&lcdbuf[i][0], ' ', 20);

	if ((newkey & keymask) != (oldkey & keymask)) {
		prog++;
		if (prog > DEMO_MAX)
			prog = 0;
		rotpos = 0;
	}
	oldkey = newkey;

	demo_semafor(prog);

	goto again;
}
