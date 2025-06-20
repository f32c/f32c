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
#include <limits.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <termios.h>
#include <time.h>
#include <unistd.h>

#include <sys/stat.h>
#include <sys/mount.h>

#ifndef F32C
#include <sys/wait.h>
#else
#include <dev/io.h>
#include <fatfs/diskio.h>
#endif

#define MAXARGS	16
#define	MAXHIST 32

static char *histbuf[MAXHIST];
static uint32_t	curhist;
static int interrupt;
static int do_exit;

typedef	void	cmdhandler_t(int, char **);

extern FILE debf;
#define dprintf(...) fprintf(&debf, __VA_ARGS__)


static void
set_term()
{
	struct termios nterm;

	tcgetattr(0, &nterm);

	nterm.c_lflag &= ~(ECHO|ECHOK|ECHONL|ICANON);
	nterm.c_iflag &= ~(IGNCR|INLCR);
	nterm.c_iflag |= (ICRNL|ISTRIP);

	tcsetattr(0, TCSADRAIN, &nterm);
}

static int
task_create(cmdhandler_t *f, int argc, char **argv)
{
#ifndef F32C
#if 0
	int tid;

	tid = fork();
	if (tid)
		return(tid);
#endif
#endif

	f(argc, argv);
	return (0);
}

#define	TOK_PIPE	0x1
#define	TOK_INPUT	0x2
#define	TOK_OUTPUT	0x3
#define	TOK_APPEND	0x4
#define	TOK_MAX		0x4

static int
tok(char *line, char **tokv)
{
	char *cp;
	int tokc = 0;
	int quote = 0;

	for (tokv[0] = NULL, cp = line; *cp != 0; cp++) {
		if (quote) {
			if (*cp == '"') {
				memmove(cp, &cp[1], strlen(cp));
				quote = 0;
			}
			continue;
		}
		switch (*cp) {
		case '\t':
		case ' ':
			*cp = 0;
			if (tokv[tokc] != NULL)
				tokv[++tokc] = NULL;
			continue;
		case '\\':
			memmove(cp, &cp[1], strlen(cp));
			if (tokv[tokc] == NULL)
				tokv[tokc] = cp;
			continue;
		case '"':
			memmove(cp, &cp[1], strlen(cp));
			quote = 1;
			continue;
		case '|':
		case '<':
		case '>':
			if (tokv[tokc] != NULL)
				tokc++;
			switch (*cp) {
			case '|':
				tokv[tokc] = (void *) TOK_PIPE;
				break;
			case '<':
				tokv[tokc] = (void *) TOK_INPUT;
				break;
			case '>':
				tokv[tokc] = (void *) TOK_OUTPUT;
				if (cp[1] != '>')
					break;
				*cp++ = 0;
				tokv[tokc] = (void *) TOK_APPEND;
				break;
			}
			tokv[++tokc] = NULL;
			*cp = 0;
			continue;
		default:
			if (tokv[tokc] == NULL)
				tokv[tokc] = cp;
			break;
		};
	}

	if (tokv[tokc] > (char *) TOK_MAX && tokv[tokc][0] != 0)
		tokc++;
	return (tokc);
}


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
		if (c < 0)
			return (-1);

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
	char *buf;
	int buf_off;
	struct stat sb;
	struct tm tm;

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

	buf_off = strlen(path);
	buf = malloc(buf_off + _POSIX_PATH_MAX + 2);
	if (buf == NULL) {
		printf("malloc() failed, aborting\n");
		free(debuf);
		return;
	}
	sprintf(buf, "%s/", path);

	for (row = 0; row < nrows; row++) {
		i = row;
		for (col = 0; col < ncols && i < items; i += nrows) {
			if (flags & LS_WIDE) {
				sprintf(&buf[buf_off], "/%s", debuf[i].d_name);
				stat(buf, &sb);
				sprintf(&buf[buf_off], "----");
				if (S_ISDIR(sb.st_mode))
					buf[buf_off] = 'd';
				if (sb.st_mode & S_IRUSR)
					buf[buf_off + 1] = 'r';
				if (sb.st_mode & S_IWUSR)
					buf[buf_off + 2] = 'w';
				if (sb.st_mode & S_IXUSR)
					buf[buf_off + 3] = 'x';
				printf("%s ", &buf[buf_off]);
				printf("%10d ", (uint32_t) sb.st_size);
				gmtime_r(&sb.st_mtime, &tm);
				asctime_r(&tm, &buf[buf_off]);
				buf[buf_off + 16] = 0;
				buf[buf_off + 24] = 0;
				printf("%s%s ", &buf[buf_off + 4],
				    &buf[buf_off + 19]);
			}
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
	free(buf);

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
ls_h(int argc, char **argv)
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
cd_h(int argc, char **argv)
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
pwd_h(int argc, char **argv)
{

	getcwd(argv[0], 128);
	printf("%s\n", argv[0]);
}


static void
rm_h(int argc, char **argv)
{
	int res;

	res = unlink(argv[1]);
	if (res)
		printf("Error: %d\n", errno);
}


static void
rmdir_h(int argc, char **argv)
{
	int res;

	res = rmdir(argv[1]);
	if (res)
		printf("Error: %d\n", errno);
}

static void
mkdir_h(int argc, char **argv)
{
	int res;

	res = mkdir(argv[1], 0777);
	if (res)
		printf("Error: %d\n", errno);
}


#ifdef F32C
static void
mkfs_h(int argc, char **argv)
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
rename_h(int argc, char **argv)
{

	if (argc != 3) {
		printf("Invalid arguments\n");
		return;
	}

	if (rename(argv[1], argv[2]) == 0)
		return;

	fprintf(stderr, "%s %s to %s: ", argv[0], argv[1], argv[2]);
	perror(NULL);
}


static void
cp_h(int argc, char **argv)
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

	clock_gettime(CLOCK_MONOTONIC, &start);
	to = open(argv[2], O_CREAT | O_RDWR, 0777);
	if (to < 0) {
		free(buf);
		close (from);	/* cannot creat file */
		printf("Can't open %s\n", argv[2]);
		return;
	}

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
cmp_h(int argc, char **argv)
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
		if (i != lim || got_a != got_b) {
			printf("%s %s differ: byte %d\n", argv[1], argv[2],
			    pos);
			break;
		}
#ifdef F32C
		/* CTRL + C ? */
		if (sio_getchar(0) == 3) {
			printf("^C - interrupted!\n");
			break;
		}
#endif
	} while (got_a > 0);

	close(a);
	close(b);
	free(abuf);
	free(bbuf);
}


#define	CREAT_MAXLINCHAR 256

static void
create_h(int argc, char **argv)
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
			for (llen = 0; interrupt == 0;) {
				c = getchar() & 0177;
				if (c == '\n' || c == '\r' || c == 3) {
					line[llen] = '\n';
					break;
				}
				if (llen < CREAT_MAXLINCHAR)
					line[llen++] = c;
			}
		} else {
			if (gets_s(line, CREAT_MAXLINCHAR) == NULL)
				break;
			llen = strlen(line);
		}
		if (interrupt) {
			printf("^C\n");
			break;
		}
		line[llen++] = '\n';
	}

	write(fd, buf, flen);
	free(buf);
	close(fd);
}


static void
more_h(int argc, char **argv)
{
	char buf[2048];
	int fd, got, i, c, res, last, lno = 0;
	int cat_mode;

	if (argc != 2) {
		printf("Invalid arguments\n");
		return;
	}

	cat_mode = argv[0][0] == 'c';

	fd = open(argv[1], 0);
	if (fd < 0) {
		printf("Can't open %s\n", argv[1]);
		return;
	}

	do {
		got = read(fd, buf, sizeof(buf));
		if (cat_mode && got > 0) {
			res = write(1, buf, got);
			if (interrupt || res != got) {
				if (errno == EINTR)
					printf("^C");
				printf("\n");
				break;
			}
			continue;
		}
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
					if (interrupt) {
						printf("^C\n");
						close(fd);
						return;
					}
					switch(c) {
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


static int
hexdump_line(int got, int *lno, uint8_t *buf)
{
	int i;

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
	(*lno)++;
	if (*lno == 23) {
stopped:
		printf("-- more --");
		i = getchar();
		printf("\r          \r");
		if (interrupt) {
			printf("^C\n");
			return (-1);
		}
		switch(i) {
		case 4:
		case 'q':
			return (-1);
		case ' ':
			*lno = 0;
			break;
		case '\r':
		case 'j':
			(*lno)--;
			break;
		default:
			goto stopped;
		}
	}
	return (0);
}


static void
hexdump_h(int argc, char **argv)
{
	uint8_t buf[16];
	int fd, got, res, fpos = 0, lno = 0;

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
		res = hexdump_line(got, &lno, buf);
	} while (got > 0 && res == 0);
	close(fd);
}


static void
history_h(int argc, char **argv)
{
	int i;

	i = curhist - MAXHIST;
	if (i < 0)
		i = 0;
	for (; i < curhist; i++)
		printf("%5d  %s\n", i + 1, histbuf[i % MAXHIST]);
}


static void
cls_h(int argc, char **argv)
{

	printf("\n\033[2J\033[H");
}


static void
date_h(int argc, char **argv)
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
exit_h(int argc, char **argv)
{

	do_exit = 1;
}


#define SREC_BUFSIZ	(1024 * 1024)

void
srec_rx(void)
{
	char *data = malloc(SREC_BUFSIZ);
	char name[256];
	char *buf = name;
	int c, col, clim, csum;
	int val, alim;
	int fd;
	int type = 0;
	int line = 0;
	int addr = 0;
	int last_addr = 0;

new_line:
	csum = 0;
	col = -1;
	clim = -1;
	val = 0;
	alim = 0;

new_char:
	col++;
	c = getchar();
	if (c < 0) {
		printf("^C\n");
		goto done;
	}
	if (c == '\r')
		goto new_char;
	if (c == '\n') {
		if (type == '0') {
			buf[addr] = 0;
			printf("hdr: %s\n", buf);
			goto new_line;
		}
		if (type == '5')
			goto new_line;
		if (type <= '3') {
			if ((line & 0x3f) == 0)
				printf("\r%c", "|/-\\"[(line >> 6) & 0x3]);
			last_addr = addr;
			line++;
			goto new_line;
		}
		printf("\nWriting %d bytes to %s...\n", last_addr - addr, name);
		fd = open(name, O_CREAT | O_RDWR, 0777);
		if (fd < 0) {
			printf("Can't open %s\n", name);
			goto done;
		}
		for (; addr < last_addr; addr += clim) {
			clim = last_addr - addr;
			if (clim > 65536)
				clim = 65536;
			val = write(fd, &data[addr & (SREC_BUFSIZ - 1)], clim);
			if (val != clim) {
				printf("Write error\n");
				break;
			}
			printf("%c\r", "|/-\\"[(clim >> 16) & 3]);
		}
		close(fd);
		printf("Done.\n");
		goto done;
	}
	if (col == 0) {
		if (c != 'S')
			goto abort;
		goto new_char;
	}
	if (col == 1) {
		type = c;
		alim = 8;
		if (type == '2' || type == '8')
			alim = 10;
		if (type == '3' || type == '7')
			alim = 12;
		addr = 0;
		buf = data;
		if (type == '0')
			buf = name;
		goto new_char;
	}
	val = (val & 0xf) << 4;
	if (c >= '0' && c <= '9')
		val |= (c - '0');
	else if (c >= 'A' && c <= 'F')
		val |= (c - 'A' + 10);
	else
		goto abort;
	if ((col & 1) == 0)
		goto new_char;
	csum += val;
	if (col == 3) {
		clim = (val << 1) + 3;
		goto new_char;
	}
	if (col < alim) {
		addr = (addr << 8) + val;
		goto new_char;
	}
	if (col < clim) {
		buf[addr & (SREC_BUFSIZ - 1)] = val;
		addr++;
		goto new_char;
	}
	csum -= val;
	csum &= 0xff;
	csum ^= 0xff;
	if (csum == val)
		goto new_char;
	printf("Invalid checksum");
	goto abort1;

abort:
	printf("Invalid record");
abort1:
	printf(" at line %d\n", line);
done:
	free(data);
}


static void
srec_h(int argc, char **argv)
{

	if (argc < 2) {
		printf("Invalid arguments\n");
		return;
	}

	switch (argv[1][0]) {
	case 'r':
		srec_rx();
		break;
	case 't':
		break;
	default:
		printf("Invalid arguments\n");
	}
}


static void
df_h(int argc, char **argv)
{
	int i, mounts;
	struct statfs *buf;

	mounts = getfsstat(NULL, 0, MNT_NOWAIT);
	buf = calloc(mounts, sizeof(struct statfs));
	if (buf == NULL) {
		perror("malloc() failed");
		return;
	}
	mounts = getfsstat(buf, mounts * sizeof(struct statfs), MNT_NOWAIT);
	printf("Filesystem\t   1K-blocks\t Used\t  Avail"
	    " Capacity  Mounted on\n");
	for (i = 0; i < mounts; i++)
#ifdef F32C
#define U64FMT "llu"
#else
#define U64FMT "lu"
#endif
		printf("%18s %9" U64FMT " %8" U64FMT " %9"
		    U64FMT "   %3" U64FMT "%%    %s\n",
		    buf[i].f_mntfromname,
		    buf[i].f_blocks * buf[i].f_bsize / 1024,
		    (buf[i].f_blocks - buf[i].f_bfree) * buf[i].f_bsize / 1024,
		    buf[i].f_bavail * buf[i].f_bsize / 1024,
		    (buf[i].f_blocks - buf[i].f_bfree) * 100 / buf[i].f_blocks,
		    buf[i].f_mntonname);
	free(buf);
}


#ifdef F32C
static void
baud_h(int argc, char **argv)
{

	if (argc == 1) {
		printf("%d\n", sio_getbaud());
		return;
	}

	if (sio_setbaud(atoi(argv[1])))
		printf("Invalid baud rate: ");
	printf("%s\n", argv[1]);
}


static void
flash_h(int argc, char **argv)
{
	int fd, start, len, res, lno = 0;
	struct diskio_inst di;
#define	FLASH_SECLEN 4096
	uint8_t buf[FLASH_SECLEN];

	diskio_attach_flash(&di, IO_SPI_FLASH, 0, 0, 0x1000000);
	free((void *) di.d_mntfrom);

	switch (argv[1][0]) {
	case 'r':
		if (argc < 5)
			break;
		start = strtol(argv[3], NULL, 0);
		len = strtol(argv[4], NULL, 0);
		if (start < 0 || len <= 0)
			break;
		if ((start & (FLASH_SECLEN - 1)) != 0) {
			printf("%08x (%d) is not sector aligned\n",
			    start, start);
			return;
		}

		fd = open(argv[2], O_CREAT | O_RDWR, 0777);
		if (fd < 0) {
			printf("Can't create %s\n", argv[2]);
			return;
		}

		for (start /= FLASH_SECLEN; len > 0;
		    len -= FLASH_SECLEN, start++) {
			di.d_sw->read(&di, buf, start, 1);
			if (len >= FLASH_SECLEN)
				res = write(fd, buf, FLASH_SECLEN);
			else
				res = write(fd, buf, len);
			if (res <= 0) {
				perror("write failed");
				break;
			}
		}
		close(fd);
		return;
	case 'w':
		if (argc < 4)
			break;
		start = strtol(argv[3], NULL, 0);
		if (start < 0)
			break;
		if ((start & (FLASH_SECLEN - 1)) != 0) {
			printf("%08x (%d) is not sector aligned\n",
			    start, start);
			return;
		}

		fd = open(argv[2], O_RDONLY);
		if (fd < 0) {
			printf("Can't open %s\n", argv[2]);
			return;
		}

		for (start /= FLASH_SECLEN, len = 0;; start++, len += res) {
			res = read(fd, buf, FLASH_SECLEN);
			if (res <= 0)
				break;
			if (res < FLASH_SECLEN)
				memset(&buf[res], 0xff, FLASH_SECLEN - res);
			di.d_sw->write(&di, buf, start, 1);
			printf("\r%c", "|/-\\"[start & 0x3]);
		}
		printf("\nWrote %d bytes\n", len);
		return;
	case 'd':
	case 'x':
		if (argc < 2)
			break;
		start = strtol(argv[2], NULL, 0);
		if (start < 0)
			break;

		do {
			di.d_sw->read(&di, buf, start / FLASH_SECLEN, 1);
			printf("%08x  ", start);
			res = hexdump_line(16, &lno,
			    &buf[start & (FLASH_SECLEN - 1)]);
			start += 16;
		} while (res == 0);
		return;
	default:
	}

	printf("Invalid arguments\n");
}
#endif


static cmdhandler_t help_h;

#define	CMDSW_ENTRY(t, h) { .tok = t, .handler = h}

const struct cmdswitch {
	const char	*tok;
	cmdhandler_t	*handler;
} cmdswitch[] = {
#ifdef F32C
	CMDSW_ENTRY("baud",	baud_h),
#endif
	CMDSW_ENTRY("cat",	more_h),
	CMDSW_ENTRY("cd",	cd_h),
	CMDSW_ENTRY("clear",	cls_h),
	CMDSW_ENTRY("cls",	cls_h),
	CMDSW_ENTRY("cmp",	cmp_h),
	CMDSW_ENTRY("copy",	cp_h),
	CMDSW_ENTRY("cp",	cp_h),
	CMDSW_ENTRY("create",	create_h),
	CMDSW_ENTRY("date",	date_h),
	CMDSW_ENTRY("del",	rm_h),
	CMDSW_ENTRY("df",	df_h),
	CMDSW_ENTRY("dir",	ls_h),
	CMDSW_ENTRY("exit",	exit_h),
#ifdef F32C
	CMDSW_ENTRY("flash",	flash_h),
#endif
	CMDSW_ENTRY("hd",	hexdump_h),
	CMDSW_ENTRY("help",	help_h),
	CMDSW_ENTRY("hexdump",	hexdump_h),
	CMDSW_ENTRY("hi",	history_h),
	CMDSW_ENTRY("history",	history_h),
	CMDSW_ENTRY("ls",	ls_h),
	CMDSW_ENTRY("mkdir",	mkdir_h),
#ifdef F32C
	CMDSW_ENTRY("mkfs",	mkfs_h),
#endif
	CMDSW_ENTRY("more",	more_h),
	CMDSW_ENTRY("mv",	rename_h),
	CMDSW_ENTRY("pwd",	pwd_h),
	CMDSW_ENTRY("quit",	exit_h),
	CMDSW_ENTRY("rename",	rename_h),
	CMDSW_ENTRY("rm",	rm_h),
	CMDSW_ENTRY("rmdir",	rmdir_h),
	CMDSW_ENTRY("srec",	srec_h),
	CMDSW_ENTRY("?",	help_h),
	{ 0, 0 }
};


static void
help_h(int argc, char **argv)
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


void
sig_h(int sig)
{

	//printf("%s() %d: signal %d\n", __FUNCTION__, __LINE__, sig);
	interrupt = 1;
}


void
cli(void)
{
	char line[128];
	int i, ll, argc = 0;
	char *argv[MAXARGS];
	char *lcp;

	set_term();

	/* XXX automount fatfs */
	getcwd(line, 128);

	signal(SIGHUP, sig_h);
	signal(SIGINT, sig_h);
	siginterrupt(SIGINT, 1);

	do {
		interrupt = 0;
		if (rl("cmd>", line, sizeof(line))) {
			if (errno == EINTR) {
				printf("^C\n");
				continue;
			}
			break;
		}

retok:
		ll = strlen(line) + 1;
		lcp = malloc(ll);
		if (lcp != NULL)
			memcpy(lcp, line, ll);

		/* Tokenize */
		argc = tok(line, argv);
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

		if (cmdswitch[i].handler == exit_h)
			cmdswitch[i].handler(argc, argv);
		else {
			i = task_create(cmdswitch[i].handler, argc, argv);
		}
	} while (!do_exit);
	do_exit = 0;
}
