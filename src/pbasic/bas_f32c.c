
#include <sys/param.h>

#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <fatfs/ff.h>

#include <io.h>

#include "bas.h"


int
bauds(void)
{
	int bauds;

	bauds = evalint();
	check();
	if (bauds < 300 || bauds > 3000000)
                error(33);      /* argument error */
	sio_setbaud(bauds);
        normret;
}

