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
	if (c == 3 || got == 0)	/* CTRL + C */
		trapped = 1;
#endif
	return (c);
}


static void
request_term_size(void)
{

	write(0,
	    "\x1b[s"		/* Save cursor */
	    "\x1b[999C"		/* Move cursor to right margin */
	    "\x1b[6n"		/* Query cursor position */
	    "\x1b[u"		/* Restore cursor */
	    , 3 + 6 + 4 + 3);
}


static void
redraw_line(int oldpos, int newpos, int len)
{
	int i;
	int len_full = 0;

	if (len % term_width == 0)
		len_full = 1;

	for (i = oldpos / term_width; i > 0; i--)
		write(0, "\x1b[A", 3);	/* Cursor up */
	write(0, "\r", 1);		/* Cursor to column 0 */
	write(0, line, len);
	if (!len_full)
		write(0, "\x1b[K", 3);	/* Erase to the end of the line */
	for (i = len / term_width; i > len_full; i--)
		write(0, "\x1b[A", 3);	/* Cursor up */
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
	int size_known = 0;
	int insert = 1;
	int i, nchar;

#ifndef f32c
	set_term();
#endif
	if (pos == promptlen)
		write(0, line, fi);
	else {
		for (i = 0; i < fi / term_width; i++)
			write(0, "\n", 1);
		request_term_size();
	}

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
			esc_mode = 0;
			switch (c) {
			case ';':
				term_height = vt100_val;
				vt100_val = 0;
				esc_mode = 2;
				continue;
			case 'R':
				if (vt100_val != 0) {
					term_width = vt100_val;
					size_known = 1;
					redraw_line(pos, pos, fi);
				}
				continue;
			case 'D':
				c = 'B' - 64; /* CTRL-B, cursor right */
				break;
			case 'C':
				c = 'F' - 64; /* CTRL-F, cursor right */
				break;
			case 'H':
				/* Home */
				redraw_line(pos, promptlen, fi);
				pos = promptlen;
				continue;
			case 'F':
				/* End */
				redraw_line(pos, fi, fi);
				pos = fi;
				continue;
			case 126:
				if (vt100_val == 3 && pos < fi) {
				/* Delete in the middle of the line */
				for (i = pos; i < fi; i++)
					line[i] = line[i + 1];
				fi--;
				line[fi] = ' ';
				redraw_line(pos, pos, fi + 1);
				}
				if (vt100_val == 2) {
				/* Toggle insert / overwrite mode */
				insert ^= 1;
				}
				continue;
			default:
				continue;
			}
		}
		esc_mode = 0;
		if (c == 'J' - 64 || c == 'M' - 64)
			/* CR / LF */
			break;
		if (c == 'B' - 64 && pos > promptlen) {
			/* CTRL-B, cursor left */
			if (pos % term_width)
				write(0, "\b", 1); /* 1 ch. left */
			else
				/* 1 line up and to the right margin */
				write(0, "\x1b[A\x1b[999C", 9);
			pos--;
			continue;
		}
		if (c == 'F' - 64 && pos < fi) {
			/* CTRL-F, cursor right */
			if ((pos + 1) % term_width)
				write(0, &line[pos], 1);
			else
				/* 1 line down and to the left margin */
				write(0, "\r\n", 2);
			pos++;
			continue;
		}
		if (c == 'R' - 64 || c == 'L' - 64) {
			/* CTRL-R or CTRL-L */
			if (c == 'L' - 64)
				/* Clear screen, cursor home */
				write(0, "\x1b[2J\x1b[H", 7);
			request_term_size();
			continue;
		}
		if (c == 'H' - 64 || c == 127) {
			/* Backspace */
			if (pos > promptlen) {
				pos--;
				fi--;
				if (pos != fi ||
				    ((pos + 1) % term_width) == 0) {
					/* Delete in the middle of the line */
					for (i = pos; i < fi; i++)
						line[i] = line[i + 1];
					line[fi] = ' ';
					redraw_line(pos + 1, pos, fi + 1);
				} else
					write(0, "\b \b", 3);
			}
			continue;
		}
		nchar = 1;
		if (c == 'I' - 64) {
			/* TAB / CTRL-I */
			for (i = promptlen; i < pos; i++)
				if (line[i] != ' ')
					break;
			if (i < fi && isdigit(line[i])) {
				for (; i < pos; i++)
					if (!isdigit(line[i]))
						break;
				if (i == pos)
					nchar = 1;
				else
					nchar = 4 - (pos - i - 1) % 4;
			} else
				nchar = 4 - (pos - promptlen) % 4;
			if (nchar == 0)
				nchar = 4;
			c = ' ';
		}
		if (c < 32)
			continue;
		if (insert) {
			if (fi + nchar >= MAXLIN)
				continue; /* Line buffer full - ignore char */
			pos += nchar;
			fi += nchar;
		} else {
			if (pos + nchar >= MAXLIN)
				continue; /* Line buffer full - ignore char */
			pos += nchar;
			if (fi < pos)
				fi = pos;
		}
		if (pos < fi) {
			/* Insert in the middle of the line */
			if (insert)
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
			if (!size_known)
				request_term_size();
		}
	}

	line[fi] = 0;
	if (pos != fi)
		redraw_line(pos, fi, fi);
	if (trapped)
		write(0, "^C", 2);
	write(0, "\r\n", 2);
#ifndef f32c
	rset_term(0);
#endif
	return (0);
}
