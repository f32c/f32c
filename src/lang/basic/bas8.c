/*
 * BASIC by Phil Cockcroft
 */
#include        "bas.h"

/*
 *      This file contains all the standard commands that are not placed
 *    anywhere else for any reason.
 */

static	void	clear_prog(void);
static	int	mypwrite(filebufp, CHAR *, int), def_fn(int, int);
static	lpoint  get_end(void);
static	STR	strpat(STR, STR, STR);

/*
 *      The 'for' command , this is fairly straight forward , but
 *    the way that the variable is not allowed to be indexed is
 *    dependent on the layout of variables in core.
 *      Most of the fiddly bits of code are so that all the variables
 *    are of the right type (real / integer ). The code for putting
 *    a '1' in the step for default cases is not very good and could be
 *    improved.
 *      A variable is accessed by its displacement from 'earray'
 *    it is this index that speeds execution ( no need to search through
 *    the variables for a name ) and that enables the next routine to be
 *    so efficient.
 */

int
forr()
{
	struct forst *p;
	struct	entry	*ep;
	int	vty;
	int	dir = DIR_INC;
	value   start;
	value   iend;
	value   istep;
	value	*l;

	l= (value *)getname(0);
	vty= (int)vartype;
	ep = curentry;
	if(vartype == SVAL || ep->dimens)	/* string or array element */
		error(2);               /* variable required */
	if(getch()!='=')
		error(SYNTAX);
	eval();                         /* get the from part */
	putin(&start, vty);              /* convert and move the right type */
	if(getch()!=TO)
		error(SYNTAX);
	eval();                         /* the to part */
	putin(&iend, vty);
	if(getch()==STEP){
		eval();                 /* the step part */
		if(vartype != RVAL){
			if(res.i < 0)
				dir = DIR_DEC;
		}
		else if(res.f < ZERO)
			dir = DIR_DEC;
		putin(&istep, vty);
	}
	else {
		point--;                /* default case */
#ifndef	SOFTFP
		if(vty != RVAL)
			istep.i = 1;
		else
			istep.f = ONE;
#else
		res.i=1;
		vartype = IVAL;
		putin(&istep, vty);
#endif
	}
	check();                                /* syntax check */
				/* have we had it in a for loop before */
	for(p = estack ; p ; p = p->prev)
		if(p->fortyp == FORTYP){
			if(p->fnnm == ep)
				goto got;   /* if so then reset its limits */
		}
		else if(p->fortyp == FNTYP)
			break;

	/*
	 * grow the stack
	 */
	p = (forstp)mmalloc((ival)sizeof(struct forst));
	if((p->prev = estack) != 0)
		p->prev->next = p;
	else
		bstack = p;
	p->next = 0;
	estack = p;
	p->fnnm=ep;
	p->fortyp = FORTYP;
	p->forvty = (char)vty;

got:    p->elses=elsecount;             /* set up all information for the */
	p->stolin=stocurlin;            /* next routine */
	p->pt=point;
	p->fordir = (char)dir;
	p->final = iend;
	p->step = istep;
	*l = start;	/* set the starting value */
	normret;
}

/*
 *      the 'next' command , this does not need an argument , if there is
 *    none then the most deeply nested 'next' is accessed. If there is
 *    a list of arguments then the variable name is accessed and a search
 *    is made for it. ( next_without_for error ). Then the step is added
 *    to the varable and the result is compared to the final. If the loop
 *    is not ended then the stack is set to the end of this 'for' structure
 *    and a return is executed. Otherwise the stack is popped and a return
 *    to the required line is performed.
 */

int
next()
{
	struct forst *p;
	value  *l;
	int    c;

	c=getch();
	point--;
	if(istermin(c)){                /* no argument */
		for(p = estack ; p ; p = p->prev)
			if(p->fortyp == FORTYP){
				l = &p->fnnm->_dval;
				goto got;
			}
			else if(p->fortyp == FNTYP)
				break;
		error(18);      /* no next */
	}
for(;;){
	l= (value *)getname(0);
	for(p = estack ; p ; p = p->prev)
		if(p->fortyp == FORTYP){
			if(p->fnnm == curentry)
				goto got;
		}
		else if(p->fortyp == FNTYP)
			error(51);
	error(18);                      /* next without for */
got:;
#ifdef	SOFTFP
	if( (vartype = p->forvty) != RVAL){
#else
	if(p->forvty != RVAL){
#endif
#ifdef pdp11
		foreadd(p->step.i,l);
#else
#ifdef  VAX_ASSEM                       /* if want to use assembler */
		l->i += p->step.i;
		asm("        bvc nov");         /* it is a lot faster.... */
		    error(35);
		asm("nov:");
#else
		long   m = p->step.i;
		m += l->i;
		if(IS_OVER(l->i, p->step.i, m))
			error(35);
		else
			l->i = (itype)m;
#endif
#endif
		if(p->fordir == DIR_DEC){
			if( l->i >= p->final.i)
				goto nort;
			else goto rt;
		}
		else if( l->i <= p->final.i)
			goto nort;
	}
	else {
		fadd(&p->step, l );
#ifdef	NaN
		if(NaN(l->f))
			(*fpfunc)();
#endif
		if(p->fordir == DIR_DEC){
#ifndef SOFTFP
			if( l->f >= p->final.f)
				goto nort;
			else goto rt;
		}
		else if( l->f <= p->final.f)
			goto nort;
#else
			if(cmp(l,&p->final)>=0 )
				goto nort;
			goto rt;
		}
		else  if(cmp(l,&p->final)<= 0)
			goto nort;
#endif
	}
rt:                       /* don't loop - pop the stack */
	if((estack = p->prev) == 0)
		bstack = 0;
	else
		p->prev->next = 0;
	clr_stack(p);
	if(getch()==',')
		continue;
	point--;
	break;
nort:
	stocurlin=p->stolin;           	/* go back to the 'for' */
					/* obscure reasons */
	point = p->pt;
	elsecount=p->elses;
	if(p->next){
		clr_stack(p->next);
		p->next = 0;
		estack = p;
	}
	break;
	}
	normret;
}

/*
 *      The 'gosub' command , This uses the same structure as 'for' for
 *    the storage of data. A gosub is identified by the flag 'fr' in
 *    the 'for' structure being zero. This just gets the line on which
 *    we are on and sets up th structure. Gosubs from immeadiate mode
 *    are dealt with and this is one of the obscure reasons for the
 *    the comment and code in 'return' and 'next'.
 */

void
bld_gosub()
{
	forstp   pt;

	pt = (forstp)mmalloc((ival)sizeof(struct forst));
	if((pt->prev = estack) != 0)
		pt->prev->next = pt;
	else
		bstack = pt;
	pt->next = 0;
	estack = pt;
	pt->fortyp = GOSTYP;
	pt->elses = elsecount;
	pt->pt = point;
	pt->stolin = stocurlin;
}

int
gosub()
{
	lpoint l;

	l=getbline();
	check();
	bld_gosub();
	stocurlin=l;
	point= l->lin;
	elsecount=0;
	return(-1);     /* return to execute the next instruction */
}

/*
 *      The 'return' command this just searches the stack for the
 *    first gosub/return it can find, pops the stack to that level
 *    and returns to the correct point. Deals with returns to
 *    immeadiate mode, as well.
 */

int
retn()
{
	struct forst   *p;

	check();
	for(p = estack ; p ; p = p->prev)
		if(p->fortyp == GOSTYP)
			goto got;
		else if(p->fortyp == FNTYP)
			break;
	error(21);              /* return without gosub */
got:
	elsecount=p->elses;
	point=p->pt;
	stocurlin=p->stolin;
	if( (estack = p->prev) == 0)
		bstack = 0;
	else
		p->prev->next = 0;
	clr_stack(p);
	normret;
}

/*
 *      The 'run' command , run will execute a program by putting it in
 *    runmode and setting the start address to the start of the program
 *    or to the optional line number. It clears all the variables and
 *    closes all files.
 */

int
runn()
{
	lpoint p;
	lnumb	l;
	int	c;
	int	rflag = 0;
	STR	st;

	c = getch();
	point--;
	p = program;
	if(istermin(c))
		goto got;
	l=getlin();
	if(l == NOLNUMB){
		if(c != ','){
			st = stringeval();
			NULL_TERMINATE(st);
			if(getch() == ','){
				if(getch() != 'r')
					error(SYNTAX);
				rflag = 1;
			}
			else
				point--;
			check();
			/*
			 * run file in str
			 */
			if((c=open( (char *)st->strval,0))== -1)
				error(15);
			FREE_STR(st);
			clear_prog();
			trap_env.e_stolin = 0;
			readfi(c, (lpoint)0, 0);
			inserted=0;   /* say we don't actually want to */
			p = program;
		}
		else {
			point++;
			if(getch() != 'r')
				error(SYNTAX);
			rflag = 1;
			check();
		}
	}
	else {
		if(getch() == ','){
			if(getch() != 'r')
				error(SYNTAX);
			rflag = 1;
		}
		else
			point--;
		check();
		p = getsline(l);
	}
got:
	clear();   /* zap the variables */
	if(!rflag)
		closeall();
	if(!p)                 /* no program so return */
		reset();
	stocurlin=p;
	point=p->lin;
	elsecount=0;
	return(-1);             /* return to execute the next instruction */
}

/*
 *      The 'end' command , checks its syntax ( no parameters ) then
 *    gets out of what we were doing.
 */

int
endd()
{
	check();
	reset();
	normret;
}

/*
 *      The 'goto' command , simply gets the required line number
 *    and sets the pointers to it. If in immeadiate mode , go into
 *    runmode and zap the stack .
 */

int
gotos()
{
	lpoint p;

	p=getbline();
	check();
	if(!stocurlin){
		clr_stack(bstack);		/* zap the stack */
		bstack = estack = 0;
	}
	point=p->lin;
	stocurlin=p;
	elsecount=0;

	return(-1);
}

/*
 *      The 'print' command , The code for this routine is rather weird.
 *    It works ( well ) for all types of printing ( including files ),
 *    but it is a bit 'kludgy' and could be done better ( I don't know
 *    how ). Every expression must be followed by a comma a semicolon
 *    or the end of a statement. To get it all to work was tricky but it
 *    now does and that is all that can be said for it.
 *      The use of filedes assumes that an integer has the same size as
 *      a structure pointer. If this is not the case. This system will not
 *      work ( nor will most of the rest of the interpreter ).
 */

static	void	doprint(int, int);

int
print()
{
	doprint(0, 0);
	normret;
}

int
bwrite()
{
	doprint(0, 1);
	normret;
}


/*
 * fp is a null argument
 */
/*ARGSUSED*/
static	int
mypwrite(filebufp fp, CHAR *buf, int len)
{

	return((int)write(1, (char *)buf, (unsigned)len));
}

static  const	CHAR    spaces[]="                ";    /* 16 spaces */

static	void
doprint(islp, iswrt)
int	islp, iswrt;
{
	ival    i;
	int     c;
	int    (*outfunc)(filebufp, CHAR *, int);
	ival   *curcursor;     /* pointer to the current cursor */
					/* 'posn' if a file, or 'cursor' */
	int     Twidth;                 /* width of the screen or of the */
	filebufp filedes = 0;           /* file. BLOCKSIZ if a file */
	ival	tmpw;
	STR	st;
	STR	patstr = 0;
	STR	ost;
	int	is_str_pat = -1;
	struct	str_info savpat = {.strlen = -1};
	static	CHAR	comma[] = ",";
	static	CHAR	quote[] = "\"";

	c=getch();
	if(c=='#'){
		i=evalint();
		if( (c = getch()) !=','){
			if(!istermin(c))
				error(SYNTAX);
		}
		else
			c=getch();
		filedes=getf(i,_WRITE);
		if(filedes->use & _BLOCKED)
			error(29);
		outfunc= putfile;               /* see bas6.c */
		curcursor= &filedes->posn;
		Twidth = filedes->bufsiz;
	}
	else {
		outfunc = mypwrite;
		curcursor= &cursor;
		Twidth = ter_width;
	}
	if(c == USING){
		if(iswrt)
			error(SYNTAX);
		patstr = stringeval();
		if(getch() != ';')
			error(SYNTAX);
		if(!patstr->strlen)
			error(BADFORMAT);
		c = getch();
		savpat = *patstr;
	}
	point--;

	for(;;){
		if(istermin(c)){
			VOID (*outfunc)(filedes, (CHAR *)nl, 1);
			*curcursor=0;
			break;
		}
		else if(c==TABB){                       /* tabing */
			if(patstr)
				error(SYNTAX);
			point++;
			if(*point++!='(')
				error(SYNTAX);
			i=evalint();
			if(getch()!=')')
				error(SYNTAX);

			while(!trapped && (tmpw = i - *curcursor) > 0){
				if(tmpw > sizeof(spaces) - 1)
					tmpw = sizeof(spaces) - 1;
				VOID (*outfunc)(filedes, (CHAR *)spaces, tmpw);
				*curcursor += tmpw;
			}
			*curcursor %= Twidth;
			c=getch();
		}
		else if(c==',' || c==';'){
			if(iswrt)
				error(SYNTAX);
			point++;
		}
		else {
			ost = 0;
			if(!patstr || is_str_pat < 0)
				is_str_pat = checktype();
			if(is_str_pat){
				st = stringeval();
				if(patstr){
					ost = st;
					st = strpat(ost, patstr, &savpat);
				}
				if(iswrt){
					VOID (*outfunc)(filedes, quote, 1);
					*curcursor = (*curcursor + 1) % Twidth;
				}
			}
			else {
				eval();
				if(patstr)
					st = mathpat(patstr);
				else
					st = mgcvt();
			}
			VOID (*outfunc)(filedes, st->strval, st->strlen);
			*curcursor = (*curcursor + st->strlen) % Twidth;
			FREE_STR(st);
			if(ost)
				FREE_STR(ost);
			c=getch();
			if(iswrt && is_str_pat){
				VOID (*outfunc)(filedes, quote, 1);
				*curcursor = (*curcursor + 1) % Twidth;
			}
		}
		if(c==',' ||c==';'){
			if(iswrt){
				VOID (*outfunc)(filedes, comma, 1);
				*curcursor = (*curcursor + 1) % Twidth;
			}
			if(c==',' && !patstr){
				tmpw = 16 - *curcursor % 16;
				VOID (*outfunc)(filedes, (CHAR *)spaces,tmpw);
				*curcursor = (*curcursor + tmpw) % Twidth;
			}
			c=getch();
			point--;
			if(istermin(c))
				break;
			continue;
		}
		else if(!istermin(c))
			error(SYNTAX);
		point--;
	}
	if(patstr)
		FREE_STR(patstr);
}

static	STR
strpat(st, spat, savpat)
STR	st, spat, savpat;
{
	STR	outstr;
	CHAR	*outend;
	CHAR	*outp;
	CHAR	*pat, *epat;
	ival	olen;
	ival	curpos;
	ival	flen;

	if(!spat->strlen){
		assert(savpat->strlen != -1);
		spat->strlen = savpat->strlen;
		spat->strval = savpat->strval;
	}
	if(st->strlen + spat->strlen >= MAX_STR)
		error(BADFORMAT);
	olen = st->strlen + spat->strlen;

	outstr = ALLOC_STR(olen);
	outend = outstr->strval + olen;
	outp = outstr->strval;

	for(pat = spat->strval, epat = pat + spat->strlen ; pat < epat ;){
		switch(*pat++){
		default:
			if(outp >= outend - 1){
				olen += 32;
				if(olen >= MAX_STR)
					error(9);
				curpos = outp - outstr->strval;
				RESERVE_SPACE(outstr, olen);
				outend = outstr->strval + olen;
				outp = outstr->strval + curpos;
			}
			*outp++ = *(pat - 1);
			continue;
		case '!':
			if(st->strlen >= 1)
				flen = 1;
			else
				flen = 0;
			break;
		case '\\':
			flen = 2;
			while(pat < epat && *pat == ' '){
				flen++;
				pat++;
			}
			if(pat >= epat || *pat != '\\')
				error(BADFORMAT);
			pat++;
			break;
		case '&':
			flen = st->strlen;
			break;
		}
		if(outp + flen >= outend){
			olen += 32 + flen;
			if(olen >= MAX_STR)
				error(9);
			curpos = outp - outstr->strval;
			RESERVE_SPACE(outstr, olen);
			outend = outstr->strval + olen;
			outp = outstr->strval + curpos;
		}
		if(flen <= st->strlen){
			if(flen)
				outp = strmov(outp, st->strval, flen);
		}
		else {
			outp = strmov(outp, st->strval, st->strlen);
			set_mem(outp, flen - st->strlen, ' ');
			outp += flen - st->strlen;
		}
		break;
	}
	spat->strlen -= (pat - spat->strval);
	spat->strval = pat;
	outstr->strlen = outp - outstr->strval;
	return(outstr);
}

int
matprint()
{
	ival    i;
	STR	st;
	int    (*outfunc)(filebufp, CHAR *, int);
	ival   *curcursor;     /* pointer to the current cursor */
					/* 'posn' if a file, or 'cursor' */
	int     Twidth;                 /* width of the screen or of the */
	filebufp filedes = 0;           /* file. BLOCKSIZ if a file */
	ival	tmpw;
	struct	entry	*ep;
	ival	d1, d2;
	valp	vpp;
	ival	*ivpp = NULL;
	char	vty;

	if(getch() == '#'){
		i=evalint();
		if( getch() !=',')
			error(SYNTAX);
		filedes=getf(i,_WRITE);
		if(filedes->use & _BLOCKED)
			error(29);
		outfunc= putfile;               /* see bas6.c */
		curcursor= &filedes->posn;
		Twidth = filedes->bufsiz;
	}
	else {
		outfunc = mypwrite;
		curcursor= &cursor;
		Twidth = ter_width;
		point--;
	}

	do {
		ep = getmat(0);
		vty = vartype;
		d1 = ep->_dims[0];
		d2 = (ep->dimens == 1) ? 1 : ep->_dims[1];
		vpp = (valp)(MEMP)ep->_darr;
		if(vty != RVAL)
			ivpp = &vpp->i;
		while(d2 > 0){
			for(i = 0 ; i < d1 ; i++){
				if(vty == RVAL)
					res = *vpp++;
				else {
					assert(ivpp != NULL);
					res.i = *ivpp++;
				}
				st = mgcvt();

				VOID(*outfunc)(filedes, st->strval, st->strlen);
				*curcursor = (*curcursor + st->strlen) % Twidth;
				tmpw = 16 - *curcursor % 16;
				VOID (*outfunc)(filedes, (CHAR *)spaces,tmpw);
				*curcursor = (*curcursor + tmpw) % Twidth;

				FREE_STR(st);
			}
			VOID (*outfunc)(filedes, (CHAR *)nl, 1);
			*curcursor  = 0;
			d2--;
		}
	}while(getch() == ',');
	point--;
	normret;
}

/*
 *      The 'if' command , no real problems here but the 'else' part
 *    could do with a bit more checking of what it's going over.
 */

int
iff()
{
	CHAR   *p;
	int    c;
	int    elsees;

	eval();
	if(getch()!=THEN)
		error(SYNTAX);
	if(!IS_ZERO(res)){
		c=getch();		/* true */
		point--;
		elsecount++;		/* say `else`s are allowed */
		if(isdigit(c))		/* if it's a number then */
			VOID gotos();	/* execute a goto */
		return(-1);		/* return to execute another ins. */
	}
	for(elsees = 0, p= point; *p ; p++) /* skip all nested 'if'-'else' */
		if(*p==(CHAR)ELSE){	/* pairs */
			if(--elsees < 0){
				p++;
				break;
			}
		}
		else if(*p==(CHAR)IF)
			elsees++;
	point = p;			/* we are after the else or at */
	if(!*p)
		normret;
	while(*p++ == ' ');		/* end of line */
	p--;				/* ignore the space after else */
	if(isdigit(*p))			/* if number then do a goto */
		VOID gotos();
	return(-1);
}

/*
 *      The 'on' command , this deals with everything , it has to do
 *    its own searching so that undefined lines are not accessed until
 *    a 'goto' to that line is actually required.
 *    Deals with on_gosubs from immeadiate mode.
 */

int
onn()
{
	lnumb	lnm[128];
	lnumb	*l;
	lpoint p;
	itype   m;
	int     k;

	if(getch()==ERROR){
		if(getch()!=GOTO)
			error(SYNTAX);
		errtrap();      /* do the trapping of errors */
		normret;
	}
	point--;
	m = evalint() - 1;
	if((k=getch())!= GOTO && k != GOSUB)
		error(SYNTAX);
	for(l=lnm;;){        /* get the line numbers */
		if( (*l++ = getlin()) == NOLNUMB)
			error(5);       /* line number required */
		if(getch()!=',')
			break;
	}
	point--;
	check();
	if(m < 0 || lnm + m >= l)	/* index is out of bounds */
		normret;                /* so return */

	p = getsline(lnm[m]);		/* find the line */

	if(k== GOSUB)
		bld_gosub();
	else {
		if(!stocurlin){		/* gotos in immeadiate mode */
			clr_stack(bstack);
			bstack = estack = 0;
		}
	}
	stocurlin = p;
	point = p->lin;
	elsecount = 0;
	return(-1);
}

/*
 *      The 'cls' command , neads to set the terminal into 'rare' mode
 *    so that there is no waiting on the page clearing ( form feed ).
 */

static	const	struct	t_info {
	const	CHAR	*t_term;
	const	CHAR	*t_clr;
} t_clr_info[] = {
	"vt100",	"\033[H\033[J$",
	"at386",	"\033[2J\033[H",
	"ansi",		"\033[H\033[J",
	"xterm",	"\033[H\033[2J",
	0, "\014",
};

int
cls()
{
	struct	t_info	*tp;
	const	CHAR	*p, *q;
	char	*tvar;

#ifndef f32c
	set_term();
#endif
	tvar = getenv("TERM");
	if(!tvar|| !*tvar)
		tvar = "";
	for(tp = (struct t_info  *)t_clr_info; tp->t_term ; tp++){
		for(p = tp->t_term, q = (const CHAR *)tvar ; *p ; p++, q++)
			if(*p != *q)
				break;
		if(!*p && !*q)
			break;
	}
	prints( (char *)tp->t_clr);
#ifndef f32c
	rset_term(0);
#endif
	cursor = 0;
	normret;
}

/*
 *      The 'base' command , sets the start index for arrays to either
 *      '0' or '1' , simple.
 */

int
base()
{
	itype	i;

	i=evalint();
	check();
	if(i && i!=1)
		error(28);      /* bad base value */
	baseval= (int)i;
	normret;
}

/*
 *      The 'rem' and '\'' command , ignore the rest of the line
 */

int
rem() {  return(GTO); }

/*
 *      The 'let' command , all the work is done in assign , the first
 *    getch() is to get the pointer in the right place for assign().
 */

int
lets()
{
	assign(0);
	normret;
}

/*
 *      The 'clear' command , clears all variables , and closes all files
 */

int
clearl()
{
	check();
	clear();
	closeall();
	normret;
}

/*
 *      The 'list' command , can have an optional two arguments and
 *    a dash is also used.
 *      Most of this routine is the getting of the arguments. All the
 *    actual listing is done in listl() , This routine should call write()
 *    and not clr(), but then the world is not perfect.
 */

int
list()
{
	lnumb	l1,l2;
	lpoint p;

	l1=getlin();
	if(l1 == NOLNUMB){
		l1=0;
		l2= NOLNUMB;
		if(getch()=='-'){
			if( (l2 = getlin()) == NOLNUMB)
				error(SYNTAX);
		}
		else
			point--;
	}
	else  {
		if(getch()!='-'){
			l2 = l1;
			point--;
		}
		else
			l2 = getlin();
	}
	check();
	p = program;
	if(l1)
		for(; p ; p = p->next)
			if(p->linnumb != CONTLNUMB && p->linnumb >= l1)
				break;
	if(!p)
		reset();
	if(l1 == l2 && l1 != p->linnumb)
		reset();
	while(p && (p->linnumb == CONTLNUMB || p->linnumb <=l2) && !trapped){
		l1=listl(p);
		line[l1++] = '\n';
		VOID write(1,line,l1);
		p = p->next;
	}
	reset();
	normret;
}

/*
 *      The routine that does the listing of a line , it searches through
 *    the table of reserved words if it find a byte with the top bit set,
 *    It should ( ha ha ) find it.
 *      This routine could run off the end of line[] since line is followed
 *    by nline[] this should not cause any problems.
 *      The result is in line[].
 */
int
listl(lpoint p)
{
	CHAR   *q;
	const	struct tabl *l;
	CHAR    *r;
	int	t;

	/* do the linenumber */
	r = str_cpy((CHAR *)"     ", line);
	if(p->linnumb != CONTLNUMB) {
		if (p->linnumb > 9999)
			r -= 4;
		else if (p->linnumb > 999)
			r -= 3;
		else if (p->linnumb > 99)
			r -= 2;
		else if (p->linnumb > 9)
			r -= 1;
		r = str_cpy((CHAR *)printlin(p->linnumb), r - 1);
	}

	for(q= p->lin; *q && r < &line[MAXLIN]; q++){
		if(*q & (CHAR)SPECIAL){              /* reserved words */
			if((t = UC(*q)) >= EXFUNC)
				t = ((t-EXFUNC) << 8) + UC(*++q);
			for(l=table;l->chval;l++){
				if(l->chval == t){
					r=str_cpy((CHAR *)l->string, r);
					break;
				}
			}
		}
		else if(*q<' '){                /* do special characters */
			*r++ ='\\';
			*r++ = *q+ ('a'-1);
		}
		else {
			if(*q == '\\')          /* the special character */
				*r++ = *q;
			*r++ = *q;              /* non special characters */
		}
	}
	if(r >= &line[MAXLIN])                  /* get it back a bit */
		r = &line[MAXLIN-1];
	*r=0;
	return(r-line);                 /* length of line */
}

/*
 *      The 'stop' command , prints the message that it has stopped
 *    and then exits the 'user' program.
 */

int
stop()
{
	check();
	dostop(0);
	normret;
}

/*
 *      Called if trapped is set (by control-c ) and just calls dostop
 *    with a different parameter to print a slightly different message
 */

void
dobreak()
{
	dostop(1);
}

/*
 *      prints out the 'stopped' or 'breaking' message then exits.
 *    These two functions were lumped together so that it might be
 *    possible to add a 'cont'inue command at a latter date ( not
 *    implemented yet ) - ( it is now ).
 */

void
dostop(i)
int	i;
{
	if(cursor){
		cursor=0;
		prints( (char *)nl);
	}
	prints( (i) ? "breaking" : "stopped" );
	if(stocurlin){
		prsline(" at line ", stocurlin);
		if(!intrap){            /* save environment */
			cancont=i+1;
			save_env(&cont_env);
		}
	}
	prints( (char *)nl);
	reset();
}

/*      the 'cont' command - it seems to work ?? */

int
cont()
{
	check();
	if(contpos && !stocurlin){
		ret_env(&cont_env);	/* restore environment */
		clr_stack(bstack);	/* recover the old stack */
		bstack = savbstack;
		estack = savestack;
		savestack = savbstack = 0;
		if(contpos==1){
			contpos=0;
			normret;        /* stopped */
		}
		contpos=0;              /* ctrl-c ed */
		return(-1);
	}
	contpos=0;
	error(CANTCONT);
	normret;
}

/*
 *      The 'delete' command , will only delete the required lines if it
 *    can find the two end lines. stops ' delete 1' etc. as a slip up.
 *      very slow algorithm. But who cares ??
 */

int
bdelete()
{
	lpoint	p3;
	lpoint p1,p2;

	p1=getbline();
	if(getch()!='-')
		error(SYNTAX);
	p2=getbline();
	check();
	if(p1->linnumb > p2->linnumb)
		reset();
	if(p1 == program)
		program = p2->next;
	else {
		for(p3 = program ; p3->next != p1 ; p3 = p3->next);
		p3->next = p2->next;
	}
	for(p2 = p2->next; p1 != p2 ; p1 = p3){
		p3 = p1->next;
		mfree( (MEMP)p1);
	}
	reset();
	normret;
}

/*
 *      The 'shell' command , calls the v7 shell as an entry into unix
 *    without going out of basic. Has to set the terminal in a decent
 *    mode , else 'ded' doesn't like it.
 *      Clears out all buffered file output , so that you can see what
 *    you have done so far, and sets your userid to your real-id
 *    this stops people becoming unauthorised users if basic is made
 *    setuid ( for games via runfile of the command file ).
 */

#ifdef	MSDOS
#include <process.h>

shell()
{
	char	*s;

	check();
	flushall();

	s = getenv("COMSPEC");
	if(!s || *s == 0)
		s = "command.com";
	spawnl(P_WAIT, s, s, (char *)0);
	normret;
}

#else

int
shell()
{
	int	i;
	STR	st = 0;
	int	c;
	memp	cmd = 0;

	c = getch();
	point--;
	if(!istermin(c)){
		st = stringeval();
		if(st->strlen){
			NULL_TERMINATE(st);
			cmd = st->strval;
		}
		else {
			FREE_STR(st);
			st = 0;
		}
	}
	check();
	i = do_system((memp)cmd);
	if(i == -1 && cmd == 0)
		prints("cannot shell out\n");
	if(st)
		FREE_STR(st);
	normret;
}


#ifndef f32c
int
do_system(cmd)
CHAR	*cmd;
{
	int	status;

	flushall();
	status = system(cmd);
	set_term();
	rset_term(0);
	return(status);
}
#endif /* !f32c */

#endif

static	const	char	bdircmd[] = "ls -C ";
#define	BDIRCMD_LEN	(sizeof(bdircmd)-1)

static	const	char	bdirlcmd[] = "ls -l ";
#define	BDIRLCMD_LEN	(sizeof(bdirlcmd)-1)

static	void	bdircom(const char *, ival);

int
bdir()
{
	bdircom(bdircmd, (ival)BDIRCMD_LEN);

	normret;
}

int
bdirl()
{
	bdircom(bdirlcmd, (ival)BDIRLCMD_LEN);

	normret;
}

static void
bdircom(cmd, clen)
const char *cmd;
ival	clen;
{
	STR	stc;
	STR	st;
	int	c;

	c = getch();
	point--;
	if(!istermin(c)){
		st = stringeval();
		if(st->strlen == 0){
			FREE_STR(st);
			st = 0;
		}
	}
	else
		st = 0;
	check();
	if(st && st->strlen + clen + 1 > MAX_STR)
		error(9);
	stc = ALLOC_STR( (ival) (clen + 1 + (st ? st->strlen : 0)) );
	stc->strlen = clen;
	VOID strmov(stc->strval, (CHAR *)cmd, stc->strlen);
	if(st){
		VOID strmov(stc->strval+stc->strlen, st->strval, st->strlen);
		stc->strlen += st->strlen;
	}
		
	NULL_TERMINATE(stc);

	flushall();

	(void) do_system(stc->strval);
	FREE_STR(stc);
	if(st)
		FREE_STR(st);
}

/*
 *      The 'edit' command , can only edit in immeadiate mode , and with the
 *    specified line ( maybe could be more friendly here , no real need to
 *    since the editor is the same as on line input.
 */

int
editl()
{
	lpoint p, pe, pt;
	int	i;
	lnumb	l1, l2;
	lpoint	lastl;
	int	fd;
	char	fname_tmp[MAXLIN];
	char	*fname;
	char	*et;
	static	const char	tname[] = "/tmp/be_tmp.";
	
	if(stocurlin || noedit)
		error(13);      /* illegal edit */

	l1=getlin();
        if(l1 == NOLNUMB){
                l2= NOLNUMB;
                if(getch()=='-'){
                        if( (l2 = getlin()) == NOLNUMB)
                                error(SYNTAX);
                }
                else
                        point--;
        }
        else  {
                if(getch()!='-'){
                        l2 = l1;
                        point--;
                }
                else
                        l2 = getlin();
        }
        check();
	
	/*
	 * l1 == NOLNUMB && l2 == NOLNUMB -> Full file
	 * l1 == NOLNUMB && l2 != NOLNUMB -> from start to l2 inclusive
	 * l1 != NOLNUMB && l2 == NOLNUMB -> from l1 -> end of file
	 * l1 != NOLNUMB && l2 != NOLNUMB -> from l1 -> l2 inclusive
	 */
	p = getsline(l1);
	if(l2 == NOLNUMB)
		pe = 0;
	else
		pe = getsline(l2);
	/*
	 * Check to see that end line is > first line
	 */
	if(l1 != NOLNUMB && l2 != NOLNUMB && l1 > l2)
		error(13);
	/*
	 * p == start, pe == last line pointer or NULL of no last line
	 */
	if(p == 0)
		goto do_edit;
	if(l1 == l2 && pe && (p->next == 0 || p->next->linnumb != CONTLNUMB)){
		/*
		 * OLD edit mode.
		 */
		i=listl(p);
		VOID edit((ival)0, (ival)i, (ival)0);	/* do the edit */
		if(trapped)             /* ignore it if exited via cntrl-c */
			reset();
		i=compile(0, nline, 0);
		if(linenumber)       /* ignore it if there is no line number */
			insert(i);
		reset();                /* return to 'ready' */
		normret;
	}
	if(pe)
		while(pe->next && pe->next->linnumb == CONTLNUMB)
			pe = pe->next;
	else
		for(pe = p ; pe->next ; pe = pe->next);
	/*
	 * PE now points to the last line to be edited.
	 */
do_edit:;
	et = getenv("EDITOR");
	if(et == 0 || *et == 0)
		et = "vi";
	et = str_cpy(et, fname_tmp);
	*et++ = ' ';
	fname = et;
	et = str_cpy( (CHAR *)tname, et);
	VOID str_cpy(printlin( (lnumb)getpid()), et);
	/*
	 * Create temporary file
	 */
	fd = creat(fname, 0600);
	if(fd < 0)
		error(13);

	for(pt = p;pt;pt = pt->next){
		i = listl(pt);
		line[i++] = '\n';
		if( write(fd, (char *)line, (unsigned)i) != i)
			error(60);
		if(pt == pe)
			break;
	}
	VOID close(fd);
	i = do_system(fname_tmp);
	if(i != 0){
		/*
		 * If edit failed, give up
		 */
		VOID unlink(fname);
		reset();
	}
	/*
	 * reopen file
	 */
	fd = open(fname, O_RDONLY);
	VOID unlink(fname);
	if(fd < 0)
		error(13);
	if(p){
		/*
		 * now delete the old lines
		 */
		if(p == program){
			program = pe->next;
			lastl = 0;
		}
		else {
			for(pt = program ; pt->next != p ; pt = pt->next);
			pt->next = pe->next;
			lastl = pt;
		}
		for(pe = pe->next; p != pe ; p = pt){
			pt = p->next;
			mfree( (MEMP)p);
		}
	}
	else
		lastl = 0;

	readfi(fd, lastl, 1);
	
	reset();                /* return to 'ready' */
	normret;
}

/*
 *      The 'auto' command , allows input of lines with automatic line
 *    numbering. Most of the code is to do with getting the arguments
 *    otherwise the loop is fairly simple. There are three ways of getting
 *    out of this routine. cntrl-c will exit the routine immeadiately
 *    If there is no linenumber then it also exits. If the line typed in is
 *    terminated by an ESCAPE character the line is inserted and the routine
 *    is terminated.
 */

int
dauto()
{
	lnumb	start, end;
	ival	i1;
	lnumb   i2;
	long    l;
	int     c;

	i2=autoincr;
	start=getlin();
	if( start != NOLNUMB){
		if(getch()!= ','){
			point--;
			i2=autoincr;
		}
		else {
			i2=getlin();
			if(i2 == NOLNUMB)
				error(SYNTAX);
		}
	}
	else
		start=autostart;
	check();
	autoincr=i2;
	end=i2;
	for(;;){
		i1= str_cpy( (CHAR *)printlin(start), line) - line;
		line[i1++]=' ';
		c=edit((ival)0, i1, (ival)1);
		if(trapped)
			break;
		i1=compile(0, nline, 0);
		if(!linenumber)
			break;
		insert((int)i1);
		if( (l= (long)start+end) >=65530){
			autostart=100;
			autoincr=10;
			error(6);       /* undefined line number */
		}
		start+=end;
		autostart= (lnumb)l;
		if(c == ESCAPE)
			break;
	}
	reset();
	normret;
}

/*
 *      The 'save' command , saves a basic program on a file.
 *    It just lists the lines adds a newline then writes them out
 */

int
save()
{
	lpoint p;
	int    fp;
	int    i;
	STR	st;

	st = stringeval();     /* get the name */
	NULL_TERMINATE(st);
	check();
	if((fp=creat( (char *)st->strval,0644))== -1)
		error(14);              /* cannot creat file */
	FREE_STR(st);
	for(p= (lpoint)program ; p ; p = p->next ){
		i=listl(p);
		line[i++]='\n';
					/* could be buffered ???? */
		if(write(fp, (char *)line,(unsigned)i) != i)
			error(60);
	}
	VOID close(fp);
	normret;
}

/*
 *      The 'load' command , loads a program from a file. The old
 *    program (if any ) is wiped.
 *      Most of the work is done in readfi, ( see also error ).
 */

int
load()
{
	int    fp;
	STR	st;

	st = stringeval();		/* get the file name */
	NULL_TERMINATE(st);
	check();
	if((fp=open( (char *)st->strval,0))== -1)
		error(15);              /* can't open file */
	FREE_STR(st);
	clear_prog();
	readfi(fp, (lpoint)0, 0);                     /* read the new file */
	reset();
	normret;
}

static	void
clear_prog()
{
	lpoint	p, p1;

	for(p1 = p = program ; p ; p = p1){
		p1 = p->next;
		mfree( (MEMP)p);
	}
	program = 0;
}

/*
 *      The 'merge' command , similar to 'load' but does not zap the old
 *    program so the two files are 'merged' .
 */

int
merge()
{
	int    fp;
	STR	st;

	st = stringeval();
	NULL_TERMINATE(st);
	check();
	if((fp=open( (char *)st->strval,0))== -1)
		error(15);
	FREE_STR(st);
	readfi(fp, (lpoint)0, 0);
	reset();
	normret;
}

/*
 *      The routine that actually reads in a file. It sets up readfile
 *    so that if there is an error ( linenumber overflow ) , then error
 *    can pick up the pieces , else the number of file descriptors are
 *    reduced and can ( unlikely ), run out of them so stopping any file
 *    being saved or restored , ( This is the reason that all files are
 *    closed so meticulacly ( see 'chain' and its  pipes ).
 */

void
readfi(fp, lp, isedit)
int	fp;
lpoint	lp;
int	isedit;
{
	CHAR   *p;
	int     i;
	CHAR    chblock[BLOCKSIZ];
	int     nleft=0;
	int    special=0;
	CHAR   *q = NULL;

	readfile=fp;
	inserted=1;     /* make certain variables are cleared */
	p=line;         /* input into line[] */
	last_ins_line = lp;
	for(;;){
		if(!nleft){
			q=chblock;
			if( (nleft=read(fp, (char *)q,BLOCKSIZ)) <= 0)
				break;
		}
		assert(q != NULL);
		*p= *q++;
		nleft--;
		if(special){
			special=0;
			if(*p>='a' && *p<='~'){
				*p -= ('a'-1);
				continue;
			}
		}
		if(*p =='\n'){
			*p=0;
			i=compile(0, nline, 0);
			if(!linenumber){
				if(!i){
					p = line;
					continue;
				}
				if(!last_ins_line && program && !isedit)
					goto bad;
				linenumber = CONTLNUMB;
				ins_line(last_ins_line, i);
				p = line;
				continue;
			}
			insert(i);
			p=line;
			isedit = 0;
			continue;
		}
		else if(*p == '\t'){
			i = (8 - (p - line)) & 7;
			while(i && p < &line[MAXLIN]){
				*p++ = ' ';
				i--;
			}
			continue;
		}
		else if(*p<' ')
			goto bad;
		else if(*p=='\\')
			special++;
		if(++p > &line[MAXLIN])
			goto bad;
	}
	if(p!=line)
		goto bad;
	VOID close(fp);
	readfile=0;
	return;

bad:    VOID close(fp);         /* come here if there is an error */
	readfile=0;             /* that readfi() has detected */
	error(57);              /* stops error() having to tidy up */
}

/*
 *      The 'new' command , This deletes any program and clears all
 *    variables , can take an extra parameter to say how many files are
 *    needed. If so then clears the number of buffers ( default 2 ).
 */

int
neww()
{
	int    i,c;

	c=getch();
	point--;
	if(!istermin(c)){
		i=evalint();
		check();
		if(i<0 || i> MAXFILES)
			i=2;
		ncurfiles = 0;
		maxfiles = i;
	}
	else
		check();
	autostart=100;
	autoincr=10;
	baseval=1;
	drg_opt = OPT_RAD;
	closeall();             /* flush the buffers */
	clear_prog();	/* delete the program */
	clear();	/* clear the variables */
	reset();
	NO_RET;
}

/*
 *      The 'chain' command , This routine chains the program.
 *      all simple numeric variables are kept. ( max of 4 k ).
 *      all other variables are cleared.
 *      runs the loaded file
 *      files are kept open
 *
 *      error need only check pipe[0] to see if it is to be closed.
 */

int
chain()
{
	int     fp;
	lpoint	lp;
	lnumb	ln = NOLNUMB;
	int	all = 0;
	STR	st;

	st = stringeval();
	NULL_TERMINATE(st);

	if(getch() == ','){
		ln = getlin();
		if(ln == NOLNUMB){
			point--;
			if(getch() != ALL)
				error(SYNTAX);
			all = 1;
		}
		else {
			if(getch() == ','){
				if(getch() != ALL)
					error(SYNTAX);
				all = 1;
			}
			else
				point--;
		}
	}
	else
		point--;
	check();
	if((fp=open( (char *)st->strval,0))== -1)
		error(15);
	FREE_STR(st);
	clear_prog();
	ch_clear(all);
	trap_env.e_stolin = 0;
	readfi(fp, (lpoint)0, 0);
	inserted=0;                     /* say we don't actually want to */
	stocurlin = program;		/* defeat getslines algorithm */
	lp = getsline(ln);
	stocurlin = lp;
	if(!lp)
		reset();
	point= lp->lin;
	elsecount=0;
	return(-1);                     /* now run the file */
}

/* define a function def fna() - can have up to 127 parameters */


int
defproc()
{
	return(def_fn(IS_MPR, 1));
}

int
bdeffn()
{
	return(def_fn(IS_MFN, 1));
}

int
deffunc()
{
	return(def_fn(IS_MFN, 0));
}

static	int
def_fn(ftyp, dftyp)
int	ftyp, dftyp;
{
	struct  deffn   fn;     /* temporary place for evaluation */
	struct deffn *p;
	CHAR   *l;
	int     i=0;
	int     c;
	struct	entry	*ep;
	char	vty;
	lpoint	lp;
	struct	entry	*args[FN_MAX_ARGS];
	struct	entry	**arg, **carg;

	c = getch();
	if(!dftyp){
		if(c != FN)
			error(SYNTAX);
	}
	else
		point--;
	/*LINTED*/
	if(!isalpha(*point))
		error(SYNTAX);
	ep = getnm(ISFUNC, 1);
	if(ep)
		error(REDEFFN);

	ep = newentry;
	vty = vartype;		/* save return type of function */

	fn.ncall = 0;
	arg = args;

	if(*point=='('){        /* get arguments */
		point++;
		for(;i< FN_MAX_ARGS;i++){
			VOID getname(0);	/* don't need value just entry*/
			if(curentry->dimens)
				error(VARREQD);
			if(vartype == SVAL && (curentry->flags & IS_FSTRING))
				error(VARREQD);
			for(carg = args ; carg < arg ; carg++)
				if(*carg == curentry)
					error(42);
			*arg++ = curentry;
					/* save type of arguments */
			if((c=getch())!=',')
				break;
		}
		if(c!= ')')
			error(SYNTAX);
		i++;
	}
	fn.narg = (char)i;
	fn.mline = IS_FN;
	if( (c = getch()) != '='){
		/*
		 * a multi line function
		 */
		/*
		 * make certain that this is the last command on the line
		 */
		if(c)
			error(SYNTAX);
		point--;
		if(!stocurlin)
			reset();
		for(lp = stocurlin->next ; lp ; lp = lp->next){
			for(l = lp->lin ; *l == ' ' ; l++);
			if(*l == (CHAR)FNEND)
				break;
		}
		if(!lp)
			error(42);
		lp = lp->next;
		fn.mline = (char)ftyp;
		fn.mpnt = stocurlin->next;
							  /* get the space */
		i = fn.narg * sizeof(struct entry *);
		ep->_deffn = (deffnp) mmalloc((ival)(sizeof(struct deffn) + i));
		fn.vargs = (struct entry **)(ep->_deffn + 1);
		for(arg = fn.vargs, i = 0 ; i < fn.narg ; i++, arg++)
			*arg = args[i];
		*ep->_deffn = fn;
		newentry = 0;
		ep->vtype = ISFUNC | vty;
		if(!lp)
			reset();
		stocurlin = lp;
		point = lp->lin;
		elsecount = 0;
		return(-1);
	}
	if(ftyp != IS_MFN)
		error(SYNTAX);
	l = point;
	while(*l++ == ' ');
	point = --l;
	while(!istermin(*l))    /* get rest of expression */
		l++;
	if(l==point)
		error(SYNTAX);
	c = ((l - point + 1) + WORD_MASK) & ~WORD_MASK;
	i = c + (fn.narg * sizeof(struct entry *)) + sizeof(struct deffn);
	p= (deffnp) mmalloc((ival)i);			/* get the space */
	/*LINTED*/
	fn.vargs = (struct entry **)((memp)(p + 1) + c);
	for(arg = fn.vargs, i = 0 ; i < fn.narg ; i++, arg++)
		*arg = args[i];
	newentry = 0;
	ep->vtype = ISFUNC | vty;
	*p = fn;
	*strmov(p->exp, point, (ival)(l - point)) = 0;
	point = l;
	ep->_deffn = p;
	normret;
}

/* the repeat part of the repeat - until loop */
/* now can have a construct like  'repeat until eof(1)'. */
/* It might be of use ?? it's a special case */

int
rept()
{
	struct forst   *p;
	CHAR   *tp;

	if(getch() == UNTIL){
		tp = point;     /* save point */
		eval();         /* calculate the value */
		check();        /* check syntax */
				/* now repeat the loop until <>0 */
		while(IS_ZERO(res) && !trapped){
			point = tp;
			eval();
		}
		if(trapped)
			return(-1);
		normret;
	}
	point--;
	check();
	p = (forstp)mmalloc((ival)sizeof(struct forst));
	if((p->prev = estack) != 0)
		p->prev->next = p;
	else
		bstack = p;
	p->next = 0;
	estack = p;
	p->pt = point;
	p->stolin = stocurlin;
	p->elses = elsecount;
	p->fortyp = REPTYP;	/* get the right type */
	normret;
}

/* the until bit of the command */

int
untilf()
{
	struct forst   *p;
	eval();
	check();
	for(p = bstack ; p ; p = p->prev)
		if(p->fortyp != FORTYP){
			if(p->fortyp == REPTYP)
				goto got;
			error(51);
		}
	error(48);
got:
	if(IS_ZERO(res)){	/* not true so repeat loop */
		elsecount = p->elses;
		point = p->pt;
		stocurlin = p->stolin;
				/* pop all off stack up until here */
		if(p->next){
			clr_stack(p->next);
			p->next = 0;
		}
		estack = p;
	}
	else {			/* pop stack if finished here. */
		if( (estack = p->prev) == 0)
			bstack = 0;
		else
			p->prev->next = 0;
		clr_stack(p);
	}
	normret;
}

/* while part of while - wend construct. This is like repeat until unless
 * loop fails on the first time. (Yeuch - next we need syntax checking on
 * input ).
 */


int
whilef()
{
	CHAR    *spoint = point;
	lpoint lp;
	struct forst   *p;

	eval();
	check();
	if(!IS_ZERO(res)){
		/* got to go through it once so make it look like a */
		/* repeat - until */
		p = (forstp)mmalloc((ival)sizeof(struct forst));
		if((p->prev = estack) != 0)
			p->prev->next = p;
		else
			bstack = p;
		p->next = 0;
		estack = p;
		p->pt = spoint;
		p->stolin = stocurlin;
		p->elses = elsecount;
		p->fortyp = WHLTYP;	/* the right type */
		normret;
	}
	lp=get_end();                   /* otherwise find a wend */
	check();
	if(stocurlin)
		stocurlin =lp;
	normret;
}

/* the end part of a while loop - wend */

int
wendf()
{
	struct forst   *p;
	CHAR    *spoint =point;

	check();
	for(p = estack ; p ; p = p->prev)
		if(p->fortyp != FORTYP){
			if(p->fortyp == WHLTYP)
				goto got;
			error(51);
		}
	error(49);
got:
	point = p->pt;
	eval();
	if(IS_ZERO(res)){		/* failure of the loop */
		if( (estack = p->prev) == 0)
			bstack = 0;
		else
			p->prev->next = 0;
		clr_stack(p);
		point = spoint;
		normret;
	}
				/* pop stack after an iteration */
	if(p->next){
		clr_stack(p->next);
		p->next = 0;
	}
	estack = p;
	elsecount = p->elses;
	stocurlin = p->stolin;
	normret;
}

/* get_end - search from current position until found a wend statement - of
 * the correct nesting. Keeping track of elses + if's(Yeuch ).
 */

static	lpoint
get_end()
{
	lpoint lp;
	CHAR   *p;
	int    c;
	int     wcount=0;
	int     rcount=0;
	int     flag=0;

	p= point;
	lp= stocurlin;
	if(getch()!=':'){
		if(!stocurlin)
			error(50);
		if( (lp = lp->next) == 0)
			error(50);
		point = lp->lin;
		elsecount=0;
	}
	for(;;){
		c=getch();
		if(c==WHILE)
			wcount++;
		else if(c==WEND){
			if(--wcount <0)
				break;  /* only get out point in loop */
		}
		else if(c==REPEAT)
			rcount++;
		else if(c==UNTIL){
			if(--rcount<0)
				error(51);      /* bad nesting */
		}
		else if(c==IF){
			flag++;
			elsecount++;
		}
		else if(c==ELSE){
			flag++;
			if(elsecount)
				elsecount--;
		}
		else if(c==REM || c==DATA || c==QUOTE){
			if(!stocurlin)
				error(50);      /* no wend */
			if( (lp = lp->next) == 0)
				error(50);      /* no wend */
			point =lp->lin;
			elsecount=0;
			flag=0;
			continue;
		}
		else for(p=point;!istermin(*p);p++)
			if(*p=='"' || *p=='`'){
				c= (int)*p++;
				while(*p && *p != (CHAR) c)
					p++;
				if(!*p)
					break;
			}
		if(!*p++){
			if(!stocurlin)
				error(50);
			if( (lp = lp->next) == 0)
				error(50);      /* no wend */
			point =lp->lin;
			elsecount=0;
			flag=0;
		}
		else
			point = p;
	}
	/* we have found it at this point - end of loop */
	if(rcount || (lp!=stocurlin && flag) )
		error(51);      /* bad nesting or wend after an if */
	return(lp);             /* not on same line */
}

/*
 * the renumber routine. It is a three pass algorithm.
 *      1) Find all line numbers that are in text.
 *         Save in table.
 *      2) Renumber all lines.
 *         Fill in table with lines that are found
 *      3) Find all line numbers and update to new values.
 *
 *      This routine eats stack space and also some code space
 *      If you don't want it don't define RENUMB.
 *      Could run out of stack if on V7 PDP-11's
 *      ( On vax's it does not matter. Also can increase MAXRLINES.)
 *      MAXRLINES can be reduced if not got split i-d. If this is
 *      the case then probarbly do not want this code anyway.
 */

struct  ta {
	lnumb	linn;
	lnumb	toli;
};

int
renumb()
{
	struct  ta      *ta, *eta;
	struct ta *tp;
	CHAR   *q;
	lpoint p;
	lpoint np;
	int	c;
	lnumb	l1,start,inc;
	int     size,pl;
	CHAR    onfl,chg,*r,*s;
	long    numb;
	int	err = 0;

	start = 100;
	inc = 10;
	l1 = getlin();
	if(l1 != NOLNUMB){              /* get start line number */
		if(l1 == 0)
			error(5);
		start = l1;
		if(getch() != ',')
			point--;
		else {
			l1 = getlin();          /* get increment */
			if(l1 == NOLNUMB || l1 == 0)
				error(5);
			inc = l1;
		}
	}
	check();                /* check rest of line */
	/*
	 * find out number of lines there are and allocate an array for them
	 */
	for(numb = 0, p=program; p ;p= p->next)
		if(p->linnumb != CONTLNUMB)
			numb++;
	/*
	 * nothing to do give up.
	 */
	if(!numb)
		reset();
	/*
	 * also check to see if we are going to overflow linenumbers
	 */
	if( (numb * inc) + start > 65530L)
		error(7);
	ta = (struct ta *)mmalloc((ival)(numb * sizeof(struct ta)));
	renstr = (MEMP)ta;

	/*
	 * now set up the renumbered line numbers
	 */
	l1 = start;           /* reset counter */
	for(tp = ta, p = program ; p ; p = p->next){
		if(p->linnumb == CONTLNUMB)
			continue;
		tp->linn = p->linnumb;
		tp->toli = l1;
		l1 += inc;
		tp++;
	}

	eta = tp;
	for(p=program; p ;p= p->next){
		onfl = 0;               /* flag to deal with on_goto */
		for(q = p->lin; *q ; q++){      /* now find keywords */
			if( ((c = UC(*q)) & SPECIAL) == 0)
				continue;
			if(c >= EXFUNC){
				q++;
				continue;
			}
			if(c == ON){            /* the on keyword */
				onfl++;                 /* set flag */
				continue;
			}               /* check items with optional numbers*/
			if(c == ELSE || c == THEN || c == RESUME || c == RESTORE
								|| c == RUNN ){
				q++;
				while(*q++ == ' ');
				q--;
				if(isdigit(*q))	/* got one ok */
					goto ok1;
			}
			if(c != GOTO && c != GOSUB)
				continue;	/* can't be anything else */
			q++;
		ok1:				/* have a label */
			do{
				while(*q++ == ' ');
				q--;		/* look for number */
				if(!isdigit(*q)){
					prsline("Line number required on line ",
									p);
					prints((char *)nl);	/* missing */
					err = 1;
					goto out1;
				}
				for(l1 = 0; isdigit(*q) ; q++) /* get it */
					if(l1 >= 6553)
						error(7);
					else l1 = l1 * 10 + *q - '0';
				if(l1 == 0){
					onfl = 0;
					break;
				}
				for(tp  = ta ; tp < eta ; tp++) /* already */
					if(tp->linn == l1)      /* got it ? */
						break;
				if(tp >= eta ){        /* undefined line */
					prints("undefined line: ");
					printd(l1);
					prsline(" on line ", p);
					prints((char *)nl);  /* can't find it */
					err = 1;
					goto out1;
				}
				if(!onfl)               /* check flag */
					break;          /* get next item */
				while(*q++== ' ');      /* if ON and comma */
			}while( *(q-1) ==',');
			if(onfl)
				q--;
			onfl = 0;
			q--;
		}
	out1:   ;
	}
	/*
	 * if had an error don't do the renumbering
	 */
	if(err){
		mfree( (memp)renstr);
		renstr = 0;
		reset();
	}
	/*
	 * renumber the lines
	 */
	l1 = start;           /* reset counter */
	for(p= program ; p ;p= p->next){
		if(p->linnumb == CONTLNUMB)
			continue;
		p->linnumb = l1;
		l1 += inc;
	}
	for(np = 0, p= program ; p ;np = p, p= p->next ){
		onfl = 0;
		chg = 0;                        /* set if line changed */
		for(r = nline, q = p->lin ; *q ; *r++ = *q++){
			if(r >= &nline[MAXLIN])  /* overflow of line */
				break;
			if( ((c = UC(*q)) & SPECIAL) == 0)
				continue;
			if(c >= EXFUNC){
				*r++ = *q++;
				continue;
			}

			if(c == ON){
				onfl++;
				continue;
			}
			if(c == ELSE || c == THEN || c == RESUME || c == RESTORE
								|| c == RUNN ){
				*r++ = *q++;
				while(*q == ' ' && r < &nline[MAXLIN] )
					*r++ = *q++;
				if(isdigit(*q)) /* got optional line number*/
					goto ok2;
			}
			if(c != GOTO && c != GOSUB)
				continue;
			*r++ = *q++;
			for(;;){
				while(*q == ' ' && r < &nline[MAXLIN] )
					*r++ = *q++;
			ok2: ;
				if(r>= &nline[MAXLIN] )
					break;
				for(l1 = 0 ; isdigit(*q) ; q++) /* get numb*/
					l1 = l1 * 10 + *q - '0';

				if(l1 == 0)         /* skip if not found */
					goto out;

				for(tp = ta ; tp->linn != l1 ; tp++);

				if(tp->linn != tp->toli)
					chg++;       /* number has changed */
							/* get new number */
				s = (CHAR *)printlin(tp->toli);
				while( *s && r < &nline[MAXLIN])
					*r++ = *s++;
				if(r >= &nline[MAXLIN] )
					break;
				if(!onfl)	/* repeat if ON statement */
					break;
				while(*q == ' ' && r < &nline[MAXLIN])
					*r++ = *q++;
				if(*q != ','){
					onfl = 0;
					break;
				}
				*r++ = *q++;
			}
			onfl = 0;
			if(r >= &nline[MAXLIN])	/* line length overflow */
				error(32);
		}
		if(!chg)                /* not changed so don't put back */
			continue;
		inserted =1;            /* say we have changed it */
		*r = 0;
		size = (r - nline) + sizeof(struct olin); /* get size */
/*
		size = (size + 03) & ~03;
*/
		pl = p->linnumb;        /* save line number */
		p = (lpoint)mmalloc( (ival)size);
		p->linnumb = pl;        /* restore line number*/
		if(!np){		/* first line */
			p->next = program->next;
			mfree( (MEMP)program);
			program = p;
		}
		else {
			p->next = np->next->next;
			mfree( (MEMP) np->next);
			np->next = p;
		}
		VOID str_cpy(nline,p->lin);   /* copy back new line */
	out:    ;
	}
	mfree( (MEMP)renstr);
	renstr = 0;
	reset();
	normret;
}
