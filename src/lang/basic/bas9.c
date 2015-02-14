/*
 * BASIC by Phil Cockcroft
 */
#include        "bas.h"

/*
 *      This file contains subroutines used by many commands
 */

/*      stringcompare will compare two strings and return a valid
 *    logical value
 */

static	CHAR	*necvt(double, int, int *, int *);
static	STR	lgcvt(void);
static	void	_scale(double *, int *, int *, int);
static	CHAR	*d_expand(double, int, int *);
static	int	pat_exp(CHAR *, int, int, int, int, int, int, int, int, int);

void
stringcompare()
{
	ival   i;
	CHAR   *p,*q;
	ival    cursiz;
	int     reslt=0;
	int     c;
	STR	st1, st2;

	st1 = stringeval();
	cursiz = st1->strlen;
	if( (c=getch()) == 0)
		error(SYNTAX);
	st2 = stringeval();
	if( (i = ((cursiz > st2->strlen) ? st2->strlen : cursiz)) != 0){
		/*
		 * make i the minimum of gcursiz and cursiz
		 */
		st2->strlen -= i; st1->strlen -= i;
		p = st1->strval; q = st2->strval;    /* set pointers */
		do{
			if(*p != *q){       /* do the compare */
				if( UC(*p) > UC(*q) )
					reslt++;
				else
					reslt--;
				FREE_STR(st2);
				FREE_STR(st1);
				compare(c,reslt);
				return;
			}
			p++;
			q++;
		}while(--i);
	}
	if(st1->strlen)
		reslt++;
	else if(st2->strlen)
		reslt--;
	FREE_STR(st2);
	FREE_STR(st1);
	compare(c,reslt);
}

/*      given the comparison operator 'c' then returns a value
 *    given that 'reslt' has a value of:-
 *              0:      equal
 *              1:      greater than
 *             -1:      less than
 */

void
compare(c,reslt)
int     c;
int    reslt;
{
	vartype= IVAL;
	if(c==EQL){
		if(!reslt)
			goto true;
	}
	else if(c==LTEQ){
		if( reslt<=0)
			goto true;
	}
	else if(c==NEQE){
		if( reslt)
			goto true;
	}
	else if(c==LTTH){
		if( reslt<0)
			goto true;
	}
	else if(c==GTEQ){
		if( reslt>=0)
			goto true;
	}
	else if(c==GRTH){
		if( reslt>0)
			goto true;
	}
	else
		error(SYNTAX);
	res.i=0;        /* false */
	return;
true:
	res.i = -1;
}

/*      converts a number in 'res' to a string in gblock
 *    the string will have a space at the start if it is positive
 */


STR
mgcvt()
{
	int     sign, decpt;
	int     ndigit=9;
	CHAR   *p1, *p2;
	int    i;
	STR	st;

	if(vartype== IVAL)	/* integer deal with them separately */
		return(lgcvt());
#ifndef SOFTFP
	p1 = necvt(res.f, ndigit+2, &decpt, &sign);
#else
	p1 = necvt(&res, ndigit+2, &decpt, &sign);
#endif
	st = ALLOC_STR( (ival) (ndigit + 10));	/* needed for extra chars */

	*st->strval = sign ? '-' : ' ';
	/*
	 * work out number of significant digits
	 */
	if(ndigit > 1){
		p2 = p1 + ndigit-1;
		do {
			if(*p2 != '0')
				break;
			ndigit--;
		}while(--p2 > p1);
	}
	p2 = &st->strval[1];

	/*
	 * if need 1e2 representation then do it here
	 */
	if(decpt < 0 || decpt > 9){
		decpt--;
		/*
		 * print out first digit
		 */
		*p2++ = *p1++;
		/*
		 * if more than one digit print out
		 */
		if(ndigit != 1){
			*p2++ = '.';
			for (i=1; i<ndigit; i++)
				*p2++ = *p1++;
		}
		/*
		 * now do the exponent
		 */
		*p2++ = 'e';
		if (decpt<0) {
			decpt = -decpt;
			*p2++ = '-';
		}
		for(i = 1000 ; i ; i /= 10)
			if(decpt >= i)
				break;
		for( ; i ; i /= 10){
			*p2++ = decpt/i + '0';
			decpt %= i;
		}
	}
	else {
		/*
		 * print out in normal notation
		 *  add a zero if decimal point is at start of line
		 */
		if(!decpt){
			*p2++ = '0';
			*p2++ = '.';
		}
		for(i=1; i<=ndigit; i++){
			*p2++ = *p1++;
			if(i==decpt && i != ndigit)
				*p2++ = '.';
		}
		while(ndigit++<decpt)
			*p2++ = '0';
	}
	*p2 = 0;
	st->strlen = p2 - st->strval;
	return(st);
}

/* integer version of above - a very simple algorithm */

static	STR
lgcvt()
{
	CHAR    s[16];
	CHAR   *p,*q;
	STR	st;
	ival	fl=0;
#ifdef	BIG_INTS
	unsigned long	l;
#else
	unsigned l;
#endif

	l=  res.i;
	q = p = &s[14];
	*p = 0;
	if(res.i <0){
		fl++;
		l= -l;
	}
	do{
		*p-- = l%10 +'0';
	}while(l/=10 );
	if(fl)
		*p ='-';
	else
		*p =' ';
	fl = q - p + 1;
	st = ALLOC_STR(fl);
	VOID strmov(st->strval, p, fl);
	return(st);
}

/*      get a linenumber or if no linenumber return a -1
 *    used by all routines with optional linenumbers
 */

lnumb
getlin()
{
	lnumb	l=0;
	int    c;

	c=getch();
	if(!isdigit(c)){
		point--;
		return(NOLNUMB);
	}
	do{
		if(l>=6553 )
			error(7);
		l= l*10 + (c-'0');
		c= UC(*point++);
	}while(isdigit(c));
	point--;
	return(l);
}

/*      getbline() gets a line number and returns a valid pointer
 *    to it, if there is no linenumber or the line is not there
 *    then there is an error. Used by 'goto' etc.
 */

lpoint
getbline()
{
	lnumb	l=0;
	lpoint p;
	int    c;

	c=getch();
	if(!isdigit(c))
		error(5);
	do{
		if(l>=6553)
			error(7);
		l= l*10+(c-'0');
		c= UC(*point++);
	}while(isdigit(c));
	point--;
			/* speed it up a bit no need to search the whole lot */
	if((p = stocurlin) == 0 || l < p->linnumb)
		p = program;
	for(; p ;p = p->next)
		if(p->linnumb == l)
			return(p);
	error(6);
	return(0);
}

lpoint
getsline(l)
lnumb	l;
{
	lpoint	p;

	if(l == NOLNUMB)
		return(program);

	if((p = stocurlin) == 0 || l < p->linnumb)
		p = program;

	for(; p ;p = p->next)
		if(p->linnumb == l)
			return(p);
	error(6);	/* undefined line */
	return(0);
}

lnumb
getrline(p)
lpoint	p;
{
	lpoint	op, savp;

	if(p->linnumb != CONTLNUMB)
		return(p->linnumb);

	savp = 0;
	for(op = program ; op != p ; op = op->next)
		if(op->linnumb != CONTLNUMB)
			savp = op;
	if(savp)
		return(savp->linnumb);
	return(0);
}

void
prsline(str, p)
lpoint	p;
const char *str;
{
	lpoint	op, savp;
	lnumb	xline;

	if(str)
		prints(str);

	if(p->linnumb != CONTLNUMB){
		printd(p->linnumb);
		return;
	}

	savp = 0;
	for(op = program ; op != p ; op = op->next)
		if(op->linnumb != CONTLNUMB)
			savp = op;
	if(savp == 0)
		op = program;
	else
		op = savp;
	for(xline = 0; op != p ; op = op->next)
		xline++;
	printd(savp ? savp->linnumb : 0);
	prints(".");
	printd(xline);
}

/*      printlin() returns a pointer to a string representing the
 *    the numeric value of the linenumber.  linenumbers are unsigned
 *    quantities.
 */

char    *
printlin(l)
lnumb	l;
{
	static char   ln[7];
	char   *p;

	p = &ln[5];
	do{
		*p-- = l %10 + '0';
	}while(l/=10);
	p++;
	return(p);
}

void
printd(l)
lnumb	l;
{
	prints(printlin(l));
}

/*      routine used to check the type of expression being evaluated
 *    used by print and eval.
 *      A string expression returns a value of '1'
 *      A numeric expression returns a value of '0'
 */

int
checktype()
{
	CHAR   *tpoint;
	int    c;

	if( (c= UC(*point)) & SPECIAL){
		if(c != FN){
			if(c == IFUNCA || c == IFUNCN || c == NOTT)
				return(0);
			if(c == OFUNC)
				error(SYNTAX);
			return(1);
		}
		tpoint = point + 1;
		c = UC(*tpoint++);
	}
	else {
		if(isdigit(c) || c=='.' || c== '-' || c=='(' || c == '&')
			return(0);
		if(c=='"' || c=='`')
			return(1);
		tpoint= point + 1;
	}
	if(!isalpha(c))
		error(SYNTAX);
	while(isalnum(*tpoint) || *tpoint == '_')
		tpoint++;
	if(*tpoint == D_STR)
		return(1);
	else if(*tpoint == D_INT || *tpoint == D_FLT)
		return(0);
	return(tcharmap[c - 'A'] == SVAL);
}

int
slen(s)
const char *s;
{
	const char *p = s;

	while(*p)
		p++;
	return(p - s);
}

/*      print out a message , used for all types of 'basic' messages
 */

void
prints(s)
const char    *s;
{
	VOID write(1, s,(unsigned)slen(s));
}

/*      copy a string from a to b returning the last address used in b
 */

CHAR    *
str_cpy(a,b)
CHAR   *a,*b;
{
	while( (*b = *a) != 0)
		b++, a++;
	return(b);
}

void
set_mem(b, len, c)
CHAR	*b;
ival	len;
int	c;
{
	if(!len)
		return;
	do {
		*b++ = (CHAR)c;
	} while(--len);
}

void
clr_mem(b, len)
CHAR	*b;
ival	len;
{
	if(len >= 20 && ((long)b & WORD_MASK) == 0){
		ival	xlen = len & WORD_MASK;
		len >>= WORD_SHIFT;
		do {
			/*LINTED*/
			*(int *)b = 0;
			b += sizeof(int);
		} while(--len);
		len = xlen;
	}
		
	if(!len)
		return;
	do {
		*b++ = 0;
	} while(--len);
}

CHAR	*
strmov(dest, src, len)
CHAR	*dest, *src;
ival	len;
{
	while (len-- > 0)
		*dest++ = *src++;
	return(dest);
}

#ifdef SOFTFP

int	getop(void);

int
getnumb(buf, bufp)
CHAR	*buf, **bufp;
{
	CHAR	*tmp;
	int	ret;

	tmp = point;
	point = buf;
	ret = getop();
	if(bufp)
		*bufp = point;
	point = tmp;
	return(ret);
}

#else

/* convert an ascii string into a number. If it is possibly an integer
 * return an integer.
 * Otherwise return a double ( in res )
 * should never overflow. One day I may fix the non floating point one.
 */

static	const	struct	cvttab	{
	double	cval;
	int	expn;
	double	maxval;
} cvttab[] = {
#ifdef	IEEEMATHS
#ifdef	NOT_NEEDED
	/*
	 * these values are not needed since they just slow the lower
	 * values down, and they don't improve the performance much for
	 * large values.
	 */
	{1e256,	256,	BIGval/1e256},	/* bad value */
	{1e128,	128,	BIGval/1e128},	/* bad value also in i386 */
	{1e64,	64,	BIGval/1e64},
#endif
#endif
	{1e32,	32,	BIGval/1e32},	/* bad value also in i386 */
	{1e16,	16,	BIGval/1e16},
	{1e8,	8,	BIGval/1e8},
	{10000,	4,	BIGval/10000},
	{100,	2,	BIGval/100},
	{10,	1,	BIGval/10},
	{0,	0,	0}
};

static	const	double	TEN = 10.0;

#ifdef	BIG_INTS
#define	MAX_L_INT	(MAX_INT / 10)
#else
#define MAX_L_INT	214748364
#endif

int
getnumb(ptr, ptrp)
CHAR	*ptr, **ptrp;
{
	double x;
	int    c;
	long	lx = 0;
	long	ly;
	long	lym = -1;
	int    exp;
	int    ndigits = 0;
	int    exponent = 0;
	char    decp = 0;
	char    lzeros = 0;
	int     minus;
	itype   xx;
	const	struct	cvttab	*cp = cvttab;
	int	seenz = 0;

	if(*ptr == '&'){
		c = UC(*++ptr);
		if(!isxdigit(c))
			return(0);
		do {
			if((unsigned long)lx &
			((unsigned long)0x0FL << (4 * (sizeof(itype) * 2 - 1))))
				return(0);
			if(isdigit(c))
				c -= '0';
			else
				c = (c & 0x7) + 9;
			lx = (lx << 4) | c;
			c = UC(*++ptr);
		} while(isxdigit(c));
		vartype= IVAL;
		res.i = (itype)lx;
		if(ptrp)
			*ptrp = ptr;
		return(1);
	}
	/*
	 * first accumulate number in a long since this is
	 * quicker than doing it in an fp number. When we have a
	 * large number (>8 digits) then we go back to original algorithm
	 */
	ly = 0;
	for(c = UC(*ptr) ; isdigit(c); c = UC(*++ptr)){
		if(lx >= MAX_L_INT){
			if(ly)
				break;
			ly = lx;
			lym = 1;
			lx = 0;
		}
		else if(!lzeros){
			seenz = 1;
			if(c == '0')	 /* ignore leading zeros */
				continue;
			lzeros++;
		}
		if(ly){
			assert(lym > 0);
			if(lym >= MAX_L_INT)
				break;
			lym *= 10;
		}
		ndigits++;
		lx = lx * 10 + c - '0';
	}

	if(ly){
		x = (double)ly * (double)lym;
		if(lx)
			x += (double)lx;
	}
	else if(lx)
		x = (double)lx;
	else
		x = ZERO;

dot:    for(; isdigit(c) ; c = UC(*++ptr)){
		if(!lzeros){
			if(c == '0'){ /* ignore leading zeros */
				seenz = 1;
				if(decp)
					exponent--;
				continue;
			}
			lzeros++;
		}
		if(ndigits > 17){      /* ignore insignificant digits */
			if(!decp)
				exponent++;
			continue;
		}
		if(decp)
			exponent--;
		ndigits++;
		/*
		 * there is a bug in the i386 C compiler which means
		 * that if I use c in:
		 * 	x = x * TEN + c - '0';
		 * then the bug bites and I get incorrect assembler code
		 */
		xx = c - '0';
		x = x * TEN + xx;
	}
	if(c == '.'){
		if(decp)
			return(0);
		c = UC(*++ptr);
		decp++;
		goto dot;
	}
	if(!ndigits && !seenz)
		return(0);
	if(c == 'e' || c == 'E'){
		minus = 0;
		exp = 0;
		if( (c = UC(*++ptr)) == '+' || c == '-'){
			if(c == '-')
				minus++;
			c = UC(*++ptr);
		}
		if(!isdigit(c))
			return(0);
		do {
			if(exp < BIGEXP)
				exp = exp * 10 + c - '0';
			c = UC(*++ptr);
		} while(isdigit(c));
		if(minus)
			exponent -= exp;
		else
			exponent += exp;
	}
	if(exponent < 0){
		exp = -exponent;
		do {
			while(exp >= cp->expn){
				x /= cp->cval;
				exp -= cp->expn;
			}
		} while((++cp)->expn);
	}
	else if(exponent > 0){
		/*
		 * Evaluate maximum values that can be multiplied
		 * by a given multiple of ten
		 */
		do {
			while(exponent >= cp->expn){
				if(x >= cp->maxval)
					return(0);
				x *= cp->cval;
				exponent -= cp->expn;
			}
		} while((++cp)->expn);
	}

	res.f = x;
	vartype = RVAL;

	switch(*ptr){
	case D_FLT:
		ptr++;
		break;
	case D_INT:
		ptr++;
		if(conv(&res)){
			if(ptrp)
				*ptrp = ptr;
			return(0);
		}
		vartype = IVAL;
		break;
	default:
#ifndef	UNPORTABLE
		if(x > MAXint || x < MINint)
			break;
#endif
		xx = (itype)x;			/* see if x is == an integer */
		/*
		 * shouldn't need a cast below but there is a bug in the 68000
		 * compiler which does the comparison wrong without it.
		 */
		if( (double) xx == x){
			vartype = IVAL;
			res.i = xx;
		}
		break;
	}

	if(ptrp)
		*ptrp = ptr;
	return(1);
}

/*
 * perform the opposite function to getop. Return a string
 * from a double. with at most ndigits.
 * rounding is performed on the last digit.
 */

CHAR	*
necvt(x, ndigits, decpt, sign)
int	ndigits, *decpt, *sign;
double	x;
{
	CHAR	*p;
	int	nd;

	_scale(&x, decpt, sign, 1);

	p = d_expand(x, ndigits, &nd);
	if(nd)
		(*decpt)++;
	return(p);
}

static	CHAR	*
d_expand(x, ndigits, nd)
double	x;
int	ndigits;
int	*nd;
{
	CHAR	*p;
	int	ndig = ndigits + 1;
	int	c;
	static	CHAR	tbuf[30];

	for(p = tbuf, *p++ = '0'; ndig ; ndig--){
		*p = (CHAR)x;
		x =  (x - (double)*p) * TEN;
		*p++ += '0';
	}
	if(nd == 0){
		*p = 0;
		return(tbuf + 1);
	}
	*nd = 0;
	c = (int)*--p;
	*p = 0;
	if(c >= '5'){
		for(;;){
			++(*--p);
			if(*p <= '9')
				break;
			*p = '0';
		}
		if(p == tbuf){
			*nd = 1;
			tbuf[ndigits] = 0;
			return(tbuf);
		}
	}
	return(tbuf + 1);
}
#endif

static	void
_scale(xp, decpt, sign, zflag)
int	*sign;
double	*xp;
int	*decpt;
int	zflag;
{
	const	struct	cvttab	*cp = cvttab;
	int	exp;
	double	x = *xp;
	double	y;

#ifdef	NaN
	if(NaN(x))
		if(IsPosNAN(x))
			x = BIG;
		else
			x = BIGminus;
#endif
	*sign = 0;
	if(x <= ZERO){
		if(x == ZERO){
			*decpt = zflag; 
			return;
		}
		x = -x;
		*sign = 1;
	}
	exp = 0;
	if(x < ONE){
		do {
			while( (y = x * cp->cval) < TEN){
				x = y;
				exp -= cp->expn;
			}
		}while( (++cp)->expn);
	}
	else if(x >= TEN){
		do {
			while(x >= cp->cval){
				x /= cp->cval;
				exp += cp->expn;
			}
		}while( (++cp)->expn);
	}

	*decpt = exp + 1;
	*xp = x;
}

STR
mathpat(spat)
STR	spat;
{
	STR	outstr;
	CHAR	*pat, *epat;
	ival	olen;
	ival	flen;

	int	done_spec = 0;
	int	dot = 0;
	int	lchars = 0;
	int	comma = 0;
	int	rchars = 0;
	int	exp = 0;
	int	last_char = 0;
	int	first_char = 0;
	int	dolars = 0;
	int	stars = 0;
	CHAR	*p;

	CHAR	num_buf[64];

	olen = spat->strlen;
	if(olen < LOC_BUF_SIZ)
		olen = LOC_BUF_SIZ;

	outstr = ALLOC_STR(olen);
	outstr->strlen = 0;

	for(pat = spat->strval, epat = pat + spat->strlen ; pat < epat ; pat++){
		if(last_char){
			for(p = (CHAR *)",.#^+-*$"; *p && *p != *pat ; p++);
			if(*p){
			bad:;
				error(BADFORMAT);
			}
		}
		switch(*pat){
		default:
			if(done_spec){
				if(dolars == 1 && !stars)
					goto bad;
				flen = pat_exp(num_buf, lchars, rchars, dot,
						exp, stars, first_char,
						last_char, dolars, comma);
				if(outstr->strlen + flen > olen){
					RESERVE_SPACE(outstr, olen + flen);
					olen += flen;
				}
				VOID strmov(outstr->strval + outstr->strlen,
								num_buf, flen);
				outstr->strlen += flen;
				done_spec = 0;
				dot = 0;
				lchars = 0;
				rchars = 0;
				comma = 0;
				exp = 0;
				last_char = 0;
				first_char = 0;
				dolars = 0;
				stars = 0;
			}
			if(*pat == '_' && pat + 1 < epat)
				pat++;
			if(outstr->strlen >= olen){
				RESERVE_SPACE(outstr, (ival)(olen + 32));
				olen += 32;
			}
			outstr->strval[outstr->strlen++] = *pat;
			continue;
		case ',':
			if(comma || dot)
				goto bad;
			comma = 1;
			break;
		case '.':
			if(dot)
				goto bad;
			dot = 1;
			break;
		case '#':
			if(dot)
				rchars++;
			else
				lchars++;
			break;
		case '^':
			if(!done_spec || (!rchars && !lchars) || exp)
				goto bad;
			exp = 0;
			while(pat < epat && *pat == '^'){
				exp++;
				pat++;
			}
			pat--;
			if(exp < 3 || exp > 5)
				goto bad;
			break;
		case '+':
			if(!done_spec)
				first_char = '+';
			else
				last_char = '+';
			break;
		case '-':
			if(!done_spec)
				goto bad;
			else
				last_char = '-';
			break;
		case '*':
			if(dolars || stars || lchars || rchars || dot)
				goto bad;
			while(pat < epat && *pat == '*'){
				pat++;
				stars++;
			}
			pat--;
			if(stars != 2)
				goto bad;
			break;
		case '$':
			if(lchars || rchars || dot)
				goto bad;
			dolars++;
			if(dolars > 2 || (stars && dolars > 1))
				goto bad;
			break;
		}
		done_spec = 1;
	}
	if(done_spec){
		flen = pat_exp(num_buf, lchars, rchars, dot, exp, stars,
					first_char, last_char, dolars, comma);
		if(outstr->strlen + flen > olen)
			RESERVE_SPACE(outstr, (ival)(outstr->strlen + flen));
		VOID strmov(outstr->strval + outstr->strlen, num_buf, flen);
		outstr->strlen += flen;
	}
	return(outstr);
}

static	int
pat_exp(num_buf, lchars, rchars, dot, exp, stars,
		first_char, last_char, dolars, comma)
CHAR	*num_buf;
int	lchars, rchars, dot, exp, stars,
		first_char, last_char, dolars, comma;
{
	int	nd;
	int	decpt;
	int	sign;
	CHAR	*p;
	CHAR	*pf;
	int	ndigits;
	int	sdigs;
	int	scnt;
	int	fsign;

	pf = num_buf;
	if(!lchars && !rchars){
	bad:;
		error(BADFORMAT);
	}
	/*
	 * now we have to do the conversion
	 */

	if(vartype != RVAL)
		cvt(&res);
		
	_scale(&res.f, &decpt, &sign, (exp && lchars));

	/*
	 * now check to see if this thing will fit in
	 * the given space. if we aren't in scientific
	 * notation, then we limit ourselves
	 * to a max of 24 
	 */
	if(decpt > 24 && !exp)
		goto bad;
	if(lchars + rchars > 24)
		goto bad;

	fsign = first_char || (!last_char && sign);

	if(exp){
		ndigits = rchars;
		if(lchars){
			decpt--;
			ndigits++;
		}
		p = d_expand(res.f, ndigits, &nd);
		if(nd)
			decpt++;
		if(decpt >= 100 && exp < 5)
			*pf++ = '%';
		if(stars){
			if(!fsign)
				*pf++ = '*';
			*pf++ = '*';
		}
		while(lchars > 1){
			*pf++ = stars ? '*' : ' ';
			lchars--;
		}
		if(fsign)
			*pf++ = sign ? '-' : '+';
		if(dolars)
			*pf++ = '$';
		if(lchars > 0)
			*pf++ = *p++;
		else if(last_char)
			*pf++ = '0';
				
		if(dot)
			*pf++ = '.';
		while(rchars > 0){
			*pf++ = *p++;
			rchars--;
		}
		*pf++ = 'E';
		if(exp > 3 || decpt < 0)
			*pf++ = (decpt < 0) ? '-' : '+';
		if(decpt < 0)
			decpt = -decpt;
		if(decpt >= 100 || exp > 4){
			*pf++ = (decpt / 100) + '0';
			decpt %= 100;
		}
		*pf++ = (decpt / 10) + '0';
		*pf++ = (decpt % 10) + '0';
	}
	else {
		sdigs = stars + lchars;
		if(dolars > 1)
			sdigs++;
		ndigits = decpt + rchars;
		if(ndigits > 24)
			goto bad;
		if(ndigits < 0)
			ndigits = 0;
		p = d_expand(res.f, ndigits, &nd);
		if(nd){
			decpt++;
			p[ndigits] = '0';
		}
		if(decpt > sdigs){
			*pf++ = '%';
			sdigs = decpt;
		}
		if(decpt > 0)
			scnt = sdigs - decpt;
		else
			scnt = sdigs - 1;
		if(!last_char && sign)
			scnt--;
		while(scnt > 0){
			scnt--;
			*pf++ = stars ? '*' : ' ';
		}

		if(fsign)
			*pf++ = sign ? '-' : '+';

		if(dolars)
			*pf++ = '$';
		if(lchars && decpt <= 0)
			*pf++ = '0';
		sdigs = decpt;
		while(sdigs > 0){
			*pf++ = *p++;
			sdigs--;
			if(comma && sdigs && (sdigs % 3) == 0)
				*pf++ = ',';
		}
		if(dot)
			*pf++ = '.';
		while(rchars > 0){
			if(decpt < 0){
				*pf++ = '0';
				decpt++;
			}
			else
				*pf++ = *p++;
			rchars--;
		}
	}
	if(last_char == '+' || (last_char && sign))
		*pf++ = sign ? '-' : '+';
	return(pf - num_buf);
}
