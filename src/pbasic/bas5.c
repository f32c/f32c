/*
 * BASIC by Phil Cockcroft
 */
#include        "bas.h"

/*
 *      This file contains the routines for input and read since they
 *    do almost the same they can use a lot of common code.
 */

/*
 *      input can have a text string, which it outputs as a prompt
 *    instead of the usual '?'. If input is from a file this
 *    facility is not permitted ( what use anyway ? ).
 *
 *      added 28-oct-81
 */

static	int	getstrdt( int (*)(void), STR),getdata( int (*)(void) );
static	int	in1file(void), in1line(void);
static	int	readd1(void);
static	void	getmore(void);

static	int	pushback = -1;

static	filebufp _curinfile;

static	int
in1file(void)
{
	int	c;

	if(pushback >= 0){
		c = pushback;
		pushback = -1;
		return(c);
	}
	switch(c = fin1ch(_curinfile)){
	case '\n':
		return(0);
	case '\0':
		return(0400);
	}
	return(c);
}

static	CHAR	*in1iline;

static	int
in1line(void)
{
	int	c;

	if(pushback >= 0){
		c = pushback;
		pushback = -1;
		return(c);
	}
	return(UC(*in1iline++));
}

int
input()
{
	CHAR   *p;
	ival   i = 0;
	value	*l;
	int     c;
	char    vty;
	int	(*infunc)(void);
	int     firsttime=0;
	int	noerr;
	int	frfile = 0;
	STR	st = NULL;

	infunc = in1line;
	c=getch();
	if(c=='"'){
		p=line;
		while(*point && *point != '"'){
			*p++ = *point++;
			i++;
		}
		if(*point)
			point++;
		if(getch()!=';')
			error(SYNTAX);
		*p=0;
		firsttime++;
	}
	else if(c=='#'){
		i=evalint();
		if(getch()!=',')
			error(SYNTAX);
		_curinfile = getf(i, _READ);
		infunc = in1file;
		frfile = 1;
	}
	else
		point--;
	l= (value *)getname(0);
	vty=vartype;
for(;;){
	if(!frfile){
		if(!firsttime){
			*line='?';
			i=1;
		}
		firsttime=0;
		VOID edit(i,i,(ival)0);
		if(trapped){
			point=savepoint; /* restore point to start of in. */
			return(-1);     /* will trap at start of this in. */
		}
		in1iline = line + i;
	}
	do {
		/* ignore leading spaces */
		while( (c = (*infunc)()) == ' ');
		if(!c && vty != SVAL)
			continue;
		pushback = c;
		if(vty == SVAL){
			st = ALLOC_STR( (ival)LOC_BUF_SIZ);
			noerr = getstrdt(infunc, st);
		}
		else
			noerr = getdata(infunc);
		if(noerr)
			while( (c = (*infunc)()) == ' ');
		if(!noerr || (c && c != ',')){
			if(vty == SVAL && st != NULL)
				FREE_STR(st);
			if(frfile)
				error(26);
			prints("Bad data redo\n");
			break;
		}
		if(vty == SVAL)
			stringassign( (stringp)l, curentry, st, 0);
		else
			putin(l, (int)vty);

		if(getch()!=','){
			point--;
			normret;
		}

		l= (value *)getname(0);
		vty=vartype;
	} while(c);
	}
}

/* valid types for string input :-
 * open quote followed by any character until another quote or the end of line
 * no quote followed by a sequence of characters except a quote
 * terminated by a comma (or end of line).
 */

/*      the next two routines return zero on error and a pointer to
 *    rest of string on success.
 */

/*      read string data routine */

static	int
getstrdt(infunc, st)
int	(*infunc)(void);
STR	st;
{
	CHAR *q;
	int	c;
	int	charac;
	ival	curlen;

	q = st->strval;
	curlen = st->strlen;
	st->strlen = 0;
	if( (c = (*infunc)()) == '"' || c == '`'){
		charac = c;
		while( (c = (*infunc)()) != charac && c){
			*q++ = (CHAR)c;
			if(++st->strlen > MAX_STR)
				return(0);
			if(st->strlen >= curlen){
				RESERVE_SPACE(st, (ival)(curlen + 32));
				q = st->strval + curlen;
				curlen += 32;
			}
		}
		if(c == charac)
			c = (*infunc)();
	}
	else if(c){
		*q++ = (CHAR)c;
		st->strlen++;
		while( (c = (*infunc)()) != 0 && c != ',' &&
							c != '"' && c != '`'){
			*q++ = (CHAR)c;
			if(++st->strlen > MAX_STR)
				return(0);
			if(st->strlen >= curlen){
				RESERVE_SPACE(st, (ival)(curlen + 32));
				q = st->strval + curlen;
				curlen += 32;
			}
		}
	}
	pushback = c;
	return(1);
}

/*      read number routine */

static	int
getdata(infunc)
int	(*infunc)(void);
{
	CHAR	tbuf[MAXLIN];
	CHAR	*p;
	int	c;
	int     minus=0;
	int	decp = 0;

	p = tbuf;
	if( (c = (*infunc)()) == '-'){
		minus++;
		c = (*infunc)();
	}
	if(!isnumber(c) && c !='.'){
		if(c != '&')
			return(0);
		do {
			*p++ = (CHAR)c;
			c = (*infunc)();
		}while(ishex(c));
		goto done;
	}
	do {
		if(c == '.')
			if(decp++)
				return(0);
		*p++ = (CHAR)c;
		c = (*infunc)();
	} while(isnumber(c) || c == '.');
	if(c == 'e' || c == 'E'){
		*p++ = (CHAR)c;
		if( (c = (*infunc)()) == '+' || c == '-'){
			*p++ = (CHAR)c;
			c = (*infunc)();
		}
		if(!isnumber(c))
			return(0);
		do {
			*p++ = (CHAR)c;
			c = (*infunc)();
		} while(isnumber(c));
	}
	if(c == D_INT || c == D_FLT){
		*p++ = (CHAR)c;
		c  = (*infunc)();
	}
done:;
	*p = 0;
	if(!getnumb(tbuf, (CHAR **)0))
		return(0);
	pushback = c;
	if(minus)
		negate();
	return(1);
}

/* input a whole line of text (into a string ) */

int
linput()
{

	CHAR   *p;
	ival	i;
	int     c;
	CHAR	*q;
	stringp	l;
	STR	st;
	ival	curlen = LOC_BUF_SIZ;

	c=getch();
	if(c=='#'){
		i=evalint();
		if(getch()!=',')
			error(SYNTAX);
		_curinfile = getf(i, _READ);
		l = (stringp)getname(0);
		if(vartype != SVAL)
			error(VARREQD);
		check();
		st = ALLOC_STR(curlen);
		for(i = 0, p = st->strval; (c = in1file()) != 0;){
			*p++ = (CHAR)c;
			if(++i > MAX_STR)
				error(9);
			if(i >= curlen){
				st->strlen = i;	/* force reallocation */
				RESERVE_SPACE(st, (ival)(curlen + 32));
				p = st->strval + curlen;
				curlen += 32;
			}
		}
		st->strlen = i;
	}
	else {
		if(c=='"'){
			i=0;
			p=line;
			while(*point && *point != '"'){
				*p++ = *point++;
				i++;
			}
			if(*point)
				point++;
			if(getch()!=';')
				error(SYNTAX);
			*p=0;
		}
		else {
			point--;
			*line='?';
			i=1;
		}
		l = (stringp)getname(0);
		if(vartype!= SVAL)
			error(VARREQD);
		check();
		VOID edit(i,i,i);
		if(trapped){
			point=savepoint; /* restore point to start of in. */
			return(-1);     /* will trap at start of this in. */
		}
		p = q = line + i;
		while(*p)
			p++;
		i = p - q;
		st = ALLOC_STR(i);
		if(i)
			VOID strmov(st->strval, q, i);
	}
	stringassign(l, curentry, st, 0);
	normret;
}

/* read added 3-12-81 */

/*
 * Read routine this should :-
 *      get variable then search for data then assign it
 *      repeating until end of command
 *              ( The easy bit. )
 */

/*
 * Getting data :-
 *      if the data pointer points to anywhere then it points to a line
 *      to a point where getch would get an end of line or the next data item
 *      at the end of a line a null string must be implemented as
 *      a pair of quotes i.e. "" , on inputing data '"'`s are significant
 *      this is no problem normally .
 *      If the read routine finds an end of line then there is bad data
 *
 */

static	int
readd1()
{
	int	c;

	if(pushback >= 0){
		c = pushback;
		pushback = -1;
		return(c);
	}
	if(!datapoint)
		getmore();
	if(!*datapoint){
		datapoint = 0;
		return(0);
	}
	c = UC(*datapoint++);
	return(c);
}

int
readd()
{
	int	c;
	value	*l;
	char   vty;
	STR	st = NULL;

	for(;;){
		l= (value *)getname(0);
		vty=vartype;
		while( (c = readd1()) == ' ');
	/* get here the next thing should be a data item or an error */
		if(!c)
			error(BADDATA);
		pushback = c;

		if(vty == SVAL){
			st = ALLOC_STR( (ival)LOC_BUF_SIZ);
			if(!getstrdt(readd1, st))
				error(BADDATA);
		}
		else if(!getdata(readd1))
			error(BADDATA);
		while( (c = readd1()) == ' ');
		if(c && c != ',')
			error(BADDATA);
		if(vty == SVAL) {
			assert(st != NULL);
			stringassign( (stringp)l, curentry, st, 0);
		} else
			putin(l, (int)vty);
		if(getch()!=',')
			break;
	}
	point--;
	normret;
}

void
matread(lp, vty, cnt)
MEMP	lp;
int	vty;
int	cnt;
{
	int	c;
	int	stp = TYP_SIZ(vty);
	value	*l = (valp)lp;

	for(; cnt; cnt--){
		while( (c = readd1()) == ' ');
	/* get here the next thing should be a data item or an error */
		if(!c)
			error(BADDATA);
		pushback = c;

		if(!getdata(readd1))
			error(BADDATA);
		while( (c = readd1()) == ' ');
		if(c && c != ',')
			error(BADDATA);
		putin(l, vty);
		l = (valp) (MEMP)(((CHAR *)l) + stp);
	}
}

int
matinput()
{
	CHAR   *p;
	ival	i = 0;
	int     c;
	struct	entry	*ep;
	valp	l;
	char	vty;
	int	(*infunc)(void);
	int     has_str=0;
	int	noerr;
	int	frfile = 0;
	int	stp;
	int	cnt;
	int	l1, l2;
	ival	c1, c2;

	infunc = in1line;
	c=getch();
	if(c=='"'){
		p=line;
		while(*point && *point != '"'){
			*p++ = *point++;
			i++;
		}
		if(*point)
			point++;
		if(getch()!=';')
			error(SYNTAX);
		*p=0;
		has_str++;
	}
	else if(c=='#'){
		i=evalint();
		if(getch()!=',')
			error(SYNTAX);
		_curinfile = getf(i, _READ);
		infunc = in1file;
		frfile = 1;
	}
	else
		point--;
	ep = getmat(0);
	vty = vartype;
	stp = TYP_SIZ(vty);
	l = (valp)(MEMP)ep->_darr;
	l1 = cnt = ep->_dims[0];
	if(ep->dimens > 1)
		cnt *= (l2 = ep->_dims[1]);
	else
		l2 = 0;
	c1 = c2 = 1;
	for(;;){
		if(!frfile){
			if(!has_str){
				p = line;
				*p++ = '(';
				if(l2){
					p = str_cpy( (CHAR *)printlin(c2), p);
					*p++ = ',';
				}
				p = str_cpy( (CHAR *)printlin(c1), p);
				*p++ = ')';
				*p++ = '?';
			
				/* 
				 * Could be (x,y)?
				 */
				i= p - line;
				if(++c1 > l1){
					c2++;
					c1 = 1;
				}
			}
			has_str=0;
			VOID edit(i,i,(ival)0);
			if(trapped){
				point=savepoint;
				return(-1);
			}
			in1iline = line + i;
		}
		do {
			/* ignore leading spaces */
			while( (c = (*infunc)()) == ' ');
			if(!c)
				break;
			pushback = c;
			noerr = getdata(infunc);
			if(noerr)
				while( (c = (*infunc)()) == ' ');
			if(!noerr || (c && c != ',')){
				if(frfile)
					error(26);
				prints("Bad data redo\n");
				break;
			}
			putin(l, vty);
			l = (valp) (MEMP)(((CHAR *)l) + stp);

			if(--cnt)
				continue;

			if(getch() != ','){
				point--;
				normret;
			}
			ep = getmat(0);
			vty = vartype;
			stp = TYP_SIZ(vty);
			l = (valp)(MEMP)ep->_darr;
			cnt = ep->_dims[0];
			if(ep->dimens > 1)
				cnt *= ep->_dims[1];
		} while(c);
	}
}

/*
 * This is only called when datapoint is at the end of the line
 * it is also called if datapoint is zero e.g. when this is the first call
 * to read.
 */

static	void
getmore()
{
	CHAR   *q;
	lpoint p;

	if(!datastolin)
		p = program;
	else
		p = datastolin->next;
	for(;p; p = p->next){
		q=p->lin;
		while(*q == ' ')
			q++;
		if(*q == (CHAR)DATA){
			do {
				q++;
			} while(*q == ' ');
			if(!*q)
				error(BADDATA);
			datapoint= q;
			datastolin=p;
			return;
		}
	}
	error(OUTOFDATA);
}

/*      the 'data' command it just checks things and sets up pointers
 *    as neccasary.
 */

int
dodata()
{
	CHAR    *p;

	if(stocurlin){
		p=stocurlin->lin;
		while(*p++ ==' ');
		if(*(p-1) != (CHAR) DATA)
			error(BADDATA);
		if(!datastolin){
			while(*p++ == ' ');
			if(!*--p)
				error(BADDATA);
			datastolin= stocurlin;
			datapoint= p;
		}
	}
	return(GTO);    /* ignore rest of line */
}

/*      the 'restore' command , will reset the data pointer to
 *     the first bit of data it finds or to the start of the program
 *     if it doesn't find any. It will start searching from a line if
 *     that line is given as an optional parameter
 */

int
restore()
{
	CHAR   *q;
	lpoint p;
	lnumb	i;

	i=getlin();
	check();
	p = getsline(i);

	datapoint=0;
	for(;p; p = p->next){
		q= p->lin;
		while(*q++ ==' ');
		if(*(q-1) == (CHAR)DATA){
			while(*q++ == ' ');
			if(!*--q)
				error(BADDATA);
			datapoint= q;
			break;
		}
	}
	datastolin= p;
	normret;
}
