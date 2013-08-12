/*
 * BASIC by Phil Cockcroft
 */
#include        "bas.h"

#ifndef	MSDOS
#ifndef	FD_CLOEXEC
//#include <sys/ioctl.h>
#endif
#endif

#include <sys/stat.h>

/*
 *      This file contains all the routines to implement terminal
 *    like files.
 */
#ifndef	O_RDWR
#define	O_RDWR		2
#endif
#ifndef	O_RDONLY
#define	O_RDONLY	0
#endif
#ifndef	O_WRONLY
#define	O_WRONLY	1
#endif
 
#if BLOCKSIZ > MAX_STR
#define	MAX_BLOCKSIZ BLOCKSIZ
#else
#define	MAX_BLOCKSIZ MAX_STR
#endif

/*
 *      setupfiles is called only once, it finds out how many files are
 *    required and allocates buffers for them. It will also execute
 *    'silly' programs that are given as parameters.
 */

#ifdef	__STDC__
static	void	runfile(int), f_flush(filebufp);
static	void	close_1(filebufp);
static	void	blrset(int);
static	void	bfdcheck(int);
#else
static	void	runfile(), f_flush();
static	void	close_1();
static	void	blrset();
static	void	bfdcheck();
#endif

void
setupfiles(int argc, char **argv)
{
	char    *q;
	int    fp;
	int     nfiles=MAXFILES;

#ifdef  NOEDIT
	noedit=1;
#endif
	while(argc > 1 ){
		q = *++argv;
		if(*q++ !='-')
			break;
		if(ispnumber(q)){
			nfiles= atoi(q);
			if(nfiles<0 || nfiles > MAXFILES)
				nfiles=MAXFILES;
		}
		else if(*q=='x')
			noedit=1;
		else if(*q=='e')
			noedit=0;
		argc--;
	}
	maxfiles = nfiles;
	ncurfiles = 0;
		/* code added to execute silly programs */
	if(argc <= 1)
		return;
	if((fp=open(*argv,O_RDONLY))!=-1)
		runfile(fp);
	prints("file not found\n");
	_exit(1);
}

/*
 *      This routine executes silly programs. It has to load up
 *    the program and then simulate the environment as is usually seen
 *    in main. It works....
 */

static	void
runfile(fp)
int	fp;
{
	static	int    firsttime = 1; /* flag to say that we are just loading */
	lpoint p;

	setupmyterm();          /* set up terminal - now done after files */
	program = 0;
	if(setexit() == ERR_RESET){	/* the file at the moment */
		drop_fns();
		execute();
	}
	if(!firsttime)          /* an error or cntrl-c */
		VOID quit();
	firsttime=0;
	readfi(fp, (lpoint)0, 0);
	clear();
	lp_fd = -1;
	p= program;	/* is this needed - yes */
	if(!p)
		VOID quit();
	stocurlin=p;
	point= p->lin;
	elsecount=0;
			/* go and run it */
	execute();
}

/* commands implemented are :-
	open / creat
	close
	input
	print
*/

/* syntax of commands :-
	open "filename" for input as <filedesc>
	open "filename" [for output] as <filedesc>
	close <filedesc> ,[<filedesc>]
	input #<filedesc> , v1 , v2 , v3 ....
	print #<filedesc> , v1 , v2 , v3 ....
	*/

/* format of file buffers    added 17-12-81
	struct  {
		int     filedes;        / * Unix file descriptor
		int     userfiledes;    / * name by which it is used
		int     posn;           / * position of cursor in file
		int     dev;            / * dev and inode are used to
		int     inode;          / * stop r/w to same file
		int     use;            / * r/w etc. + other info
		int     nleft;          / * number of characters in buffer
		char    buf[BLOCKSIZ];  / * the actual buffer
		} file_buffer ;

	The file_buffers are stored between the end of initialised data
      and fendcore. uses sbrk() at start up.

	At start up there are two buffer spaces allocated.
*/

/*
 *      The 'open' command it allocates file descriptors and buffer
 *    space then sets about opening the file and checking weather the
 *    the file is opened already and then checks to see if that file
 *    was opened for reading or writing.  It stops files being read and
 *    written at the same time
 */

#ifndef __FreeBSD__
//long	lseek();
	/* To phil C		phil@gmrs.isar.de
	   From Julian S	jhs@freebsd.org
	   Date 950813
	FreeBSD current has 
	off_t    lseek __P((int, off_t, int));
	& reports
	/usr/include/unistd.h:82: previous declaration of `lseek'
	however you might want a more general ifndef BSD or similar perhaps ?
	*/
#endif

int
bfopen()
{
	struct filebuf *p;
	struct filebuf *q;
	int     c;
	itype	i;
	int     append=0;
	itype   bl = 0;
	int     mode= _READ;
	struct  stat    inod;
	int	type_set = 0;
	int	is_random = 0;
	int	bsize = BLOCKSIZ;
	STR	st;

	st = stringeval();
	NULL_TERMINATE(st);
	c=getch();
	if(c== FOR){
		type_set = 1;
		c=getch();
		if(c== OUTPUT)
			mode = _WRITE;
		else if(c== APPEND){
			append++;
			mode = _WRITE;
		}
		else if(c== TERMINAL)
			mode = _TERMINAL;
		else if(c == RANDOM){
			bl = BLOCKSIZ;
			is_random++;
		}
		else if(c != INPUT)
			error(SYNTAX);
		c=getch();
	}
	if(c!= AS)
		error(SYNTAX);
	i=evalint();
	if(i<1 || i>MAXFILES)
		error(29);
	if(getch() == ','){
		if(getch() != RECORDSIZ)
			error(SYNTAX);
		bl = evalint();
		/*
		 * We should be able to have a blocked file with
		 * a string that is at maximum length mapping it.
		 */
		if(bl <= 0 ||  bl > MAX_BLOCKSIZ)
			error(10);
		bsize = bl;
	}
	else
		point--;
	check();

/* here we have mode set. i is the file descriptor 1-9
   now check to see if already allocated then allocate the descriptor
   and open file etc. */

	bfdcheck(i);

	if(ncurfiles >= maxfiles)	/* out of file descriptors */
		error(31);
	p = (filebufp)mmalloc((ival)(sizeof(struct filebuf) + bsize));
	p->bufsiz = bsize;
	p->filedes=0;
	p->userfiledes=0;
	p->use=0;
	p->nleft=0;
	p->next = filestart;
	filestart = p;
	ncurfiles++;

/*   code to check to see if file is open twice */

	if(stat(st->strval,&inod)!= -1){
		if( (inod.st_mode & S_IFMT) == S_IFDIR) {
			if(mode== _READ )  /* cannot deal with directories */
				error(15);
			else
				error(14);
		}
		for(q = filestart ; q ; q = q->next)
			if(q->userfiledes && q->inodnumber== inod.st_ino &&
						q->device== inod.st_dev){
				if(mode== _READ ){
					if( q->use & mode )
						break;
					error(15);
				}
				else
					error(14);
			}
	}

	if((!type_set && bl) || is_random){
#ifdef	O_CREAT
		p->filedes = open(st->strval, O_CREAT|O_RDWR, 0644);
		if(p->filedes < 0)
			error(15);
#else
		if( (p->filedes = open(st->strval, O_RDWR)) < 0){
			if((p->filedes = creat(st->strval, 0644)) < 0)
				error(15);
			(void) close(p->filedes);
			if( (p->filedes = open(st->strval, O_RDWR)) < 0)
				error(15);
		}
#endif
		mode = _READ|_WRITE;
	}
	else if(mode == _READ){
		if( (p->filedes=open(st->strval, O_RDONLY))== -1)
			error(15);
	}
	else  if(mode == _TERMINAL){
		if(bl)
			error(15);
		if((p->filedes = open(st->strval, O_RDWR)) == -1)
			error(15);
		mode |= _READ | _WRITE;
	}
	else  {
		if(append){
			p->filedes=open(st->strval, O_WRONLY);
			VOID lseek(p->filedes, 0L, 2);
		}
		if(!append || p->filedes== -1)
			if((p->filedes=creat(st->strval, 0644))== -1)
				error(14);
	}
	FREE_STR(st);
	p->posn = 0;
	VOID fstat(p->filedes,&inod);
#ifdef	FD_CLOEXEC
	VOID fcntl(p->filedes, F_SETFD, FD_CLOEXEC);
#else
#ifdef  FIOCLEX
	VOID ioctl(p->filedes, FIOCLEX, 0);  /* close on exec */
#endif
#endif
	p->device= inod.st_dev;         /* fill in all relevent details */
	p->inodnumber= inod.st_ino;
	p->userfiledes= (short)i;
	if(bl)
		mode |= _BLOCKED;
	p->nleft=0;
	p->use = (short)mode;
	normret;
}

static	void
bfdcheck(userfd)
int	userfd;
{
	filebufp p;
	filebufp q = 0;	/* only for lint */

	for(p = filestart ; p ; p = q){
		q = p->next;
		if(p->userfiledes == 0){
			p->use = 0;
			p->filedes = -1;
			close_1(p);
		} else if(userfd == p->userfiledes)
			error(29);
	}
}

/*      the 'close' command it runs through the list of file descriptors
 *    and flushes all buffers and closes the file and clears all
 *    relevent entry in the structure
 */

int
fclosef()
{
	int	c;

	c = getch();
	point--;
	if(istermin(c)){
		closeall();
		normret;
	}
	do{
		close_1(getf(evalint(),(_READ | _WRITE) ));
	} while(getch() == ',');
	point--;
	normret;
}

static	void
close_1(p)
filebufp p;
{
	filebufp op;

	if(p->use & _BLOCKED)
		kill_fstrs(p->buf, p->buf + p->bufsiz);
	else if(p->use & _WRITE )
		f_flush(p);
	if(p->filedes != -1)
		VOID close(p->filedes);
	
	if(p == filestart)
		filestart = p->next;
	else {
		for(op = filestart ; op ; op = op->next)
			if(op->next == p)
				break;
		if(!op)		/* a can't happen */
			return;
		op->next = p->next;
	}
	ncurfiles--;
	mfree( (MEMP)p);
}

/*      the 'eof' maths function eof is true if writting to the file
 *    or if the _EOF flag is set.
 */

void
eofl()
{
	struct filebuf *p;
	struct	stat	statbuf;

	p=getf(evalint(),(_READ | _WRITE) );
	vartype= IVAL;
	if(p->use & _EOF){
		res.i = -1;
		return;
	}
	res.i =0;
	if( (p->use & (_BLOCKED|_READ)) == (_BLOCKED|_READ)){
		VOID fstat(p->filedes, &statbuf);
		if(lseek(p->filedes, 0L, 1) <= statbuf.st_size - p->bufsiz)
			return;
	}
	else if((p->use & _WRITE) == 0){
		if(p->nleft)
			return;
		p->posn = 0;
		if( (p->nleft= read(p->filedes,p->buf,p->bufsiz)) > 0)
			return;
		p->nleft=0;
	}
	p->use |= _EOF;
	res.i = -1;
}

/*      the 'posn' maths function returns the current 'virtual' cursor
 *    in the file. If the file descriptor is zero then the screen
 *    cursor is accessed.
 */

void
fposn()
{
	struct filebuf *p;
	itype	i;

	i=evalint();
	vartype= IVAL;
	if(!i){
		res.i = (itype)cursor;
		return;
	}
	p=getf( (ival)i,(_READ | _WRITE) );
	if(p->use & _WRITE)
		res.i = (itype)p->posn;
	else
		res.i = 0;
}

/*      getf() returns a pointer to a file buffer structure. with the
 *    relevent file descriptor and with the relevent access permissions
 */

struct  filebuf *
getf(i,j)
ival	i;     /* file descriptor */
int	j;     /* access permission */
{
	struct filebuf *p;

	if(i == 0)
		error(29);
	j &= ( _READ | _WRITE ) ;
	for(p= filestart ; p ; p = p->next)
		if(p->userfiledes==i && ( p->use & j) )
			return(p);
	error(29);      /* unknown file descriptor */
	return(0);	/* not reached */
}

/*      flushes the file pointed to by p */

static	void
f_flush(p)
struct filebuf *p;
{

	if(p->nleft){
		if(write(p->filedes,p->buf,p->nleft) != p->nleft){
			p->nleft = 0;
			c_error(60);
		}
		p->nleft=0;
	}
}

/*      will flush all files , for use in 'shell' and in quit */

void
flushall()
{
	struct filebuf *p;
	for(p = filestart ; p ; p = p->next)
		if(p->nleft && ( p->use & _WRITE ) ){
			if(write(p->filedes,p->buf,p->nleft) != p->nleft){
				p->nleft = 0;
				c_error(60);
			}
			p->nleft=0;
		}
}

/*      closes all files and clears the relevent bits of info
 *    used in clear and new.
 */

void
closeall()
{
	struct filebuf *p;

	flushall();
	while( (p = filestart) != 0)
		close_1(p);
}

/*      write to a file , same as write in parameters (see print )
 */

int
putfile(p,q,i)
struct filebuf *p;
CHAR   *q;
int     i;
{
	ival	j;

	if(i <= 0)
		return(0);
	do {
		j = p->bufsiz - p->nleft;
		if(j >= i)
			j = i;
		if(!j){
			f_flush(p);
			continue;
		}
		VOID strmov(p->buf + p->nleft, q, j);
		p->nleft += j;
		q += j;
	}while( (i -= j) > 0);
	if(p->use & _TERMINAL)
		f_flush(p);
	return(0);
}

/* gets a line into q (MAX 512 or j) from file p terminating with '\n'
 * or _EOF returns number of characters read.
 */

int
fin1ch(p)
filebufp p;
{
	if(p->use & _TERMINAL)          /* kludge for terminal files */
		p->use &= ~_EOF;
	else if(p->use & _EOF)
		error(30);              /* end of file */

	if(p->use & _BLOCKED)
		error(29);

	if(!p->nleft){
		p->posn = 0;
		if( (p->nleft= read(p->filedes,p->buf,p->bufsiz)) <=0){
			p->nleft=0;     /* a read error */
			p->use |= _EOF; /* or end of file */
			error(30);
			/*NOTREACHED*/
		}
	}
	p->nleft--;
	return(UC(p->buf[p->posn++]));
}

/*
 * random file access mechanism
 */

#define	SPAD	' '

int
blset()
{
	blrset(1);
	normret;
}

int
brset()
{
	blrset(0);
	normret;
}

static	void
blrset(pad)
int	pad;
{
	stringp sp;
	STR	st;
	ival	i;

	sp = (stringp)getname(0);
	if(vartype != SVAL)
		error(2);
	if( (curentry->flags & IS_FSTRING) == 0)
		error(23);
	if(getch() != '=')
		error(4);
	st = stringeval();
	check();
	i = sp->len - st->strlen;
	if(i > 0){
		if(!pad){
			set_mem(sp->str, i, SPAD);
			VOID strmov(sp->str + i, st->strval, st->strlen);
		}
		else
			set_mem(strmov(sp->str,st->strval,st->strlen), i, SPAD);
	}
	else
		VOID strmov(sp->str, st->strval, sp->len);
	FREE_STR(st);
}

int
bfield()
{
	filebufp fp;
	struct	entry	*ep = NULL;
	stringp	sp;
	itype	il;
	ival	bsiz = 0;
	CHAR	*p;

	if(getch() != '#')
		error(SYNTAX);
	fp = getf(evalint(), (_READ|_WRITE));
	if((fp->use & _BLOCKED) == 0)
		error(29);
	if(getch() != ',')
		error(SYNTAX);
	p = fp->buf;
	do{
		il = evalint();
		if(il <= 0 || il > MAX_STR)
			error(10);
		if(il + bsiz > fp->bufsiz)
			error(12);
		if(getch() != AS)
			error(SYNTAX);
		sp = (stringp)getname(0);
		if(vartype != SVAL || (ep = curentry)->dimens ||
			(ep->flags & (IS_LOCAL|IS_COMMON)) != 0)
			error(2);
		/*
		 * magic time
		 */
		assert(ep != NULL);
		if( (ep->flags & IS_FSTRING) == 0 && sp->str != 0)
			mfree( (MEMP)sp->str);
		ep->flags |= IS_FSTRING;
		sp->str = p;
		set_mem(p, (ival)il, SPAD);
		sp->len = il;
		p += il;
		bsiz += il;
	}while(getch() == ',');
	point--;
	normret;
}

int
bput()
{
	filebufp fp;
	itype	pos = -1;
	int	c;

	if(getch() != '#')
		error(SYNTAX);
	fp = getf(evalint(), _WRITE);
	if((fp->use & _BLOCKED) == 0)
		error(52);

	if( (c = getch()) == ',' || c == RECORD){
		if(c == ',' && getch() != RECORD)
			point--;
		pos = evalint();
		if(pos < 0)
			pos = 0;
	}
	else
		point--;
	check();


	fp->nleft = fp->bufsiz;
	if(pos >= 0)
		VOID lseek(fp->filedes, (long)pos * fp->bufsiz, 0);
	fp->use &= ~_EOF;
	f_flush(fp);
	normret;
}

int
bget()
{
	filebufp fp;
	ival	pos = -1;
	int	c;

	if(getch() != '#')
		error(SYNTAX);
	fp = getf(evalint(), _READ);
	if((fp->use & _BLOCKED) == 0)
		error(52);
	if((c = getch()) == ',' || c == RECORD){
		if(c == ',' && getch() != RECORD)
			point--;
		pos = evalint();
		if(pos <= 0)
			pos = 0;
	}
	else
		point--;
	check();
	if(pos >= 0){
		VOID lseek(fp->filedes, (long)pos * fp->bufsiz, 0);
		fp->use &= ~_EOF;
	}
	else if(fp->use & _EOF)
		error(30);
	if(read(fp->filedes,fp->buf,fp->bufsiz) != fp->bufsiz){
		fp->use |= _EOF;
		error(30);
	}
	normret;
}
