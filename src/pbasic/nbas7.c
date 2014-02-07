/*
 * BASIC by Phil Cockcroft
 */
#include        "bas.h"
#include	<errno.h>

/*
 * these variables should be set in the terminal configuration routines.
 */
#ifndef	CTRL
#define	CTRL(c)	((c) & 037)
#endif

int	ch_erase = CTRL('h');
int	ch_kill = CTRL('u');
int	ch_eof = CTRL('d');
int	ch_rprnt = CTRL('r');
int	ch_werase = CTRL('w');
int	ch_lnext = CTRL('v');
int	ch_susp = CTRL('z');
int	line_len = 80;

/*      read a single character */

int
readc()
{
	char    c='\r';

#ifdef  SIG_JMP
	if(!setjmp(ecall)){
		ecalling = 1;
		if(read(0,&c,1) <= 0){
			ecalling = 0;
			VOID quit();
		}
		ecalling = 0;
	}
#else
	switch(read(0,&c,1)){		/* reading from a pipe exit on eof */
	case 1:
		break;
	case 0:
		VOID quit();
		break;
	case -1:
		if(errno != EINTR)
			VOID quit();
		break;
	}
#endif
	if (c == 3)
		trapped = 1;
	return( ((int)c) & 0177);
}

/* sets up the terminal structures so that the editor is in rare
 * with no paging or line boundries and no echo
 * Also sets up the user modes so that they are sensible when
 * we exit. ( friendly ).
 */

void
setupmyterm()
{
/*
	set_cap();
*/
	setu_term();
	if(ter_width > 10)
		line_len = ter_width;
}

/*   the actual editor pretty straight forward but.. */

#define	NORMAL_CHAR(c)	((c) >= ' ' && (c) <= '~')

#define	HIST_SIZ	500

#define	NORMAL_EDIT	0
#define	COMMAND_EDIT	1
#define	INSERT_EDIT	2
#define	TRAPPED_EDIT	3

static	CHAR	*xpbuf;
static	int	xpbuflen;

static	CHAR	*eline;

static	int	edit_mode;

static	jmp_buf	edit_chg;
static	int	cur_elnumb;
static	int	hist_numb;

static	int	cursr;
static	int	scstart;
static	int	scend;
static	int	scrlim;
static	int	line_end;
static	int	lastxm;
static	int	llim;

typedef	struct	{
	CHAR	*bufp;
	int	slen;
} savl_t;

int	Hist_Siz = HIST_SIZ;
static	savl_t	*edit_history;

#define	DATAVALID(buf)	((buf)->bufp != 0 && (buf)->slen > 0)

static	savl_t	ubuf;

static	savl_t	clbuf;
static	int	clcur;

static	savl_t	srbuf;

static	savl_t	Ubuf;

static	struct	undo	{
	savl_t	dels;
	savl_t	ins;
	int	posn;
	int	ocur;
	int	ncur;
	int	ucmd;
	int	uop;
	int	orepcnt;
	int	uswaped;
} undo;

static	int	last_ftFT;
static	int	last_ftFTc;
static	int	curcmd;
static	int	lastsrch;

static	CHAR	lastgtcmd[4];
static	CHAR	*lastgtcmdp;

static	void	putchs(const CHAR *, int);
static	void	putch(int);
static	void	pflush(void);
static	void	mv_cursr(int);
static	void	sav_ubuf(savl_t *, int, CHAR *);
static	void	setundo(void);
static	void	insert_mode(int, int);
static	void	redraw_line(int);
static	void	mvto_lin(int);
static	int	dosrch(int);
static	int	substr(CHAR *, int, CHAR *, int, int);
static	void	kill_line(void);
static	void	yank_line(void);
static	void	chng_line(void);
static	void	recov_line(savl_t *);
static	void	free_ubuf(savl_t *);
static	void	setscend(void);
static	int	mtchbrkt(void);
static	void	del_c(int, int);
static	int	gtword(int, int, int);
static	void	sav_curline(void);
static	void	draw_from_cursr(int);
static	int	normal_edit(void);
static	int	command_mode(ival);
static	int	find_c(int, int, int, int);
static	int	rd_xcmd(int, int, void (*)(void), int);
static	void	beep(void);
static	void	set_sc(void);
static	int	putxch(int);
static	int	vsize(int);
static	void	addnchars(int, CHAR *, CHAR **, CHAR **);
static	void	savustr(CHAR *, int, int, int);
static	void	dodotcmd(int);
static	void	doundo(void);
static	void	dotilde(int);
static	void	dopcmd(int, int);
static	CHAR    *do_ctrl_d(CHAR *, CHAR *);

static	const	char	*xemsgs[] = {
	"  ",
	"> ",
	"< ",
	"* "
};

static	const	char	delstr[] = "\b \b\b \b";
static	const	char	crlf[] = "\r\n";

/*
erase = ^h; kill = ^u;
eof = ^d; eol = <undef>; eol2 = <undef>; swtch = <undef>;
start = ^q; stop = ^s; susp = ^z; dsusp = ^y;
rprnt = ^r; flush = ^o; werase = ^w; lnext = ^v;
*/

/*ARGSUSED*/
int
edit(fl,fi,fc)
ival	fl, fi, fc;
{
	CHAR   *q;
	CHAR   *p;
	int     c = 0;
	int     special;
	int	llen;
	savl_t	*cur_line;
	CHAR	xeline[MAXLIN+1];
	CHAR	_xpbuf[MAXLIN+1];

	xpbuf = _xpbuf;
	xpbuflen = 0;

	eline = xeline;

	if(!edit_history){
		llen = sizeof(savl_t) * Hist_Siz;
		edit_history = (savl_t *)mmalloc(llen);
		clr_mem( (memp)edit_history, (ival)llen);
	}
	cur_elnumb = ++hist_numb;

	cur_line = &edit_history[cur_elnumb % Hist_Siz];
	free_ubuf(cur_line);

	scrlim = line_len - 4;
	
	llim = fl;
	curcmd = 0;
	setundo();

	if(fi){
		VOID strmov(eline, line, fi);
		putchs(eline, fi);
	}
	eline[fi] = 0;
	cursr=(int)fi;
	line_end = fi;
	lastxm = 0;
	edit_mode = NORMAL_EDIT;

	switch(setjmp(edit_chg)){
	case 0:		/* normal edit */
		c = normal_edit();
		if(c == ESCAPE && !noedit)
			c = command_mode(fc);
		break;
	case INSERT_EDIT:
		c = '\n';
		break;
	case TRAPPED_EDIT:
		free_ubuf(&clbuf);
		free_ubuf(&Ubuf);
		setundo();
		putchs(crlf, 2);
		pflush();
		hist_numb--;
		cursor=0;
		return(c);
	}

	if(!noedit)
		putchs(crlf, 2);
	pflush();

	eline[line_end] = 0;

/*   special characters are dealt with here- null is never returned */
	for(p=eline,q=line,special=0;*p;p++){
		if(special){
			special=0;
			if(*p >= CTRL('a') && *p < ' ')
				*q++ = *p;
			else {
				*q++ = '\\';
				*q++ = *p;
			}
		}
		else if(*p=='\\')
			special++;
		else *q++ = *p;
	}
	*q=0;
	llen = q - (line +llim);
	if(llen > 0)
		sav_ubuf(cur_line, llen, line + llim);
	else
		hist_numb--;

	free_ubuf(&clbuf);
	free_ubuf(&Ubuf);
	setundo();
	cursor=0;
	return(c);
}

static	int
normal_edit()
{
	CHAR	*pcursr;
	int	c;
	int	i;
	int	lastescaped = 0;
	int	inword;
	CHAR	*plim;
	CHAR	*tmp;

	pcursr = eline + cursr;
	plim = eline + llim;
	for(;;){
		pflush();
		c = readc();
		if(trapped){
			*pcursr = 0;
			longjmp(edit_chg, TRAPPED_EDIT);
		}
		if(!c)
			continue;
		if(NORMAL_CHAR(c) || lastescaped){
			lastescaped = 0;
			if(pcursr >= eline + MAXLIN){
				beep();
				continue;
			}
			if(!noedit)
				VOID putxch(c);
			*pcursr++ = (CHAR)c;
			continue;
		}
		if(c == ch_eof){
#ifdef	MDUMP
			mdump();
#endif
			if( (tmp = do_ctrl_d(pcursr, plim)) != 0){
				pcursr = tmp;
				continue;
			}
			c = readc();
			if(c != ch_eof){
				beep();
				continue;
			}
			putchs(crlf, 2);
			pflush();
			VOID quit();
			break;
		} else if(c == '\r' || c == '\n' || c == ESCAPE){
			break;
		} else if(c == '\t'){
			i = pcursr - eline;
			do {
				if(i >= MAXLIN){
					beep();
					break;
				}
				*pcursr++ = (CHAR)' ';
				if(!noedit)
					putch(' ');
			} while(++i & 7);
			continue;
		} 
		if(noedit){
			if(pcursr < eline + MAXLIN)
				*pcursr++ = (CHAR)c;
			continue;
		}
		if(c == ch_kill){
			i = pcursr - eline;
			if(i > line_len)
				i %= line_len;
			else
				i -= llim;
			while(i-- > 0)
				putchs(delstr, 3 * vsize(*--pcursr));
			pcursr = plim;
			continue;
		} else if(c == ch_erase){
			if(pcursr > plim)
				putchs(delstr, 3 * vsize(*--pcursr));
			else
				beep();
			continue;
		} else if(c == ch_rprnt){
			putchs("^R\r\n", 4);
			for(i = pcursr - plim, pcursr = plim; i ; i--)
				VOID putxch(*pcursr++);
			continue;
		} else if(c == ch_werase){
			if(pcursr <= plim){
				beep();
				continue;
			}
			inword = 0;
			while(pcursr > plim){
				if(pcursr[-1] == ' '){
					if(inword)
						break;
				}
				else
					inword = 1;
				putchs(delstr, 3*vsize(*--pcursr));
			}
			continue;
		} else if(c == ch_lnext){
			lastescaped = 1;
			putchs("^\b", 2); 
			continue;
#ifdef	SIGTSTP
		} else if(c == ch_susp){
			putchs(crlf, 2);
			pflush();	/* flush it out */
			VOID kill(0, SIGTSTP);
			if(llim)
				putchs(eline, llim);
			for(i = pcursr - plim, pcursr = plim; i ; i--)
				VOID putxch(*pcursr++);
			continue;
#endif
		}
		if(pcursr >= eline + MAXLIN){
			beep();
			continue;
		}
		*pcursr++ = (CHAR)c;
		VOID putxch(c);
	}
	*pcursr = 0;
	line_end = cursr = pcursr - eline;
	return(c);
}

static	int
command_mode(fc)
ival	fc;
{
	int	mcursr;
	int	c = 0;
	int	lnum;
	int	nchars;
	int	repcnt = 1;
	int	repset;

	edit_mode = COMMAND_EDIT;
	redraw_line(1);

	sav_ubuf(&Ubuf, line_end - llim, eline + llim);

	while(!trapped){
		pflush();
		c = readc();
		if(trapped)
			break;
		if(c >= '1' && c <= '9'){
			repset = 1;
			repcnt = c - '0';
			for(;;){
				c = readc();
				if(trapped)
					break;
				if(c < '0' || c > '9'){
					if(repcnt < 0 || repcnt > MAXLIN)
						repcnt = MAXLIN;
					break;
				}
				repcnt = repcnt * 10 + c - '0';
			}
		}
		else {
			repset = 0;
			repcnt = 1;
		}
		if(c == '\r' || c == '\n' || trapped)
			break;

		lastgtcmdp = 0;

		mcursr = cursr;
		
		switch(curcmd = c){
		case '\b':
		case 'h':
			if( (mcursr -= repcnt) >= llim)
				mv_cursr(mcursr);
			else
				beep();
			break;
		case 'l':
		case ' ':
			if((mcursr += repcnt) < line_end)
				mv_cursr(mcursr);
			else
				beep();
			break;
		case '$':
			if(mcursr >= line_end || line_end <= llim)
				beep();
			else
				mv_cursr(line_end);
			break;
		case 'j':
		case '+':
			setundo();
			undo.posn = cur_elnumb;
			undo.uop = 4;
			mvto_lin(cur_elnumb + repcnt);
			undo.ocur = cur_elnumb;
			break;
		case '-':
		case 'k':
			setundo();
			undo.posn = cur_elnumb;
			undo.uop = 4;
			mvto_lin(cur_elnumb - repcnt);
			undo.ocur = cur_elnumb;
			break;
		case 'G':
			if(!repset){
				repcnt = cur_elnumb - Hist_Siz - 1;
				if(repcnt < 1)
					repcnt = 1;
			}
			setundo();
			undo.posn = cur_elnumb;
			mvto_lin(repcnt);
			undo.ocur = cur_elnumb;
			if(cur_elnumb != undo.posn)
				undo.uop = 4;
			break;
		case CTRL('L'):
			putch('\n');
			redraw_line(0);
			break;
		case 'w':
		case 'e':
		case 'b':
		case 'W':
		case 'E':
		case 'B':
			mcursr = gtword(c, repcnt, 0);
			if(mcursr < 0 || (cursr >= line_end-1 &&
							mcursr >= cursr))
				beep();
			else
				mv_cursr(mcursr);
			break;
		case '0':
			mv_cursr(llim);
			break;
		case '^':
			for(mcursr = llim ; mcursr < line_end ; mcursr++)
				if(eline[mcursr] != ' ')
					break;
			mv_cursr(mcursr);
			break;
		case '|':
			mv_cursr(llim + repcnt - 1);
			break;
		case ';':
			if(!last_ftFT){
				beep();
				break;
			}
			mcursr = find_c(last_ftFT, repcnt, last_ftFTc, 0);
			if(mcursr >= 0)
				mv_cursr(mcursr);
			else
				beep();
			break;
		case ',':
			switch(last_ftFT){
			case 't':
				c = 'T';
				break;
			case 'f':
				c = 'F';
				break;
			case 'F':
				c = 'f';
				break;
			case 'T':
				c = 't';
				break;
			default:
				c = 0;
				break;
			}
			if(!c){
				beep();
				break;
			}
			mcursr = find_c(c, repcnt, last_ftFTc, 0);
			if(mcursr >= 0)
				mv_cursr(mcursr);
			else
				beep();
			break;
		case 't':
		case 'f':
		case 'F':
		case 'T':
			mcursr = find_c(c, repcnt, 0, 0);
			if(mcursr >= 0)
				mv_cursr(mcursr);
			else
				beep();
			break;
		case '%':
			mcursr = mtchbrkt();
			if(mcursr >= 0)
				mv_cursr(mcursr);
			else
				beep();
			break;
		case 'A':
		case 'a':
		case 'I':
		case 'i':
		case 'R':
		case 'r':
		case 'S':
			setundo();
			insert_mode(c, repcnt);
			break;
		case 's':
			setundo();
			if(mcursr + repcnt <= line_end)
				insert_mode(c, repcnt);
			else
				beep();
			break;
		case 'd':
			setundo();
			mcursr = rd_xcmd(repcnt, c, kill_line, 0);
			if(mcursr < 0)
				break;
			nchars = mcursr - cursr;
			if(!nchars){
				beep();
				break;
			}
			if(nchars < 0){
				mv_cursr(mcursr);
				nchars = -nchars;
			}
			del_c(nchars, 0);
			break;
		case 'c':
			setundo();
			mcursr = rd_xcmd(repcnt, c, chng_line, 0);
			if(mcursr < 0)
				break;
			nchars = mcursr - cursr;
			if(!nchars){
				beep();
				break;
			}
			if(nchars < 0){
				mv_cursr(mcursr);
				nchars = -nchars;
			}
			insert_mode(c, nchars);
			break;
		case 'C':
			nchars = line_end - mcursr;
			if(!nchars){
				beep();
				break;
			}
			setundo();
			insert_mode(c, nchars);
			break;
		case 'D':
			nchars = line_end - mcursr;
			if(!nchars)
				beep();
			else {
				setundo();
				del_c(nchars, 0);
			}
			break;
		case 'x':
			setundo();
			del_c(repcnt, 0);
			break;
		case 'X':
			setundo();
			if(mcursr - repcnt < llim){
				beep();
				break;
			}
			mv_cursr(mcursr - repcnt);
			del_c(repcnt, 0);
			break;
		case '.':
			if(undo.ucmd == 0)
				beep();
			else
				dodotcmd(undo.ucmd);
			break;
		case 'u':
			if(undo.ucmd && undo.uop > 0)
				doundo();
			else
				beep();
			break;
		case 'U':
			setundo();
			kill_line();
			undo.uop = 3;
			if(DATAVALID(&Ubuf))
				addnchars(Ubuf.slen, Ubuf.bufp, (CHAR **)0,
								(CHAR **)0);
			savustr(Ubuf.bufp, Ubuf.slen, llim, 0);
			mv_cursr(llim);
			break;
			/*
			 * search operations
			 */
		case '/':
		case '?':
			/*
			 * do a save cur line.
			 * go into insert mode with a special flag set.
			 * when returned from routine, text is in eline
			 * do a search for this line. If found, do a move
			 * to this line. If not found, do a move to current
			 * line and beep. 
			 */
			lastsrch = c;
			if(cur_elnumb == hist_numb)
				sav_curline();
			
			free_ubuf(&srbuf);
			insert_mode(c, 1);

			if(trapped)
				break;

			if(!DATAVALID(&srbuf) || *srbuf.bufp != c){
				free_ubuf(&srbuf);
				lnum = hist_numb;
				beep();
			}
			else {
				lnum = dosrch(c);
				if(lnum < 0)
					lnum = hist_numb;
			}
			cur_elnumb = -1;	/* force movement */
			mvto_lin(lnum);
			break;
		case 'n':
		case 'N':
			/* repeat search with known search string. */
			if( (lastsrch != '/' && lastsrch != '?') ||
							srbuf.slen <= 0){
				beep();
				break;
			}
			lnum = dosrch( (c == 'n') ? lastsrch : 
					((lastsrch == '/') ? '?' : '/'));
			if(lnum < 0)
				break;
			mvto_lin(lnum);
			break;
		case 'y':
			setundo();
			mcursr = rd_xcmd(repcnt, c, yank_line, 0);
			if(mcursr < 0)
				break;
			nchars = mcursr - cursr;
			if(!nchars){
				beep();
				break;
			}
			if(nchars < 0)
				nchars = -nchars;
			else
				mcursr = cursr;
			sav_ubuf(&ubuf, nchars, eline + mcursr);
			break;
		case 'Y':
			setundo();
			yank_line();
			break;
		case 'p':
		case 'P':
			dopcmd(c, repcnt);
			break;
		case '~':
			setundo();
			dotilde(repcnt);
			break;
		case ESCAPE:
			if(!fc){
				beep();
				break;
			}
			eline[line_end] = 0;
			return(c);
		default:
			beep();
			break;
		}
	}
	if(trapped)
		longjmp(edit_chg, TRAPPED_EDIT);
	eline[line_end] = 0;
	return(c);
}

static void
dodotcmd(c)
int	c;
{
	int	ndels = 0;
	int	ndelp = 0;
	int	doins = 0;
	int	mcursr = cursr;
	struct	undo	xundo;
	CHAR	in_text[MAXLIN+1];
	CHAR	*itext = in_text;

	/* copy undo buf */
	xundo = undo;
	if(undo.uswaped){
		/* unswap undo buf */
		xundo.dels = undo.ins;
		xundo.ins = undo.dels;
	}
	undo.dels.bufp = 0;
	undo.ins.bufp = 0;
	setundo();
	undo.ucmd = c;
	edit_mode = INSERT_EDIT;
	switch(c){
	case 'A':
		undo.uop = 1;
		mv_cursr(line_end);
		doins++;
		break;
	case 'a':
	case 'p':
		undo.uop = 1;
		if(line_end != llim)
			mv_cursr(cursr+1);
		doins++;
		break;
	case 'i':
	case 'P':
		undo.uop = 1;
		doins++;
		break;
	case 'I':
		undo.uop = 1;
		mv_cursr(llim);
		doins++;
		break;
	case 'R':
	case 'r':
	case 'S':
	case 's':
		ndels = xundo.dels.slen;
		undo.uop = 3;
		ndelp = 2;
		doins++;
		break;
	case 'c':
		/*
		 * BUG here: what should we do if we get cc for a dotcmd?
		 * we do what ksh does which is to do what we have here.
		 * vi does something different - i.e. it effectively
		 * does nothing.
		 */
		mcursr = rd_xcmd(1, c, chng_line, 1);
		if(mcursr < 0)
			break;
		ndels = mcursr - cursr;
		if(!ndels)
			beep();
		else if(ndels < 0){
			mv_cursr(mcursr);
			ndels = -ndels;
		}
		
		ndelp = 2;
		undo.uop = 3;
		doins++;
		break;
	case 'C':
		ndels = line_end - mcursr;
		if(!ndels){
			beep();
			break;
		}
		undo.uop = 3;
		ndelp = 2;
		doins++;
		break;
	case 'd':
		mcursr = rd_xcmd(1, c, kill_line, 1);
		if(mcursr < 0){
			break;
		}
		ndels = mcursr - cursr;
		if(!ndels)
			beep();
		else if(ndels < 0){
			mv_cursr(mcursr);
			ndels = -ndels;
		}
		break;
	case 'D':
		ndels = line_end - mcursr;
		if(!ndels)
			beep();
		break;
	case 'x':
		ndels = xundo.dels.slen;
		if(ndels <= 0)
			beep();
		break;
	case 'X':
		ndels = xundo.dels.slen;
		if(mcursr - ndels < llim){
			beep();
			ndels = 0;
		}
		else
			mv_cursr(mcursr - ndels);
		break;
	case '~':
		dotilde(xundo.orepcnt);
		break;
	default:
		beep();
		break;
	}
	if(ndels > 0)
		del_c(ndels, ndelp);
	if(doins){
		mcursr = cursr;
		if(DATAVALID(&xundo.ins))
			addnchars(xundo.ins.slen, xundo.ins.bufp,
							&itext, (CHAR **)0);
		savustr(in_text, itext - in_text, mcursr, 0);
		if(cursr > llim)
			mv_cursr(cursr - 1);
	}
	free_ubuf(&xundo.dels);
	free_ubuf(&xundo.ins);
	edit_mode = COMMAND_EDIT;
	mv_cursr(cursr);
}

static void
doundo()
{
	if(undo.uop & 8){
		mv_cursr(undo.ocur);
		dotilde(undo.orepcnt);
		if(undo.uswaped)
			undo.uswaped = 0;
		else {
			undo.uswaped = 1;
			mv_cursr(undo.ocur);
		}
		return;
	}
	if(undo.uop & 4){
		if(undo.uswaped){
			undo.uswaped = 0;
			mvto_lin(undo.ocur);
		}
		else {
			undo.uswaped = 1;
			mvto_lin(undo.posn);
		}
		return;
	}
	edit_mode = INSERT_EDIT;
	if(undo.uswaped){
		undo.uswaped = 0;
		mv_cursr(undo.posn);
		if( (undo.uop & 2) && DATAVALID(&undo.dels))
			del_c(undo.dels.slen, 1);
		if( (undo.uop & 1) && DATAVALID(&undo.ins))
			addnchars(undo.ins.slen, undo.ins.bufp,
							(CHAR **)0, (CHAR **)0);
		mv_cursr(undo.ncur);
	}
	else {
		undo.ncur = cursr;
		mv_cursr(undo.posn);
		if( (undo.uop & 1) && DATAVALID(&undo.ins))
			del_c(undo.ins.slen, 1);
		if( (undo.uop & 2) && DATAVALID(&undo.dels))
			addnchars(undo.dels.slen, undo.dels.bufp,
						(CHAR **)0, (CHAR **)0);
		mv_cursr(undo.ocur);
		undo.uswaped = 1;
	}
	edit_mode = COMMAND_EDIT;
	mv_cursr(cursr);
}

static void
dopcmd(c, repcnt)
int	c, repcnt;
{
	int	mcursr;
	CHAR	in_text[MAXLIN+1];
	CHAR	*itext = in_text;

	setundo();
	if(!DATAVALID(&ubuf)){
		beep();
		return;
	}
	edit_mode = INSERT_EDIT;
	if(c == 'p' && line_end != llim)
		mv_cursr(cursr+1);
	undo.uop = 1;
	mcursr = cursr;
			
	while(repcnt-- > 0)
		addnchars(ubuf.slen, ubuf.bufp, &itext, (CHAR **)0);
	savustr(in_text, itext - in_text, mcursr, 0);
	if(cursr > llim)
		mv_cursr(cursr - 1);
	edit_mode = COMMAND_EDIT;
}

void
dotilde(repcnt)
int	repcnt;
{
	int	c;

	if(llim == line_end){
		undo.orepcnt = 0;
		beep();
		return;
	}
	undo.orepcnt = repcnt;
	if(cursr + repcnt >= line_end)
		repcnt = line_end - cursr;
	while(repcnt > 0){
		repcnt--;
		c = eline[cursr];
		if(c >= 'A' && c <= 'Z')
			c += 'a' - 'A';
		else if(c >= 'a' && c <= 'z')
			c += 'A' - 'a';
		VOID putxch(c);
		eline[cursr] = (CHAR)c;
		mv_cursr(++cursr);
	}
	undo.uop = 8;
}

static	void
insert_mode(c, repcnt)
int	c;
int	repcnt;
{
	int	mcursr;
	int	nchanged;
	int	iposn;
	int	inword;
	int	escaped;
	CHAR	in_text[MAXLIN+1];
	CHAR	*itext = in_text;
	CHAR	rep_text[MAXLIN+1];
	CHAR	*rtext = 0;
	int	srch = 0;
	CHAR	xc;

	edit_mode = INSERT_EDIT;

	iposn = cursr;
	switch(c){
	case '/':
	case '?':
		eline[llim] = (char)c;
		*itext++ = (char)c;
		line_end = llim + 1;
		cursr = line_end;
		eline[line_end] = 0;
		iposn = cursr;
		redraw_line(3);
		srch = 1;
		break;
		/*
		 * c and S are a problem, since we also have to save what
		 * we changed it to. so that we can do a change back again.
		 * this is not nice.
		 */
	case 'C':
	case 'c':
	case 's':
		if(repcnt)
			del_c(repcnt, 2);
		undo.uop = 3;
		/* must copy ubuf here */
		break;
	case 'S':
		nchanged = line_end - llim;
		sav_ubuf(&ubuf, nchanged, eline + llim);
		savustr(eline + llim, nchanged, llim, 1);
		undo.uop = 3;
		line_end = llim;
		cursr = llim;
		eline[line_end] = 0;
		redraw_line(3);
		/* must copy ubuf here */
		break;
	case 'I':
		undo.uop = 1;
		mv_cursr(llim);
		break;
	case 'R':
		undo.uop = 3;
		rtext = rep_text;
		break;
	case 'r':
		undo.uop = 3;
		do {
			c = readc();
			if(trapped)
				longjmp(edit_chg, TRAPPED_EDIT);
		} while(c == 0);
		if(repcnt > MAXLIN)
			repcnt = MAXLIN;
		set_mem(itext, repcnt, c);
		rtext = rep_text;
		addnchars(repcnt, itext, &itext, &rtext);
		savustr(in_text, itext - in_text, iposn, 0);
		savustr(rep_text, rtext - rep_text, iposn, 1);
		if(cursr > llim)
			mv_cursr(cursr - 1);
		edit_mode = COMMAND_EDIT;
		return;
	case 'A':
		undo.uop = 1;
		mv_cursr(line_end);
		break;
	case 'a':
		undo.uop = 1;
		if(line_end != llim)
			mv_cursr(cursr+1);
		break;
	default:
		undo.uop = 1;
		break;
	}
	iposn = cursr;
	escaped = 0;
	for(;;){
		pflush();
		c = readc();
		if(trapped)
			longjmp(edit_chg, TRAPPED_EDIT);
		if(c == 0)
			continue;

		if(escaped){
			escaped = 0;
			xc = (CHAR)c;
			addnchars(1, &xc, &itext, &rtext);
			continue;
		}

		if(c == ESCAPE)
			break;

		if(c == '\n' || c == '\r') {
			if(srch)
				break;
			else
				longjmp(edit_chg, INSERT_EDIT);
		}

		if(c == ch_kill){
			iposn = llim;
			itext = in_text;
			if(rtext)
				rtext = rep_text;
			if(!srch)
				kill_line();
			else {
				line_end = llim;
				cursr = llim;
				eline[line_end] = 0;
				redraw_line(3);
			}
		} else if(c == '\b' || c == ch_erase){
			if(itext > in_text){
				mv_cursr(cursr-1);
				del_c(1, 1);
				itext--;
				if(rtext)
					rtext--;
			}
			else
				beep();
		}
		else if(c == CTRL('w')){
			if(itext <= in_text){
				beep();
				continue;
			}
			inword = 0;
			
			for(mcursr = cursr; mcursr > iposn ; mcursr--)
				if(eline[mcursr-1] == ' '){
					if(inword)
						break;
				}
				else
					inword = 1;
			nchanged = cursr - mcursr;
			itext -= nchanged;
			if(rtext)
				rtext -= nchanged;
			mv_cursr(mcursr);
			del_c(nchanged, 1);
		}
		else if(c == ch_eof){
			beep();
		}
		else if(c == CTRL('v')){
			escaped = 1;
		}
		else if(c == '\t'){
			addnchars(8 - (cursr & 7), "        ", &itext, &rtext);
		}
		else {
			xc = (CHAR)c;
			addnchars(1, &xc, &itext, &rtext);
		}
	}
	if(srch){
		sav_ubuf(&srbuf, itext - in_text, in_text);
		edit_mode = COMMAND_EDIT;
		return;
	}
		
	savustr(in_text, itext - in_text, iposn, 0);
	if(rtext)
		savustr(rep_text, rtext - rep_text, iposn, 1);
	if(cursr > llim)
		mv_cursr(cursr - 1);
	edit_mode = COMMAND_EDIT;
}

static void
addnchars(nchars, buf, ibuf, rbuf)
int	nchars;
CHAR	*buf;
CHAR	**ibuf, **rbuf;
{
	CHAR	*p;
	int	nc, mcursr, nchanged;

	if(!nchars)
		return;
	if(cursr >= MAXLIN -1){
		beep();
		return;
	}
	p = eline + cursr;
	if(vsize(*p) > 1)
		putch('\b');

	if(rbuf && *rbuf){
		if(cursr + nchars >= MAXLIN)
			nchars = MAXLIN - cursr;

		/* do an overwrite */
		nc = nchars;
		if(cursr + nc > line_end)
			nc = line_end - cursr;
		if(nc)
			*rbuf = strmov(*rbuf, p, nc);
		
		if(ibuf)
			*ibuf = strmov(*ibuf, buf, nchars);
		VOID strmov(p, buf, nchars);
		mcursr = cursr + nchars;
		if(mcursr > line_end)
			line_end = mcursr;
	}
	else {
		if(line_end + nchars >= MAXLIN)
			nchars = MAXLIN - line_end;

		/* not at end of line */
		if(cursr < line_end){
			CHAR	*sp, *q;
			sp = eline + line_end;
			q = sp + nchars;
			while(sp >= p)
				*q-- = *sp--;
		}
		if(ibuf)
			*ibuf = strmov(*ibuf, buf, nchars);
		VOID strmov(p, buf, nchars);
		line_end += nchars;
		mcursr = cursr + nchars;
	}
	eline[line_end] = 0;
	setscend();
	nchanged = line_end - cursr + 1;
	if(nchanged < 1)
		nchanged = 1;
	if(cursr + nchanged >= scend){
		cursr = mcursr;
		redraw_line(0);
	}
	else {
		draw_from_cursr(nchanged);
		mv_cursr(mcursr);
	}
}

static	void
redraw_line(force)
int	force;
{
	CHAR	*p;
	int	i;
	int	scursr;
	int	savscr;
	int	xem = 0;

	if(cursr >= line_end){
		if(edit_mode == COMMAND_EDIT)
			cursr = line_end - 1;
		else if(cursr > line_end)
			cursr = line_end;
	}
	if(cursr < llim)
		cursr = llim;

	if(cursr < scstart || cursr >= scend || force)
		set_sc();
	putch('\r');

	putchs(eline, llim);
	if(scstart > llim)
		xem |= 2;
	savscr = llim;
	p = eline + scstart;
	for(i = scstart, scursr = llim ; scursr < scrlim ; i++, p++){
		if(i == cursr)
			savscr = scursr;
		if(i >= line_end){
			if(!xem && !lastxm && !(force & 2))
				break;
			scursr += putxch(' ');
		}
		else
			scursr += putxch(*p);
	}
	if(i < line_end)
		xem |= 1;
	if(xem || lastxm || (force & 2)){
		putchs(xemsgs[xem], 2);
		scursr += 2;
	}
	while(scursr > savscr){
		putch('\b');
		scursr--;
	}
	if(vsize(eline[cursr]) > 1)
		putch('^');
	lastxm = xem;
}

static	void
draw_from_cursr(nchanged)
int	nchanged;
{
	CHAR	*p;
	int	i;
	int	xem = 0;
	int	savscr;
	int	scursr;
	int	ocursr;

	ocursr = cursr;
	if(cursr >= line_end){
		if(edit_mode == COMMAND_EDIT)
			cursr = line_end - 1;
		else if(cursr > line_end)
			cursr = line_end;
	}
	if(cursr < llim)
		cursr = llim;
	if(scstart > llim)
		xem |= 2;
	scursr = llim;
	p = eline + scstart;
	for(i = scstart ; i < cursr ; i++, p++)
		scursr += vsize(*p);

	savscr = scursr;
	if(cursr != ocursr)
		for(; i < ocursr ; i++, p++)
			scursr += vsize(*p);

	for(; scursr < scrlim ; p++, i++, nchanged--){
		if(i >= line_end){
			if(!xem && !lastxm && !nchanged)
				break;
			scursr += putxch(' ');
		}
		else
			scursr += putxch(*p);
	}
		
	if(i < line_end)
		xem |= 1;
	if(xem || lastxm || nchanged){
		putchs(xemsgs[xem], 2);
		scursr += 2;
	}
	while(scursr > savscr){
		putch('\b');
		scursr--;
	}
	if(vsize(eline[cursr]) > 1)
		putch('^');
	lastxm = xem;
}

static	void
mv_cursr(ncursr)
int	ncursr;
{
	CHAR	*p;
	int	i;

	if(ncursr >= line_end){
		if(edit_mode == COMMAND_EDIT)
			ncursr = line_end - 1;
		else if(ncursr > line_end)
			ncursr = line_end;
	}
	if(ncursr < llim)
		ncursr = llim;
	if(ncursr < scstart || ncursr >= scend){
		cursr = ncursr;
		redraw_line(0);
		return;
	}
	i = ncursr - cursr;
	if(!i)
		return;
	p = eline + cursr;
	cursr = ncursr;
	if(vsize(*p) > 1)
		putch('\b');
	if(i < 0){
		i = -i;
		do {
			putchs("\b\b", vsize(*--p));
		}while(--i);
	}
	else {
		do {
			VOID putxch(*p++);
		} while(--i);
	}
	if(vsize(*p) > 1)
		putch('^');
}

static	void
mvto_lin(lnum)
int	lnum;
{
	savl_t	*savlp;

	if(lnum == cur_elnumb){
		redraw_line(3);
		return;
	}
	if(lnum < 0 || lnum > hist_numb || lnum <= hist_numb - Hist_Siz){
		beep();
		redraw_line(3);
		return;
	}
	if(lnum == hist_numb){		/* back to current line. */
		recov_line(&clbuf);
		cursr = clcur;
		free_ubuf(&clbuf);
	}
	else {				/* moveing off of current line. */
		savlp = &edit_history[lnum % Hist_Siz];
		if(!DATAVALID(savlp)){
			beep();
			redraw_line(3);
			return;
		}
		cursr = llim;
		if(cur_elnumb == hist_numb)
			sav_curline();
		recov_line(savlp);
	}
	cur_elnumb = lnum;
	redraw_line(3);
}

static	int
dosrch(cmdc)
int	cmdc;
{
	int	i, lnum;
	int	incr = (cmdc == '?') ? 1 : -1;
	CHAR	*mstr = srbuf.bufp + 1;
	int	nchrs = srbuf.slen - 1;
	savl_t	*ptr;
	int	bol = 0;

	if(*mstr == '^'){
		mstr++;
		nchrs--;
		bol++;
	}
	lnum = cur_elnumb + incr + Hist_Siz;
	for(i = 1 ; i < Hist_Siz ; i++, lnum += incr){
		ptr = &edit_history[lnum % Hist_Siz];
		if(!DATAVALID(ptr))
			break;
		if(ptr->slen < nchrs)
			continue;
		if(substr(mstr, nchrs, ptr->bufp, ptr->slen, bol)){
			while(lnum < hist_numb - Hist_Siz)
				lnum += Hist_Siz;
			while(lnum > hist_numb)
				lnum -= Hist_Siz;
			return(lnum);
		}
	}
	beep();
	return(-1);
}

static int
substr(str, slen, ofstr, oflen, bol)
CHAR	*str, *ofstr;
int	slen, oflen, bol;
{
	int	retrys;
	CHAR	*p, *q;
	int	icnt;

	retrys = oflen - slen;
	do  {
		for(p = str, q = ofstr, icnt = slen ; icnt ; icnt--, p++, q++)
			if(*p != *q)
				break;
		if(!icnt)
			return(1);
		ofstr++;
	} while(--retrys >= 0 && !bol);
	return(0);
}

static	void
del_c(nchars, ubufupdate)
int	nchars;
int	ubufupdate;
{
	CHAR	*p, *q;
	CHAR	*eq;
	int	nchanged;

	if(cursr >= line_end){
		beep();
		return;
	}
	nchanged = line_end - cursr;
	if(nchars > nchanged)
		nchars = nchanged;
	if(line_end - nchars < llim){
		beep();
		return;
	}
	p = &eline[cursr];
	q = p + nchars;
	switch(ubufupdate){
	case 0:	/* normal case */
		sav_ubuf(&ubuf, nchars, p);
		savustr(p, nchars, cursr, 1);
		undo.uop = 2;
		break;
	case 1:	/* no update */
		break;
	case 2:	/* a change update */
		savustr(p, nchars, cursr, 1);
		break;
	}
	eq = eline + line_end;
	if(vsize(*p) > 1)
		putch('\b');
	while(q <= eq){
		if(!NORMAL_CHAR(*p))
			nchanged++;
		*p++ = *q++;
	}
	line_end -= nchars;
	eline[line_end] = 0;
	setscend();
	if(cursr < scstart || cursr + nchanged >= scend)
		redraw_line(2);
	else
		draw_from_cursr(nchanged);
}

static	void
yank_line()
{
	sav_ubuf(&ubuf, line_end - llim, eline + llim);
}

static	void
chng_line()
{
	if(line_end == llim){
		beep();
		return;
	}
	mv_cursr(llim);
	insert_mode('c', line_end - llim);
}

static	void
sav_ubuf(savl, nchars, sbuf)
savl_t	*savl;
int	nchars;
CHAR	*sbuf;
{
	if(savl->bufp)
		mfree( (MEMP)savl->bufp);
	savl->slen = nchars;
	savl->bufp = (CHAR *)mmalloc( (ival)(nchars + 1));
	if(nchars)
		VOID strmov(savl->bufp, sbuf, nchars);
	savl->bufp[nchars] = 0;
}

static	void
free_ubuf(savl)
savl_t	*savl;
{
	if(savl->bufp){
		mfree( (MEMP)savl->bufp);
		savl->bufp = 0;
	}
	savl->slen = 0;
}

static	void
setundo()
{
	free_ubuf(&undo.dels);
	free_ubuf(&undo.ins);
	undo.dels.slen = -1;
	undo.ins.slen = -1;
	undo.ocur = cursr;
	undo.ncur = -1;
	undo.ucmd = curcmd;
	undo.uop = 0;
	undo.uswaped = 0;
}

static	void
savustr(buf, len, posn, isdel)
CHAR *buf;
int len, posn, isdel;
{
	sav_ubuf(isdel ? &undo.dels : &undo.ins, len, buf);
	if(posn >= 0)
		undo.posn = posn;
}

static	void
sav_curline()
{
	sav_ubuf(&clbuf, line_end - llim, eline + llim);
	clcur = cursr;
}

static	void
recov_line(savl)
savl_t	*savl;
{
	if(llim)
		VOID strmov(eline, line, llim);

	line_end = llim;
	if(DATAVALID(savl)){
		VOID strmov(eline + llim, savl->bufp, savl->slen);
		line_end += savl->slen;
	}
	eline[line_end] = 0;
}

static	void
set_sc()
{
	int	i, sc;
	int	ncur;
	CHAR	*p;

	ncur = cursr;

	for(i = sc = llim, p = eline + i ; i < ncur ; i++, p++)
		sc += vsize(*p);

	if(sc >= scrlim){
		/* cursor is beyond end of line. */
		sc = (scrlim - llim) / 2;
		while(sc > 0){
			sc -= vsize(*p--);
			i--;
		}
		scstart = i;
	}
	else
		scstart = llim;
	setscend();
}

static	void
setscend()
{
	int	i;
	int	scrwidth = scrlim - llim;
	CHAR	*p;

	scend = scstart;
	p = eline + scstart;
	for(i = 0 ; i < scrwidth && scend < line_end; scend++, p++)
		i += vsize(*p);
	scend += (scrwidth - i);	/* this assumes space = 1 char width */
}

static	void
kill_line()
{						/* save the whole line */
	int	nchars;

	nchars = line_end - llim;
	sav_ubuf(&ubuf, nchars, eline + llim);
	savustr(eline + llim, nchars, llim, 1);
	undo.uop = 2;
	line_end = llim;
	cursr = llim;
	eline[line_end] = 0;
	redraw_line(3);
}

static	int
rd_xcmd(repcnt, cmdc, dfunc, dotcmd)
int	repcnt, cmdc;
void	(*dfunc)(void);
int	dotcmd;
{
	int	mcursr;
	int	c;
	int	xrepcnt;

	lastgtcmdp = lastgtcmd;
	if(!dotcmd){
		c = readc();
		if(trapped)
			return(-1);
		if(c >= '1' && c <= '9'){
			xrepcnt = c - '0';
			for(;;){
				c = readc();
				if(trapped)
					return(-1);
				if(c < '0' || c > '9'){
					repcnt *= xrepcnt;
					if(repcnt < 0 || repcnt > MAXLIN)
						repcnt = MAXLIN;
					break;
				}
				xrepcnt = xrepcnt * 10 + c - '0';
			}
		}
		*lastgtcmdp++ = (CHAR)c;
		undo.orepcnt = repcnt;
	}
	else {
		c = *lastgtcmdp++;
		repcnt = undo.orepcnt;
	}
	if(c == cmdc && dfunc){
		/* 't'is a duplicate. do it to the whole line. */
		/* and the only thing that you can do is a cc or a dd or a yy */
		(*dfunc)();
		return(-1);
	}
	switch(c){
	case 'f':
	case 'F':
	case 't':
	case 'T':
		mcursr = find_c(c, repcnt, 0, dotcmd);
		if(mcursr >= cursr)
			mcursr++;
		break;
	case 'W':
	case 'w':
		if(cmdc == 'c'){
			if(eline[cursr] == ' '){
				if(--repcnt == 0){
					mcursr = cursr + 1;
					break;
				}
			}
			c = ((c == 'w') ? 'e' : 'E');
		}
		mcursr = gtword(c, repcnt, 1);
		break;
	case 'e':
	case 'b':
	case 'E':
	case 'B':
		mcursr = gtword(c, repcnt, 1);
		break;
	case 'l':
		mcursr = cursr + repcnt;
		if(mcursr > line_end)
			mcursr = -1;
		break;
	case 'h':
		mcursr = cursr - repcnt;
		if(mcursr <= llim)
			mcursr = -1;
		break;
	case '0':
		mcursr = llim;
		break;
	case '$':
		mcursr = line_end;
		break;
	case '%':
		mcursr = mtchbrkt();
		if(mcursr > cursr)
			mcursr++;
		break;
	default:
		lastgtcmdp = lastgtcmd;
		mcursr = -1;
		break;
	}
	if(mcursr < 0)
		beep();
	if(!dotcmd)
		*lastgtcmdp = 0;
	return(mcursr);
}

static	int
find_c(c, repcnt, last_c, dotcmd)
int	c, repcnt;
int	last_c, dotcmd;
{
	int	mcursr = cursr;
	int	xc;
	int	found = 0;
	
	if( (xc = last_c) <= 0){
		if(!dotcmd || !lastgtcmdp){
			xc = readc();
			if(trapped)
				return(-1);
			last_ftFT = c;
			last_ftFTc = xc;
			if(lastgtcmdp)
				*lastgtcmdp++ = (CHAR)xc;
		}
		else
			xc = *lastgtcmdp++;
	}

	if(c == 'f' || c == 't'){
		for(found = 0; mcursr < line_end && found < repcnt;)
			if(eline[++mcursr] == xc)
				found++;
		if(c == 't'){
			if(mcursr > llim)
				mcursr--;
			else
				found = 0;
		}
	}
	else {
		for(; mcursr > llim && found < repcnt;)
			if(eline[--mcursr] == xc)
				found++;
		if(c == 'T'){
			if(mcursr < line_end - 1)
				mcursr++;
			else
				found = 0;
		}
	}
	if(found >= repcnt)
		return(mcursr);
	return(-1);
}

static	int
is_inword(c, ascw)
int	c, ascw;
{
	if(c == ' ')
		return(2);
	if(!ascw)
		return(1);
	return((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
							(c >= '0' && c <= '9'));
}

static	int
gtword(c, repcnt, cw)
int	c, repcnt, cw;
{
	int	mcursr = cursr;
	int	wtype, rtype;
	int	ascword;

	ascword = (c < 'A' || c > 'Z');
	switch(c){
	case 'W':
	case 'w':
		do {
			if(mcursr >= line_end)
				return(-1);
			wtype = is_inword(eline[mcursr], ascword);
			while(mcursr < line_end){
				rtype = is_inword(eline[++mcursr], ascword);
				if(rtype != wtype){
					if(rtype != 2)
						break;
					wtype = rtype;
				}
			}
		} while(--repcnt > 0);
		break;
	case 'E':
	case 'e':
		do {
			wtype = is_inword(eline[mcursr+1], ascword);
			for(;mcursr < line_end;mcursr++){
				rtype = is_inword(eline[mcursr+1], ascword);
				if(rtype != wtype){
					if(wtype != 2)
						break;
					wtype = rtype;
				}
			}
		}while(--repcnt > 0);
		if(cw && mcursr < line_end)
			mcursr++;
		break;
	case 'B':
	case 'b':
		do {
			if(mcursr <= llim)
				return(-1);
			wtype = is_inword(eline[mcursr-1], ascword);
			for(; mcursr > llim ; mcursr--){
				rtype = is_inword(eline[mcursr-1], ascword);
				if(rtype != wtype){
					if(wtype != 2)
						break;
					wtype = rtype;
				}
			}
		} while(--repcnt > 0);
		break;
	}
	return(mcursr);
}

static	int
mtchbrkt()
{
	int	mcursr = cursr;
	int	nc = 0, rbseen = 0;

	/*
	 * search forward for matching '('
	 */
	while(mcursr < line_end){
		if(eline[mcursr] == ')'){
			if(--nc <= 0)
				break;
		}
		else if(eline[mcursr] == '('){
			rbseen++;
			nc++;
		}
		mcursr++;
	}
	if(mcursr >= line_end)
		return(-1);
	if(nc < 0 && !rbseen){
		/* must search back for previous bracket */
		nc = 0;
		while(mcursr > llim){
			if(eline[mcursr] == ')')
				nc++;
			else if(eline[mcursr] == '('){
				if(--nc <= 0)
					return(mcursr);
			}
			mcursr--;
		}
	}
	return( (nc <= 0) ? mcursr : -1);
}
			
static CHAR *
do_ctrl_d(pcursr, plim)
CHAR	*pcursr, *plim;
{
	CHAR	*savc;
	const	struct	tabl	*l;
	const	CHAR	*flist = 0;
	int	ndone = 0;
	int	i = 0;
	int	sslen;
	int	force = 0;

	savc = pcursr - 1;
	if(savc < plim || noedit)
		return( (CHAR *)0);

	if(*savc == '.' && savc > plim){
		force = 1;
		savc--;
	}
	if(is_inword( (int)*savc, 1) != 1)
		return( (CHAR *)0);

	while(savc >= plim && is_inword(*savc, 1) == 1){
		savc--;
		i++;
	}
	savc++;
	for(l = table ; l->string ; l++){
		if(*l->string != *savc)
			continue;
		sslen = slen( (char *)l->string);
		if(sslen < i)
			continue;
		if(!substr(savc, i, (CHAR *)l->string, sslen, 1))
			continue;
		if(!force || flist == 0)
			flist = l->string;
		putchs(crlf, 2);
		putchs("        ", 8);
		putchs(l->string, sslen);
		ndone++;
	}
	
	if(ndone){
		putchs(crlf, 2);
		if(ndone == 1 || force){
			while(*flist && savc < eline + MAXLIN)
				*savc++ = *flist++;
			pcursr = savc;
		}
		for(i = pcursr - eline, pcursr = eline; i ; i--)
			VOID putxch(*pcursr++);
	}
	else
		beep();
	return(pcursr);
}

/*      put out a character uses buffere output of up to 256 characters
 *    It used to use a static buffer but this is a waste of space so
 *    it now uses gblock as this is never used during an edit.
 *      A value of zero for the parameter will flush the buffer.
 */

static void
putch(c)
int	c;
{
#ifdef	MSDOS
	if(c &= MASK)
		bdos(6, (char)c);
#else
	if(xpbuflen >= MAXLIN)
		pflush();
	xpbuf[xpbuflen++] = (CHAR) c;
#endif
}

static void
pflush()
{
	if(xpbuflen > 0)
		VOID write(1, (char *)xpbuf, xpbuflen);
	xpbuflen = 0;
}

static void
putchs(sp, len)
const	char	*sp;
int	len;
{
	CHAR	*s = (CHAR *)sp;

	if(len + xpbuflen < MAXLIN){
		VOID strmov(xpbuf + xpbuflen, s, len);
		xpbuflen += len;
	}
	else {
		for(;*s && len > 0 ; s++, len--)
			putch(*s);
	}
}

static	int
putxch(c)
int	c;
{
	if(NORMAL_CHAR(c)){
		putch(c);
		return(1);
	}
	putch('^');
	if(c == '\177')
		putch('?');
	else
		putch(c + 'A'-1);
	return(2);
}

static	int
vsize(c)
int	c;
{
	return(NORMAL_CHAR(c) ? 1 : (c ? 2 : 0));
}

static	void
beep()
{
	putch('\007');
}
