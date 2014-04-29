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
	int i;

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
			write(0, "^C", 2);
			break;
		}
		if (c == 27) {
			esc_mode = 1;
			continue;
		}
		if (esc_mode && (c == '[' || c == 'O' || isdigit(c))) {
			esc_mode = 2;
			continue;
		}
		if (esc_mode == 2) {
			if (c == 'D' && pos > promptlen) {
				/* Cursor left */
				write(0, "\b", 1);
				pos--;
			}
			if (c == 'C' && pos < fi) {
				/* Cursor right */
				write(0, &line[pos], 1);
				pos++;
			}
			esc_mode = 0;
			continue;
		}
		esc_mode = 0;
		if (c == 10 || c == 13)	{
			/* CR / LF */
			line[fi] = 0;
			break;
		}
		if (c == 8 || c == 127) {
			/* Delete / Backspace */
			if (pos > promptlen) {
				pos--;
				fi--;
				write(0, "\b", 1);
				if (pos == fi)
					write(0, " \b", 2);
				else {
					/* Delete in the middle of the line */
					for (i = pos; i < fi; i++)
						line[i] = line[i + 1];
					write(0, &line[pos], fi - pos);
					write(0, " ", 1);
					for (i = pos; i <= fi; i++)
						write(0, "\b", 1);
				}
			}
			continue;
		}
//printf(".%d %d.\n", pos, c);
		if (fi >= MAXLIN)
			continue; /* Line buffer full - ignore char */
		write(0, &c, 1);
		pos++;
		fi++;
		if (pos < fi) {
			/* Insert in the middle of the line */
			for (i = fi; i >= pos; i--)
				line[i] = line[i - 1];
			line[pos - 1] = c;
			write(0, &line[pos], fi - pos);
			for (i = pos; i < fi; i++)
				write(0, "\b", 1);
		}
		line[pos - 1] = c;
	}

	write(0, "\r\n", 2);
#ifndef f32c
	rset_term(0);
#endif
//printf("OUT: %s\n", &line[promptlen]);
	return (0);
}
