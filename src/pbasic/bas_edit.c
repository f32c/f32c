#include "bas.h"

#ifndef f32c
#include <sys/ioctl.h>
#endif


#ifndef f32c
void
setupmyterm()
{
/*
	set_cap();
*/
	setu_term();
}
#endif


static int
readc(void)
{
	char c;
	int got;

#ifndef f32c
	do {
		ioctl(0, FIONREAD, &got);
		if (got) {
			got = read(0, &c, 1);
			break;
		}
		update_x11(0);
		usleep(50 * 1000);
	} while (!trapped);
	if (!trapped && got != 1)
		quit();
#else
	got = read(0, &c, 1);
	if (c == 3)	/* CTRL + C */
		trapped = 1;
#endif
	return (c);
}


/*
 * fl .. (prlen)   .. length of the prompt, must be <= fi
 * fi .. (ilen)    .. initial length of the buffer content, must be >= fl
 * fc .. (nobeep?) .. set to 1 in AUTO mode and in LINPUT, 0 otherwise ?!?
 */
int
edit(ival promptlen, ival fi, ival fc)
{
	char c;
	int pos = fi;
	int esc_mode = 0;

//printf("IN: edit %d, %d, %d\n", promptlen, fi, fc);

#ifndef f32c
	set_term();
#endif

	line[fi] = 0;
	write(0, line, fi);

	while (1) {
		c = readc();
		if (trapped) {
			/* CTRL + C */
			write(0, "^C\r\n", 4);
			return (0);
		}
		if (c == 27) {
			esc_mode = 1;
			continue;
		}
		if (esc_mode && c == '[') {
			esc_mode = 2;
			continue;
		}
		esc_mode = 0;
		if (c == 10 || c == 13)	{
			/* CR / LF */
			write(0, "\r\n", 2);
			line[fi] = 0;
//printf("OUT: %s\n", &line[promptlen]);
			return (0);
		}
		if (c == 8 || c == 127) {
			/* Delete / Backspace */
			if (pos > promptlen) {
				write(0, "\b \b", 3);
				pos--;
				fi--;
			}
			continue;
		}
//printf(".%d %d.\n", pos, c);
		write(0, &c, 1);
		line[pos] = c;
		pos++;
		fi++;
	}
}
