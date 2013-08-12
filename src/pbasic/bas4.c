/*
 * BASIC by Phil Cockcroft
 */
#include        "bas.h"

/*
 *      Stringeval() will evaluate a string expression of any
 *    form. '+' is used as the concatenation operator
 *
 *      gblock and gcursiz are used as global variables by the
 *    string routines. Gblock contains the resultant string while
 *    gcursiz holds the length of the resultant string ( even if not
 *    put in gblock ).
 *      For routines that need more than one result e.g. mid$ instr$
 *    then one result at least is put on the stack while the other
 *    ( possibly ) is put in gblock.
 */

/*
 *      The parameter to stringeval() is a pointer to where the
 *    result will be put.
 */

#ifdef	__STDC__
static	STR	midst(void);
static	STR	hocvtstr(int);
#else
static	STR	midst();
static	STR	hocvtstr();
#endif

static	STR	str_free;
static	int	nstr_free;

/*
 * maximum number of strings that should be left in the free
 * list
 */
#define	MAX_FREE_STRS	100

STR
stringeval()
{
	STR	st;
	STR	fstr = NULL;
	int     c;
	stringp l;
	CHAR    charac;

	st = ALLOC_STR( (ival)0);

for(;;){
	c=getch();
	if(c & SPECIAL){             /* a string function */
		if(c == SFUNCN)
			fstr = (*strngncommand[*point++ & 0177])();
		else if(c == SFUNCA){
			c = (int)*point++ & 0177;
			if(*point++!='(')
				error(SYNTAX);
			fstr = (*strngcommand[c])();
			if(getch()!=')')
				error(SYNTAX);
		}
		else if(c == MIDSTR){
			if(*point++!='(')
				error(SYNTAX);
			fstr = midst();
			if(getch()!=')')
				error(SYNTAX);
		}
		else if(c == FN){
			fstr = ALLOC_STR( (ival)0);
			ffn( (struct entry *)0, fstr);
		}
		else
			error(11);
	}
	else if(c=='"' || c=='`'){      /* a quoted string */
		fstr = ALLOC_STR( (ival)0);
		fstr->strval = point;
		fstr->strlen = 0;
		charac= (CHAR)c;
		while(*point && *point!= charac){
			fstr->strlen++;
			point++;
		}
		if(*point)
			point++;
	}
	else if(isletter(c)){           /* a string variable */
#if 0
		CHAR *sp = --point;

		l= (stringp)getname(ISFUNC);
		if(l == 0){
			fstr = ALLOC_STR( (ival)0);
			point = sp;
			ffn( (struct entry *)0, fstr);
		}
		else {
#else
			--point;
			l= (stringp)getname(0);
#endif
			if(vartype!= SVAL)
				error(SYNTAX);
			fstr = ALLOC_STR( (ival)0);
			fstr->strval = l->str;
			fstr->strlen = l->len;
#if 0
		}
#endif
	}
	else
		error(SYNTAX);
   /* all routines return to here with the string pointed to by p */
	if((c = getch()) == '['){
		ival	l1, l2;

		l1 = evalint();
		if(l1 < 1 || l1 > MAX_STR)
			error(9);
		l1--;
		if( (c = getch()) == ','){
			l2 = evalint();
			if(l2 < 0 || l2 > MAX_STR)
				error(9);
			c = getch();
		}
		else
			l2 = MAX_STR;
		if(c != ']')
			error(SYNTAX);
		if(l1 > fstr->strlen)
			l1 = fstr->strlen;
		if(l2 > fstr->strlen - l1)
			l2 = fstr->strlen - l1;
		fstr->strval += l1;
		fstr->strlen = l2;
		c = getch();
	}

	if(fstr->strlen + st->strlen > MAX_STR)
		error(9);
	if(st->strlen == 0)
		COPY_OVER_STR(st, fstr);
	else if(fstr->strlen != 0){
		RESERVE_SPACE(st, (ival) (fstr->strlen + st->strlen));
		VOID strmov(st->strval+st->strlen, fstr->strval, fstr->strlen);
		st->strlen += fstr->strlen;
	}
	FREE_STR(fstr);
	if(c != '+'){
		point--;
		if(c != '"' && c != '`' && !isletter(c))
			break;
	}
	}
	/*
	 * check to see if strval is in the allocated buffer
	 * If it is not, then put it in
	 */
	RESERVE_SPACE(st, (ival)st->strlen);
	return(st);
}

/*
 *      stringassign() will put the sting in gblock into the string
 *    pointed to by p.
 *      It will call the garbage collection routine as neccasary.
 */

void
stringassign(p, ep, st, nodel)
stringp p;
struct	entry	*ep;
STR	st;
int	nodel;
{
	if(p->str){
		if(ep->flags & IS_FSTRING)
			error(3);	/* illegal string function */
		mfree( (MEMP)p->str);
		p->str = 0;
	}
	if((p->len = st->strlen) != 0){
		if(st->allocstr == st->locbuf){
			p->str = (CHAR *)mmalloc(st->strlen);
			VOID strmov(p->str, st->allocstr, st->strlen);
		}
		else
			p->str = st->allocstr;
		st->allocstr = 0;
	}
	if(!nodel)
		FREE_STR(st);
}

/*
 *      The following routines implement string functions they are all quite
 *    straight forward in operation.
 */

STR
datef()
{
	STR	st;
	int	c, i, n;
	CHAR	*p, *q;
	struct	tm	*tmp;
	int	tf;
	static	int	mplies[] = { 0, 1, 10, 100, 1000, 10000 };
#ifndef	__STDC__
	char    *ctime();
	long	m;
	struct	tm	*localtime();
#else
	time_t	m;
#endif

	VOID time(&m);

	c = getch();
	if(c == '('){
		st = stringeval();
		if(getch() != ')')
			error(SYNTAX);
		tmp = localtime(&m);
		for(p = st->strval, i = st->strlen ; i ;){
			c = lcase(*p);
			for(q = p, n = 0 ; lcase(*q) == c && n < i; q++)
				n++;
			i -= n;
			switch(c){
			case 's':
				tf = tmp->tm_sec;
				break;
			case 'h':
				tf = tmp->tm_hour;
				break;
			case 'd':
				tf = tmp->tm_mday;
				break;
			case 'm':
				if(c == UC(*p))
					tf = tmp->tm_min;
				else
					tf = tmp->tm_mon + 1;
				break;
			case 'y':
				tf = tmp->tm_year;
				if(n >= 4)
					tf += 1900;
				break;
			default:
				p += n;
				continue;
			}
			/*
			 * n is never 0
			 */
			if(n > 4){
				set_mem(p, n - 4, '0');
				p += n-4;
				n = 4;
			}
			tf %= mplies[n + 1];
			
			while(n >= 0){
				*p++ = '0' + (tf / mplies[n]);
				tf %= mplies[n];
				n--;
			}
		}
	}
	else {
		point--;
		st = ALLOC_STR( (ival)24);
		VOID strmov(st->strval, (CHAR *)ctime(&m), st->strlen);
	}
	return(st);
}

STR
strng()
{
	CHAR	*p;
	itype	m;
	ival	cursiz=0;
	int	siz;
	STR	st;

	st = stringeval();

	if(getch()!=',')
		error(SYNTAX);
	m=evalint();
	if(m> MAX_STR || m < 0)
		error(10);
	if(!st->strlen || m <= 1){
		if(!m)
			st->strlen = 0;
		return(st);
	}

	siz=(int)m;
	cursiz = siz * st->strlen;
	if((unsigned)cursiz > MAX_STR)
		error(9);
	RESERVE_SPACE(st, cursiz);

	for(p = st->strval + st->strlen, siz-- ; siz ; siz--)
		p = strmov(p, st->strval, st->strlen);
	st->strlen = cursiz;
	return(st);
}

/*      left$ string function */

STR
leftst()
{
	itype    l1;
	STR	st;

	st = stringeval();
	if(getch()!=',')
		error(SYNTAX);
	l1=evalint();
	if(l1<0 || l1 > MAX_STR)
		error(10);
	if(l1 < st->strlen)
		st->strlen = l1;
	return(st);
}

/*      right$ string function */

STR
rightst()
{
	itype	l1;
	STR	st;

	st = stringeval();
	if(getch()!=',')
		error(SYNTAX);

	l1=evalint();

	if(l1<0 || l1 > MAX_STR)
		error(10);

	if(l1 < st->strlen){
		st->strval += st->strlen - l1;
		st->strlen = l1;
	}
	return(st);
}

/*
 *      midst$ string function:-
 *              can have two or three parameters , if third
 *              parameter is missing then a value of cursiz
 *              is used.
 */

static	STR
midst()
{
	STR	st;
	itype   l1,l2;

	st = stringeval();

	if(getch() != ',')
		error(SYNTAX);

	l1 = evalint() - 1;
	if(getch() != ','){
		point--;
		l2 = MAX_STR;
	}
	else
		l2 = evalint();
	if(l1 < 0 || l2 < 0 || l1 > MAX_STR || l2 > MAX_STR)
		error(10);
	l2 += l1;
	if(l2 > st->strlen)
		l2 = st->strlen;
	if(l1 > st->strlen)
		l1 = st->strlen;
	st->strval += l1;
	st->strlen = l2 - l1;
	return(st);
}

/*      ermsg$ string routine , returns the specified error message */

STR
estrng()
{
	STR	st;
	CHAR   *q;
	itype  l;
	ival	mlen;

	l = evalint();
	if(l < 1 || l > MAXERR)
		error(22);
	q = (CHAR *)ermesg[l-1];
	mlen = slen(q);
	st = ALLOC_STR( (ival)mlen);
	st->strval = q;
	return(st);
}

/*      chr$ string function , returns character from the ascii value */

STR
chrstr()
{
	STR	st;
	itype	i;

	i = evalint();
	if(i < 0 || i > 255)
		error(FUNCT);
	st = ALLOC_STR( (ival)1);
	*st->strval = (CHAR)i;
	return(st);
}

/*      str$ string routine , returns a string representation
 *      of the number given. There is NO leading space on positive
 *      numbers.
 */

STR
nstrng()
{
	STR	st;

	eval();
	st = mgcvt();
	if(*st->strval == ' '){
		st->strval++;
		st->strlen--;
	}
	return(st);
}

/*      val() maths function , returns the value of a string. If
 *    no numeric value is used then a value of zero is returned.
 */

void
val()
{
	CHAR   *p;
	int	minus=0;
	STR	st;
	int	ret;

	st = stringeval();
	NULL_TERMINATE(st);
	p = st->strval;
	while(*p == ' ')
		p++;
	if(*p == '-'){
		p++;
		minus++;
	}
	if(!ispnumber(p) && *p != '.' && *p != '&'){
		FREE_STR(st);
		if(minus)
			error(36);
		res.i=0;
		vartype= IVAL;
		return;
	}
	ret = getnumb(p, (CHAR **)0);

	FREE_STR(st);

	if(!ret)
		error(36);
	if(minus)
		negate();
}

void
binval()
{
	itype	iv = 0;
	int	minus = 0;
	int	max_digits = sizeof(itype) * 8;
	CHAR	*p;
	STR	st;

	st = stringeval();
	NULL_TERMINATE(st);
	for(p = st->strval ; *p == ' ' ; p++);
	if(*p == '-'){
		minus++;
		p++;
	}
	while(*p){
		if(*p != '0' && *p != '1')
			error(36);
		iv <<= 1;
		iv += *p++ - '0';
		if(!max_digits--)
			error(36);
	}
	FREE_STR(st);
	if(minus)
		iv = -iv;
	res.i = iv;
	vartype = IVAL;
}
	
/*      instr() maths function , returns the index of the first string
 *    in the second. Starting either from the first character or from
 *    the optional third parameter position.
 */

void
brinstr(rflag)
int rflag;
{
	CHAR   *p,*q,*r;
	itype   i=0;
	STR	st1, st2;
	ival	cursiz;
	itype	pos = -1;

	st1 = stringeval();
	if(getch()!=',')
		error(SYNTAX);
	st2 = stringeval();

	if(getch()==','){
		i=evalint()-1;
		if(i<0 || i>= MAX_STR)
			error(10);
	}
	else
		point--;
	cursiz = st1->strlen - st2->strlen;
	vartype= IVAL;
	for(r = st1->strval + st2->strlen + i; i <= cursiz ; i++, r++){
		p = st2->strval;
		q = st1->strval + i;
		while(q < r && *p == *q)
			p++,q++;
		if( q == r ){
			pos = i;
			if(!rflag)
				break;
		}
	}
	/*
	 * should be '&& pos != -1' but pos is -1 when it fails so it works
	 */
	res.i = pos + 1;
	FREE_STR(st2);
	FREE_STR(st1);
}

void
instr()
{
	brinstr(0);
}

void
rinstr()
{
	brinstr(1);
}

/*      space$ string function returns a string of spaces the number
 *    of which is the argument to the function
 */

STR
space()
{
	itype  i;
	STR	st;

	i = evalint();
	if(i < 0 || i > MAX_STR)
		error(10);
	st = ALLOC_STR( (ival)i);
	if(i != 0)
		set_mem(st->strval, i, ' ');
	return(st);
}

/*      mid$() when on the left of an assignment */
/* can have optional third argument */

/*      a$ = "this is me"
 * mid$(a$,2) = "hello"         ->   a$ = "thello"
 * mid$(a$,2,5) = "hello"       ->   a$ = "thellos me"
 */

int
lhmidst()
{
	CHAR	*p;
	itype   i1,i2;
	ival	cursiz,rhside;
	stringp	pat;
	struct	entry	*ep;
	STR	st, nst;
	ival	totlen;

	if(*point++ !='(')
		error(SYNTAX);
	pat= (stringp)getname(0);
	if(vartype!= SVAL)
		error(VARREQD);
	ep = curentry;
	if(getch()!=',')
		error(SYNTAX);
	i1=evalint()-1;
	if(getch()!=','){
		i2= MAX_STR;
		point--;
	}
	else
		i2= evalint();
	if(i2<0 || i2> MAX_STR || i1<0 || i1>= MAX_STR)
		error(10);
	if(getch()!=')' )
		error(SYNTAX);
	if(getch()!='=')
		error(4);
	cursiz = pat->len;
	if(i1>cursiz)
		i1=cursiz;
	i2+=i1;
	if(i2>cursiz)
		i2=cursiz;
	rhside= cursiz -i2;
	st = stringeval();
	check();
	totlen = st->strlen + rhside + i1;
	if(totlen > MAX_STR)
		error(9);
	if(i1){
		nst = ALLOC_STR( (ival)totlen);
		p = strmov(nst->strval, pat->str, i1);
		p = strmov(p, st->strval, st->strlen);
		if(rhside)
			VOID strmov(p, pat->str + i2, rhside);
		COPY_OVER_STR(st, nst);
		FREE_STR(nst);
	}
	else {
		RESERVE_SPACE(st, totlen);
		if(rhside)
			VOID strmov(st->strval, pat->str + i2, rhside);
	}

	st->strlen = totlen;
	stringassign(pat, ep, st, 0);    /* done it !! */
	normret;
}

/*
 * translitterate a character from a$ to result using b$
 * y$ = xlate(a$, b$
 */
STR
xlate()
{
	ival	cursiz1;
	ival	cursiz2;
	CHAR   *p, *q;
	ival	c;
	STR	st1, st2;

	st1 = stringeval();
	if(getch()!=',')
		error(SYNTAX);
	st2 = stringeval();
	cursiz1 = st1->strlen;
	cursiz2 = st2->strlen;
	for(p = st1->strval, q = st2->strval ; cursiz1 ; cursiz1--, p++){
		if( (c = (ival)UC(*p)) >= cursiz2)
			*p = 0;
		else
			*p = q[c];
	}
	FREE_STR(st2);
	return(st1);
}

/* mkint(a$)
 * routine to make the first 2 bytes of string into a integer
 * for use with formatted files.
 */

void
mkint()
{
	STR	st;

	st = stringeval();
	if(st->strlen < sizeof(itype) )
		error(10);
	/*LINTED pointer use*/
	res.i = *(itype *)st->strval;
	vartype = IVAL;
	FREE_STR(st);
}

/* ditto for string to double */

void
mkdouble()
{
	STR	st;

	st = stringeval();
	if(st->strlen < sizeof(res) )
		error(10);
	/*LINTED pointer use*/
	res = *(value *)st->strval;
	vartype = RVAL;
	FREE_STR(st);
}

/*
 * mkistr$(x%)
 * convert an integer into a string for use with disk files
 */

STR
mkistr()
{
	itype	iv;
	STR	st;

	iv = evalint();
	st = ALLOC_STR( (ival)sizeof(itype));
	/*LINTED pointer use*/
	*(itype *)st->strval = iv;
	return(st);
}

/* mkdstr$(x)
 * ditto for doubles.
 */

STR
mkdstr()
{
	STR	st;

	evalreal();
	st = ALLOC_STR( (ival)sizeof(res));
	/*LINTED pointer use*/
	*(value *)st->strval = res;
	return(st);
}

static	const	CHAR	hexchar[] = "0123456789ABCDEF";

static	STR
hocvtstr(shift)
int	shift;
{
	STR	st;
	CHAR	*p;
	int	nchars;
	unsigned long	lv;
	ival	nsig;
	int	mask;

	nchars = (sizeof(itype) * 8 + shift - 1) / shift;
	mask = (1 << shift) - 1;

	lv = (unsigned long)evalint();

	if(getch() == ','){
		nsig = evalint();
		if(nsig <= 0){
			if(nsig == 0)
				nsig = 1;
			else
				error(FUNCT);
		}
	}
	else {
		nsig = 1;
		point--;
	}
	st = ALLOC_STR( (ival)nchars);
	for(p = st->strval + nchars - 1; nchars ; nchars--, p--){
		*p = hexchar[lv & mask];
		lv >>= shift;
	}
	for(; st->strlen > nsig; st->strlen--, st->strval++)
		if(*st->strval != '0')
			break;
	return(st);
}

STR
hexstr()
{
	return(hocvtstr(4));
}

STR
octstr()
{
	return(hocvtstr(3));
}

STR
binstr()
{
	return(hocvtstr(1));
}

STR
decstr()
{
	STR	st, retst;
	value	x;

	evalreal();
	if(getch() != ',')
		error(SYNTAX);
	x = res;
	st = stringeval();
	res = x;
	vartype = RVAL;
	retst = mathpat(st);
	COPY_OVER_STR(st, retst);
	FREE_STR(retst);
	return(st);
}

STR
bupper()
{
	STR	st;
	itype	i;
	CHAR	*p;
	int	c;

	st = stringeval();
	for(i = st->strlen , p = st->strval ; i ; i--, p++){
		c = UC(*p);
		if(islcase(c))
			*p = c - 'a' + 'A';
	}
	return(st);
}

STR
blower()
{
	STR	st;
	itype	i;
	CHAR	*p;
	int	c;

	st = stringeval();
	for(i = st->strlen , p = st->strval ; i ; i--, p++){
		c = UC(*p);
		if(isucase(c))
			*p = c - 'A' + 'a';
	}
	return(st);
}

void
COPY_OVER_STR(st, fstr)
STR	st, fstr;
{
	if(st->allocstr && st->allocstr != st->locbuf)
		mfree((MEMP)st->allocstr);

	if(fstr->allocstr == fstr->locbuf){
		st->allocstr = st->locbuf;
		VOID strmov(st->allocstr, fstr->allocstr, fstr->alloclen);
	}
	else
		st->allocstr = fstr->allocstr;
	fstr->allocstr = 0;
	st->alloclen = fstr->alloclen;
	st->strval = fstr->strval;
	st->strlen = fstr->strlen;
}

void
FREE_STR(st)
STR	st;
{
	STR	nst;

	if(st->allocstr != 0 && st->allocstr != st->locbuf)
		mfree((MEMP)st->allocstr);
	st->allocstr = 0;
	/*
	 * now take off the used queue
	 */
	if(st->prev){
		st->prev->next = 0;
		str_uend = st->prev;
	}
	else
		str_uend = str_used = 0;

	nst = st->next;
	/*
	 * and add to the free list
	 */
	st->next = str_free;
	str_free = st;
	nstr_free++;

	while( (st = nst) != 0){
		/* the cleanup case */
		if(st->allocstr != 0 && st->allocstr != st->locbuf)
			mfree((MEMP)st->allocstr);
		st->allocstr = 0;
		nst = st->next;
		st->next = str_free;
		str_free = st;
		nstr_free++;
	}
	while(nstr_free > MAX_FREE_STRS){
		st = str_free;
		str_free = st->next;
		mfree( (MEMP) st);
		nstr_free--;
	}
}

void
NULL_TERMINATE(st)
STR	st;
{
	if(st->strlen >= st->alloclen)
		RESERVE_SPACE(st, (ival)(st->strlen+1));
	st->strval[st->strlen] = 0;
}

/*
 * slop that might be needed, for adding a null byte etc.
 * to the string... Stops sillies like reallocating a string to add a
 * null byte on the end
 */
#define STR_SLOP	2

/*
 * allways aallocate space in quantities of this
 */
#define	STR_ALIGNED	64

#define	STR_ALIGN(x) ((((x) + STR_SLOP) + STR_ALIGNED-1) & ~(STR_ALIGNED-1))

void
RESERVE_SPACE(st, len)
STR	st;
ival	len;
{
	CHAR	*p;
	CHAR	*tofree = 0;

	if(len == 0){
		st->strval = st->allocstr;
		return;
	}
	if(st->allocstr != 0){
		if(st->alloclen < len){
			len = STR_ALIGN(len);
			p = (CHAR *)mmalloc(len);
			if(st->allocstr != st->locbuf)
				tofree = st->allocstr;
			st->allocstr = p;
			st->alloclen = len;
		}
	}
	else {
		if(len <= LOC_BUF_SIZ){
			st->allocstr = st->locbuf;
			st->alloclen = LOC_BUF_SIZ;
		}
		else {
			len = STR_ALIGN(len);
			st->allocstr = (CHAR *)mmalloc(len);
			st->alloclen = len;
		}
	}

	if(st->strlen && st->strval != st->allocstr)
		VOID strmov(st->allocstr, st->strval, st->strlen);

	if(tofree)
		mfree((MEMP)tofree);
	st->strval = st->allocstr;
}

void
DROP_STRINGS()
{
	STR	st;

	while( (st = str_free) != 0){
		str_free = st->next;
		mfree( (MEMP)st);
	}
	nstr_free = 0;
}

STR
ALLOC_STR(len)
ival	len;
{
	/* Take a str element off the free list */
	STR	st;
	int	i;

	if( (st = str_free) == 0){
		for(i = 10 ; i ; i--){
			st = (STR)mmalloc(sizeof(* st));
			clr_mem( (memp)st, sizeof(* st) - LOC_BUF_SIZ);
			st->next = str_free;
			str_free = st;
			nstr_free++;
		}
		st = str_free;
	}
	str_free = st->next;
	nstr_free--;

	/*
	 * now add to the used list
	 */
	st->next = 0;
	if((st->prev = str_uend) == 0)
		str_used = st;
	else
		st->prev->next = st;
	str_uend = st;

	/*
	 * now allocate any space needed for it
	 */
	st->strlen = len;
	if(len == 0){
		st->allocstr = 0;
		st->alloclen = 0;
	}
	else if(len <= LOC_BUF_SIZ){
		st->alloclen = LOC_BUF_SIZ;
		st->allocstr = st->locbuf;
	}
	else {
		st->alloclen = STR_ALIGN(len);
		st->allocstr = (CHAR *)mmalloc(st->alloclen);
	}
	st->strval = st->allocstr;
	return(st);
}
