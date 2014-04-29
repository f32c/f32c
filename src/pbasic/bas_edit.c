#include "bas.h"

#ifndef f32c
#include <sys/ioctl.h>
#endif


static int term_height = 24;
static int term_width = 80;


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
request_term_size(void)
{

	write(0, "\x1b[s", 3);		/* Save cursor */
	write(0, "\x1b[999C", 6);	/* Move cursor to right margin */
	write(0, "\x1b[6n", 4);		/* Query cursor position */
	write(0, "\x1b[u", 3);		/* Restore cursor */
}


static void
redraw_line(int oldpos, int newpos, int len)
{
	int i;
	int len_full = 0;

	if (len % term_width == 0)
		len_full = 1;

	for (i = oldpos / term_width; i > 0; i--)
		write(0, "\x1b[A", 4);	/* Cursor up */
	write(0, "\r", 1);		/* Cursor to column 0 */
	write(0, line, len);
	if (!len_full)
		write(0, "\x1b[K", 4);	/* Erase to the end of the line */
	for (i = len / term_width; i > len_full; i--)
		write(0, "\x1b[A", 4);	/* Cursor up */
	write(0, "\r", 1);		/* Cursor to column 0 */
	for (i = newpos / term_width; i > 0; i--)
		write(0, "\n", 1);	/* Cursor down */
	i = (newpos / term_width) * term_width;
	write(0, &line[i], newpos % term_width);
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
	int vt100_val = 0;
	int i, nchar;

#ifndef f32c
	set_term();
#endif

	request_term_size();

	line[fi] = 0;
	write(0, line, fi);

	while (1) {
		c = readc();
		if (trapped)
			break;	/* CTRL + C */
		if (c == 27) {
			esc_mode = 1;
			vt100_val = 0;
			continue;
		}
		if (esc_mode && (c == '[' || c == 'O' || isdigit(c))) {
			if (isdigit(c))
				vt100_val = (vt100_val * 10) + c - '0';
			esc_mode = 2;
			continue;
		}
		if (esc_mode == 2) {
			if (c == ';') {
				term_height = vt100_val;
				vt100_val = 0;
				continue;
			}
			if (c == 'R' && vt100_val != 0)
				term_width = vt100_val;
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
			if (c == 'H') {
				/* Home */
				redraw_line(pos, promptlen, fi);
				pos = promptlen;
			}
			if (c == 'F') {
				/* End */
				redraw_line(pos, fi, fi);
				pos = fi;
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
			request_term_size();
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
		nchar = 1;
		if (c == 9) {
			/* TAB / CTRL-I */
			nchar = 4;
			c = ' ';
		}
		if (c < 32)
			continue;
		if (fi + nchar >= MAXLIN)
			continue; /* Line buffer full - ignore char */
		pos += nchar;
		fi += nchar;
		if (pos < fi) {
			/* Insert in the middle of the line */
			for (i = fi; i >= pos; i--)
				line[i] = line[i - nchar];
			for (i = 1; i <= nchar; i++)
				line[pos - i] = c;
			redraw_line(pos - nchar, pos, fi);
		} else {
			for (i = 1; i <= nchar; i++) {
				line[pos - i] = c;
				write(0, &c, 1);
			}
		}
	}

	redraw_line(pos, fi, fi);
	if (trapped)
		write(0, "^C", 2);
	write(0, "\r\n", 2);
#ifndef f32c
	rset_term(0);
#endif
	return (0);
}
