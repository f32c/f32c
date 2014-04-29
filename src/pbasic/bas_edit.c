#include "bas.h"

#ifndef f32c
#include <sys/ioctl.h>
#endif


static int termwidth = 80;


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


static void
redraw_line(int oldpos, int newpos, int len)
{
	int i;
	int len_full = 0;

	if (len % termwidth == 0)
		len_full = 1;

//printf("\n.pos_full %d len_full %d.\n\n", pos_full, len_full);
	for (i = oldpos / termwidth; i > 0; i--)
		write(0, "\x1b[A", 4);	/* Cursor up */
	write(0, "\r", 1);		/* Cursor to column 0 */
	write(0, line, len);
	if (!len_full)
		write(0, "\x1b[K", 4);	/* Erase to the end of the line */
	for (i = len / termwidth; i > len_full; i--)
		write(0, "\x1b[A", 4);	/* Cursor up */
	write(0, "\r", 1);		/* Cursor to column 0 */
	for (i = newpos / termwidth; i > 0; i--)
		write(0, "\n", 1);	/* Cursor down */
	i = (newpos / termwidth) * termwidth;
	write(0, &line[i], newpos % termwidth);
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
				redraw_line(pos, pos - 1, fi);
				pos--;
			}
			if (c == 'C' && pos < fi) {
				/* Cursor right */
				redraw_line(pos, pos + 1, fi);
				pos++;
			}
			if (c == 126 && pos < fi) {
				/* Delete in the middle of the line */
				for (i = pos; i < fi; i++)
					line[i] = line[i + 1];
				fi--;
				line[fi] = ' ';
				redraw_line(pos, pos, fi + 1);
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
		if (c == 18) {
			/* CTRL-R */
			redraw_line(pos, pos, fi);
			continue;
		}
		if (c == 8 || c == 127) {
			/* Backspace */
			if (pos > promptlen) {
				pos--;
				fi--;
				write(0, "\b", 1);
				if (pos != fi) {
					/* Delete in the middle of the line */
					for (i = pos; i < fi; i++)
						line[i] = line[i + 1];
				}
				line[fi] = ' ';
				redraw_line(pos + 1, pos, fi + 1);
			}
			continue;
		}
//printf(".%d %d.\n", pos, c);
		if (fi >= MAXLIN)
			continue; /* Line buffer full - ignore char */
		pos++;
		fi++;
		if (pos < fi) {
			/* Insert in the middle of the line */
			for (i = fi; i >= pos; i--)
				line[i] = line[i - 1];
			line[pos - 1] = c;
			redraw_line(pos - 1, pos, fi);
		} else {
			write(0, &c, 1);
			line[pos - 1] = c;
		}
	}

	redraw_line(pos, fi, fi);
	write(0, "\r\n", 2);
//printf("\b\bOUT 1:    \b\b\b%s\r\n", &line[promptlen]);
#ifndef f32c
	rset_term(0);
#endif
//printf("OUT 2: %s\n", &line[promptlen]);
	return (0);
}
