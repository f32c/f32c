
#include <io.h>
#include <sio.h>
#include <stdio.h>
#include <types.h>


extern void pcm_play(void);


int
main(void)
{
	char c;

	/* Register PCM output function as idle loop handler */
	sio_idle_fn = pcm_play;

	do {
		c = getchar();
	} while (1);
}
