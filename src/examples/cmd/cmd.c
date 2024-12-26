/*
 * A command shell skeleton, aiming at enabling basic file manipulation,
 * while serving as a proving ground for bringing file access libraries
 * somewhat in line to what would one expect from their POSIX counterparts.
 * A crude readline-style line editor is included.
 */

#include <ctype.h>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#include <sys/stat.h>

#ifndef F32C
#include <termios.h>
#endif

#ifdef F32C
#include <fatfs/ff.h>
#endif

#define MAXARGS	16
#define	MAXHIST 32

static char *histbuf[MAXHIST];
static uint32_t	curhist;

#ifndef F32C
#define	gets(str, size) gets_s((str), (size))

static struct termios oterm, nterm;

static void
set_term()
{
	tcgetattr(0, &oterm);
	nterm = oterm;

	nterm.c_lflag &= ~(ECHO|ECHOK|ECHONL|ICANON|ISIG);
	nterm.c_iflag &= ~(IGNCR|INLCR|ICRNL);
	nterm.c_iflag |= ISTRIP;
	nterm.c_cc[VMIN] = 1;
	nterm.c_cc[VTIME] = 0;

	tcsetattr(0, TCSADRAIN, &nterm);
}
#endif /* !F32C */

int
rl(const char *prompt, char *buf, int buflen)
{
	char *cp = buf, *endp;
	int hist = curhist;
	int insert = 1;
	int refresh = 0;
	int esc = 0;
	int c, i;

	*buf = 0;

refresh:
	if (refresh++) {
		for (i = 0; i <= cp - buf + strlen(prompt); i++)
			printf("\b \b");
		printf("\033[K");
	}
	printf("%s %s", prompt, buf);
	cp = &buf[strlen(buf)];
	endp = cp;
	do {
		c = getchar();
		if (esc) {
			switch (c) {
			case '0': case '1': case '2': case '3': case '4':
			case '5': case '6': case '7': case '8': case '9':
			case '[':
				esc = c;
				continue;
			case 'A': /* Cursor Up */
				c = 16; /* CTRL + P */
				esc = 0;
				break;
			case 'B': /* Cursor Down */
				c = 14; /* CTRL + N */
				esc = 0;
				break;
			case 'C': /* Cursor Right */
				c = 6; /* CTRL + F */
				esc = 0;
				break;
			case 'D': /* Cursor Left */
				c = 2; /* CTRL + B */
				esc = 0;
				break;
			case '~':
				switch (esc) {
				case '1': /* Home */
					c = 1; /* CTRL + A */
					break;
				case '2': /* Insert */
					c = 15; /* CTRL + O */
					break;
				case '3': /* Delete */
					c = 4; /* CTRL + D */
					break;
				case '4': /* End */
					c = 5; /* CTRL + E */
					break;
				case '5': /* PgUp */
					break;
				case '6': /* PgDn */
					break;
				default:
					break;
				}
				esc = 0;
				break;
			default:
				esc = 0;
				continue;
			}
		}
		switch (c) {
		case 1:	/* CTRL + A */
			for (; cp > buf; cp--)
				printf("\b");
			continue;
		case 2:	/* CTRL + B */
			if (cp > buf) {
				printf("\b");
				cp--;
			}
			continue;
		case 3:	/* CTRL + C */
			printf("\n");
			return (-1);
		case 4:	/* CTRL + D */
			if (endp > cp) {
				printf("%s ", &cp[1]);
				for (i = 1; i <= endp - cp; i++) {
					cp[i - 1] = cp[i];
					printf("\b");
				}
				endp--;
			}
			continue;
		case 5: /* CTRL + E */
			printf("%s", cp);
			cp = endp;
			continue;
		case 6:	/* CTRL + F */
			if (cp < endp)
				printf("%c", *cp++);
			continue;
		case 8:	/* CTRL + H, BS */
		case 127: /* DEL */
			if (cp > buf) {
				printf("\b%s ", cp);
				for (i = 0; i <= endp - cp; i++) {
					cp[i - 1] = cp[i];
					printf("\b");
				}
				cp--;
				endp--;
			}
			continue;
		case 10: /* CTRL + J, LF */
		case 13: /* CTRL + M, CR */
			printf("\n");
			return (0);
		case 11: /* CTRL + K */
			for (i = 0; i < endp - cp; i++)
				printf(" ");
			for (i = 0; i < endp - cp; i++)
				printf("\b");
			*cp = 0;
			endp = cp;
			continue;
		case 14: /* CTRL + N */
			if (hist == curhist)
				continue;
			hist++;
			if (hist == curhist)
				*buf = 0;
			else
				sprintf(buf, "%s", histbuf[hist % MAXHIST]);
			goto refresh;
		case 15: /* CTRL + O */
			insert ^= 1;
			continue;
		case 16: /* CTRL + P */
			if (hist <= 0 || hist + MAXHIST <= curhist)
				continue;
			hist--;
			sprintf(buf, "%s", histbuf[hist % MAXHIST]);
			goto refresh;
			goto refresh;
		case 12: /* CTRL + L */
			printf("\n\033[2J\033[H"); /* Clear entire screen */
		case 18: /* CTRL + R */
			goto refresh;
		case 27: /* ESC */
			esc = 1;
			continue;
		default:
			if (endp >= &buf[buflen - 1] || !isprint(c))
				continue;
			if (insert) {
				if (endp > cp)
					for (i = endp - cp; i >= 0; i--)
						cp[i + 1] = cp[i];
				*cp = c;
				*++endp = 0;
				printf("%s", cp);
				cp++;
				for (i = 0; i < endp - cp; i++)
					printf("\b");
			} else {
				printf("%c", c);
				if (cp == endp)
					*++endp = 0;
				*cp++ = c;
			}
		}
	} while (1);
}


#define	LS_RECURSE	(1 << 0)
#define	LS_WIDE		(1 << 1)
#define	LS_ALL		(1 << 2)
#define	LS_FLAGDIR	(1 << 3)
#define	LS_DONOTSORT	(1 << 4)
#define	LS_SINGLECOL	(1 << 5)

static int
ls_cmp(const void *p1, const void *p2)
{
	const struct dirent *de1 = p1;
	const struct dirent *de2 = p2;

	return(strcmp(de1->d_name, de2->d_name));
}


static void
ls_walk(char *path, int flags)
{
	DIR *dir;
	struct dirent *de;
	struct dirent *debuf = NULL;
	int debuflen = 0;
	int items = 0;
	int i, l;
	int width, nrows, ncols, row, col;

	/* Skip multiple leading '/' */
	while (path[0] == '/' && path[1] == '/')
		path++;

	/* Open the directory */
	dir = opendir(path);
	if (dir == NULL) {
		printf("Error: %d\n", errno);
		return;
	}

	/* Read directory into debuf */
	for (width = 0;;) {
		de = readdir(dir);
		if (de == NULL)
			break;

		/* Ignore dot entries, on FATFS they never appear anyway */
		if (!(flags & LS_ALL) && de->d_name[0] == '.'
		    && (de->d_name[1] == 0 || de->d_name[1] == '.'))
			continue;
		
		if (items >= debuflen) {
			debuflen += 16;
			debuf = realloc(debuf, debuflen * sizeof(*debuf));
		}
		if (debuf == NULL) {
			printf("malloc() failed, aborting\n");
			closedir(dir);
			return;
		}
		l = 0;
		if ((flags & LS_FLAGDIR) && de->d_type == DT_DIR
		    && de->d_namlen < 255)
			l = 1;
		if (width < de->d_namlen + l)
			width = de->d_namlen + l;
		memcpy(&debuf[items], de, sizeof(*de));
		items++;
	}
	closedir(dir);

	if (!(flags & LS_DONOTSORT))
		qsort(debuf, items, sizeof(*debuf), ls_cmp);

	if (width >= 32 || (flags & (LS_SINGLECOL | LS_WIDE))) {
		ncols = 1;
		width = 0;
	} else if (width < 8) {
		width = 8;
		ncols = 9;
	} else if (width < 16) {
		width = 16;
		ncols = 5;
	} else if (width < 24) {
		width = 24;
		ncols = 3;
	} else {
		width = 32;
		ncols = 2;
	}
	nrows = items / ncols;
	if (nrows * ncols < items)
		nrows++;

	for (row = 0; row < nrows; row++) {
		i = row;
		for (col = 0; col < ncols && i < items; i += nrows) {
			printf("%s", debuf[i].d_name);
			col++;
			l = debuf[i].d_namlen;
			if ((flags & LS_FLAGDIR) && debuf[i].d_type == DT_DIR) {
				printf("/");
				l++;
			}
			if (col < ncols)
				for (; l < width; l++)
					printf(" ");
		}
		printf("\n");
	}

	if (flags & LS_RECURSE) {
		l = strlen(path);
		if ((l > 0 && path[1] != ':') || (l > 2 && path[l - 1] != '/'))
			path[l++] = '/';

		for (i = 0; i < items; i++)
			if ((debuf[i].d_type == DT_DIR)
			    && debuf[i].d_name[0] != '.') {
				strcpy(&path[l], debuf[i].d_name);
				printf("\n%s:\n", path);
				ls_walk(path, flags);
			}
	}

	free(debuf);
}


static void
ls_h(char **argv, int argc)
{
	char buf[128];
	int argi = 1;
	int flags = 0;
	char *ocp;

	if (argc > 1 && argv[1][0] == '-') {
		argi++;
		for (ocp = &argv[1][1]; *ocp != 0; ocp++)
			switch (*ocp) {
			case '1':
				flags |= LS_SINGLECOL;
				break;
			case 'a':
				flags |= LS_ALL;
				break;
			case 'F':
				flags |= LS_FLAGDIR;
				break;
			case 'f':
				flags |= LS_DONOTSORT | LS_ALL;
				break;
			case 'l':
				flags |= LS_WIDE;
				break;
			case 'R':
				flags |= LS_RECURSE;
				break;
			default:
				printf("Unknown flag: %c\n", *ocp);
				return;
			}
	}

	if (argc > argi)
		strcpy(buf, argv[argi]);
	else
		strcpy(buf, ".");
	ls_walk(buf, flags);
}


static void
cd_h(char **argv, int argc)
{
	int res;
	char path[128];

	res = chdir(argv[1]);
	if (res)
		printf("Error: %d\n", errno);
	getcwd(path, 128);
	printf("%s\n", path);
}


static void
pwd_h(char **argv, int argc)
{

	getcwd(argv[0], 128);
	printf("%s\n", argv[0]);
}


static void
rm_h(char **argv, int argc)
{
	int res;

	res = unlink(argv[1]);
	if (res)
		printf("Error: %d\n", errno);
}


static void
rmdir_h(char **argv, int argc)
{
	int res;

	res = rmdir(argv[1]);
	if (res)
		printf("Error: %d\n", errno);
}

static void
mkdir_h(char **argv, int argc)
{
	int res;

	res = mkdir(argv[1], 0777);
	if (res)
		printf("Error: %d\n", errno);
}


#ifdef F32C
static void
mkfs_h(char **argv, int argc)
{
	char buf[FF_MAX_SS];
	int res;

	if (argc < 2 || argv[1][1] != ':') {
		printf("Invalid arguments\n");
		return;
	}

	res = f_mkfs(argv[1], 0, buf, FF_MAX_SS);
	if (res != FR_OK)
		printf("Error: %d\n", res);
}
#endif


static void
cp_h(char **argv, int argc)
{
	char *buf;
	int buflen;
	int from, to;
	int got, wrote;
	unsigned tot = 0;
	uint64_t tns;
	struct timespec start, end;

	if (argc != 3) {
		printf("Invalid arguments\n");
		return;
	}

	from = open(argv[1], O_RDONLY);
	if (from < 0) {
		printf("Can't open %s\n", argv[1]);
		return;
	}

	for (buflen = 64 * 1024; buflen >= 4096; buflen = buflen >> 1) {
		buf = malloc(buflen);
		if (buf != NULL)
			break;
	}
	if (buf == NULL) {
		close (from);
		printf("malloc() failed\n");
		return;
	}

	to = open(argv[2], O_CREAT | O_RDWR, 0777);
	if (to < 0) {
		free(buf);
		close (from);	/* cannot creat file */
		printf("Can't open %s\n", argv[2]);
		return;
	}

	clock_gettime(CLOCK_MONOTONIC, &start);
	do {
		got = read(from, buf, buflen);
		if (got < 0) {
			close(from);
			close(to);
			free(buf);
			printf("unexpected eof reading %s\n", argv[1]);
			return;
		}
		wrote = write(to, buf, got);
		tot += wrote;
		if (wrote < got) {
			close(from);
			close(to);
			free(buf);
			printf("error writing %s byte %d\n", argv[2], tot);
			return;
		}
#ifdef F32C
		/* CTRL + C ? */
		if (sio_getchar(0) == 3) {
			printf("^C - interrupted!\n");
			got = 0;
		}
#endif
	} while (got > 0);
	close(from);
	close(to);

	clock_gettime(CLOCK_MONOTONIC, &end);
	tns = (end.tv_sec - start.tv_sec) * 1000000000
	    + end.tv_nsec - start.tv_nsec;
	free(buf);
	printf("Copied %d bytes in %.3f s (%.3f KB/s)\n", tot,
	    0.000000001 * tns, tot / (tns * 0.000001));
}


static void
cmp_h(char **argv, int argc)
{
	int a, b, got_a, got_b, pos, i, lim, buflen;
	char *abuf, *bbuf;

	if (argc != 3) {
		printf("Invalid arguments\n");
		return;
	}

	a = open(argv[1], O_RDONLY);
	if (a < 0) {
		printf("Can't open %s\n", argv[1]);
		return;
	}
	b = open(argv[2], O_RDONLY);
	if (b < 0) {
		printf("Can't open %s\n", argv[2]);
		close(a);
		return;
	}

	for (buflen = 64 * 1024; buflen >= 4096; buflen = buflen >> 1) {
		abuf = malloc(buflen);
		bbuf = malloc(buflen);
		if (abuf != NULL && bbuf != NULL)
			break;
		free(abuf);
		free(bbuf);
	}
	if (abuf == NULL || bbuf == NULL) {
		free(abuf);
		free(bbuf);
		close(a);
		close(b);
		printf("malloc() failed\n");
		return;
	}

	pos = 0;
	do {
		got_a = read(a, abuf, buflen);
		got_b = read(b, bbuf, buflen);
		lim = buflen;
		if (got_a < lim)
			lim = got_a;
		if (got_b < lim)
			lim = got_b;
		for (i = 0; i < lim; i++)
			if (abuf[i] != bbuf[i])
				break;
		pos += i;
		if (i != lim || got_a != got_b)
			break;
#ifdef F32C
		if (sio_getchar(0) == 3) {
			printf("^C - interrupted!\n");
			break;
		}
#endif
	} while (got_a > 0);

	if (got_a != got_b)
		printf("%s %s differ: byte %d\n", argv[1], argv[2], pos);

	close(a);
	close(b);
	free(abuf);
	free(bbuf);
}


#define	CREAT_MAXLINCHAR 256

static void
create_h(char **argv, int argc)
{
	char *buf, *line;
	int fd, llen, flen, maxflen, c, silent = 0;

	if (argc == 3) {
		if (*argv[1] != '-') {
			printf("Invalid arguments\n");
			return;
		}
		argv[1] = argv[2];
		silent = 1;
		argc--;
	}

	if (argc != 2) {
		printf("Invalid arguments\n");
		return;
	}

	fd = open(argv[1], O_CREAT | O_RDWR, 0777);
	if (fd < 0) {
		printf("Can't create %s\n", argv[1]);
		return;
	}

	for (maxflen = 4 * 1024 * 1024; ((buf = malloc(maxflen)) == NULL)
	    && maxflen != 0; maxflen /= 2) {}

	if (buf == NULL) {
		close(fd);
		printf("malloc() failure\n");
		return;
	}

	for (flen = 0; flen < maxflen - CREAT_MAXLINCHAR; flen += llen) {
		line = &buf[flen];
		if (silent) {
			for (llen = 0;;) {
				c = getchar() & 0177;
				if (c == '\n' || c == '\r' || c == 3) {
					line[llen] = '\n';
					break;
				}
				if (llen < CREAT_MAXLINCHAR)
					line[llen++] = c;
			}
			if (c == 3)
				break;
		} else {
			if (gets(line, CREAT_MAXLINCHAR) < 0)
				break;
			llen = strlen(line);
		}
		line[llen++] = '\n';
	}

	write(fd, buf, flen);
	free(buf);
	close(fd);
}


static void
more_h(char **argv, int argc)
{
	char buf[128];
	int fd, got, i, c, last, lno = 0;

	if (argc != 2) {
		printf("Invalid arguments\n");
		return;
	}

	fd = open(argv[1], 0);
	if (fd < 0) {
		printf("Can't open %s\n", argv[1]);
		return;
	}

	do {
		got = read(fd, buf, 128);
		for (i = 0, last = 0; i < got; i++) {
			if (buf[i] == '\n') {
				write(1, &buf[last], i - last + 1);
				last = i + 1;
				lno++;
				if (lno == 23) {
stopped:
					printf("-- more --");
					c = getchar();
					printf("\r          \r");
					switch(c) {
					case 3:
						printf("^C\n");
					case 4:
					case 'q':
						close(fd);
						return;
					case ' ':
						lno = 0;
						break;
					case '\r':
					case 'j':
						lno--;
						break;
					default:
						goto stopped;
					}
				}
			}
		}
		write(1, &buf[last], i - last);
	} while (got > 0);
	close(fd);
}


static void
hexdump_h(char **argv, int argc)
{
	uint8_t buf[16];
	int fd, i, got, fpos = 0, lno = 0;

	if (argc != 2) {
		printf("Invalid arguments\n");
		return;
	}

	fd = open(argv[1], 0);
	if (fd < 0) {
		printf("Can't open %s\n", argv[1]);
		return;
	}

	do {
		got = read(fd, buf, 16);
		printf("%08x  ", fpos);
		fpos += got;
		for (i = 0; i < 16; i++) {
			if (i < got)
				printf("%02x ", buf[i]);
			else
				printf("   ");
			if ((i & 7) == 7)
				printf(" ");
		}
		if (got)
			printf("|");
		for (i = 0; i < got; i++)
			if (isprint(buf[i]))
				printf("%c", buf[i]);
			else
				printf(".");
		if (got)
			printf("|");
		printf("\n");
		lno++;
		if (lno == 23) {
stopped:
			printf("-- more --");
			i = getchar();
			printf("\r          \r");
			switch(i) {
			case 3:
				printf("^C\n");
			case 4:
			case 'q':
				close(fd);
				return;
			case ' ':
				lno = 0;
				break;
			case '\r':
			case 'j':
				lno--;
				break;
			default:
				goto stopped;
			}
		}
	} while (got > 0);
	close(fd);
}


static void
history_h(char **argv, int argc)
{
	int i;

	i = curhist - MAXHIST;
	if (i < 0)
		i = 0;
	for (; i < curhist; i++)
		printf("%5d  %s\n", i + 1, histbuf[i % MAXHIST]);
}


static void
cls_h(char **argv, int argc)
{

	printf("\n\033[2J\033[H");
}


static void
date_h(char **argv, int argc)
{
	struct timespec ts;
	struct tm tm;
	time_t tim;

	clock_gettime(CLOCK_REALTIME, &ts);
	if (argc == 2) {
		if (argv[1][0] == '+')
			ts.tv_sec += atoi(&argv[1][1]);
		else if (argv[1][0] == '-')
			ts.tv_sec -= atoi(&argv[1][1]);
		else
			ts.tv_sec = atoi(argv[1]);
		clock_settime(CLOCK_REALTIME, &ts);
	}

	tim = time(NULL);
	gmtime_r(&tim, &tm);
	printf("%s", asctime(&tm));
}


static void
exit_h(char **argv, int argc)
{

	exit(0);
}


typedef	void	cmdhandler_t(char **, int);
static cmdhandler_t help_h;

#define	CMDSW_ENTRY(t, h) { .tok = t, .handler = h}

const struct cmdswitch {
	const char	*tok;
	cmdhandler_t	*handler;
} cmdswitch[] = {
	CMDSW_ENTRY("cd",	cd_h),
	CMDSW_ENTRY("cls",	cls_h),
	CMDSW_ENTRY("clear",	cls_h),
	CMDSW_ENTRY("cmp",	cmp_h),
	CMDSW_ENTRY("copy",	cp_h),
	CMDSW_ENTRY("cp",	cp_h),
	CMDSW_ENTRY("create",	create_h),
	CMDSW_ENTRY("date",	date_h),
	CMDSW_ENTRY("del",	rm_h),
	CMDSW_ENTRY("dir",	ls_h),
	CMDSW_ENTRY("exit",	exit_h),
	CMDSW_ENTRY("hd",	hexdump_h),
	CMDSW_ENTRY("hexdump",	hexdump_h),
	CMDSW_ENTRY("help",	help_h),
	CMDSW_ENTRY("hi",	history_h),
	CMDSW_ENTRY("history",	history_h),
	CMDSW_ENTRY("ls",	ls_h),
	CMDSW_ENTRY("mkdir",	mkdir_h),
#ifdef F32C
	CMDSW_ENTRY("mkfs",	mkfs_h),
#endif
	CMDSW_ENTRY("more",	more_h),
	CMDSW_ENTRY("pwd",	pwd_h),
	CMDSW_ENTRY("quit",	exit_h),
	CMDSW_ENTRY("rm",	rm_h),
	CMDSW_ENTRY("rmdir",	rmdir_h),
	CMDSW_ENTRY("?",	help_h),
	{ 0, 0 }
};


static void
help_h(char **argv, int argc)
{
	int i, j;
	const char *tp;

	for (i = 0; (tp = cmdswitch[i].tok) != NULL; i++) {
		printf("%s ", tp);
		for (j = strlen(tp); j < 10; j++)
			printf(" ");
		if ((i % 6) == 5)
			printf("\n");
	}
	if (i % 6)
		printf("\n");
}


int
main(void)
{
	char line[128];
	int i, ll, argc;
	char *argv[MAXARGS];
	char *tok, *lcp;

#ifndef F32C
	set_term();
#endif

	do {
		if (rl("cmd>", line, sizeof(line)))
			continue;

retok:
		ll = strlen(line) + 1;
		lcp = malloc(ll);
		if (lcp != NULL)
			memcpy(lcp, line, ll);

		/* Tokenize */
		for (argc = 0, tok = line; argc < MAXARGS; argc++) {
			if (tok != NULL && *tok == '\"')
				argv[argc] = strtok_r(&tok[1], "\"", &tok);
			else
				argv[argc] = strtok_r(tok, " 	", &tok);
			if (argv[argc] == NULL)
				break;
		}

		if (argc == 0) {
			free(lcp);
			continue;
		}

		if (argc == 1) {
			if (argv[0][0] == '!') {
				free(lcp);
				if (argv[0][1] == '!')
					i = -1;
				else
					i = atoi(&argv[0][1]);
				if (i < 0)
					i += curhist;
				else
					i--;
				if (i >= curhist || i + MAXHIST < curhist ||
				    i < 0) {
					printf("%s: event not found\n",
					    argv[0]);
					continue;
				}
				i = i % MAXHIST;
				sprintf(line, "%s", histbuf[i]);
				printf("%s\n", line);
				goto retok;
			}
			if (strlen(argv[0]) == 2 && argv[0][1] == ':') {
				argv[1] = argv[0];
				argv[0] = "cd";
				argc = 2;
			}
		}

		if (lcp != NULL) {
			i = (curhist - 1) % MAXHIST;
			if (curhist && strcmp(lcp, histbuf[i]) == 0)
				free(lcp);
			else {
				i = curhist % MAXHIST;
				free(histbuf[i]);
				histbuf[i] = lcp;
				curhist++;
			}
		}

		for (i = 0; cmdswitch[i].tok != NULL; i++)
			if (strcmp(cmdswitch[i].tok, argv[0]) == 0)
				break;
		if (cmdswitch[i].tok == NULL) {
			printf("Unknown command\n");
			continue;
		}
		cmdswitch[i].handler(argv, argc);
	} while (1);
}
