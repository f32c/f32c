/*
 * BASIC by Phil Cockcroft
 */
#include "bas.h"

/* this file contains all the routines that were originally done in assembler
 * these routines only require a floating point emulator to work.
 * To speed things up some routines could be put into assembler and some
 * could be made into macros. the relevent routines are labeled as such
 */

#ifndef VAX_ASSEM       /* if done in assembler don't bring it in */
#ifndef	NS_ASSEM
/* AS */

/* get a single character from the line pointed to by getch() */

int
getch()
{
	char   *p;

	p = (char *)point;
	while(*p == ' ')
		p++;
#ifdef	mips
	point = (CHAR *)(p+1);
	return(*(unsigned char *)p);
#else
	point = (CHAR *)++p;
	return(*(unsigned char *)(p - 1));
#endif
}

/* AS  #define  ELSE 0351 */

void
check()         /* check to see no garbage at end of command */
{
	char   *p;
	char   c;

	p = (char *)point;
	while(*p == ' ')
		p++;
	if((c = *p) == 0 || c == ':' || (c == (char)ELSE && elsecount)){
		point = (CHAR *)p;
		return;
	}
	error(SYNTAX);          /* not a terminator - error */
}
#endif
#endif

#ifndef SOFTFP
/*ARGSUSED*/
void
fpcrash(void)
{
	c_error(34);	/* arithmetic overflow */
	if(res.f < ZERO)
		res.f = BIGminus;
	else
		res.f = BIG;
}
#endif

void
startfp()
{
#ifndef SOFTFP
	fpfunc = fpcrash;       /* will call error(34) on overflow */
#else
	fpfunc = 0;
#endif
}

int
_conv(p)
value	*p;
{
	ival	i;

	i = p->f;
	if(i < 0){
		if(i == -MAX_INT - 1){
			p->i = i;
			return(0);
		}
		i--;
	}
	else if(i == 0 && p->f < ZERO)
		i--;
	if( (p->f - i) >= 0.5)
		i++;
	p->i = i;
	return(0);
}

/* AS */

/* compare two values. return 0 if equal -1 if first less than second
 * or 1 for vice versa.
 */

int
cmp(p,q)
value  *p,*q;
{
	if(vartype != RVAL){
		if(p->i == q->i)
			return(0);
		else if(p->i < q->i)
			return(-1);
		return(1);
	}
	if(p->f == q->f)
		return(0);
	else if(p->f< q->f )
		return(-1);
	return(1);
}

/* the arithmetic operation jump table */

/* all the routines below should be put into AS */

#if	defined(mips) && !defined(lint) && !defined(CDS_COMPILER)
static	void	fandor(valp, valp, int), andor(valp, valp, int);
static	void	comop(valp, valp, int), fads(valp, valp, int);
static	void	ads(valp, valp, int), fmdm(valp, valp, int);
static	void	mdm(valp, valp, int), fexp(valp, valp, int), ex(valp, valp,int);
#else
static	mbinf_t	fandor, andor, comop, fads, ads, fmdm, mdm, fexp, ex;
#endif


const	mathf_t	mbin = {
	0, 0,
	fandor,
	andor,
	comop,
	comop,
	fads,
	ads,
	fmdm,
	mdm,
	fexp,
	ex,
};

static	void
ex(p,q,c)               /* integer exponentiation */
valp    p,q;
int	c;
{
	if(p->i < 0)
		error(41);
	if(q->i >= 0 && q->i < 31){
		itype  ll = 1;
		for(c = 0; c < q->i ; c++){
			ll = mmult_ply(p->i, ll, 0);
			if(vartype == RVAL)
				goto exp_over;
		}
		q->i = ll;
		return;
	}
exp_over:;
	cvt(p);
	cvt(q);
	vartype = RVAL;
	fexp(p,q,c);
}

static	void
fmdm(p,q,c)             /* floating * / mod */
valp    p,q;
int	c;
{
	double	fmod(double, double);
/*
	double  floor();
	double	x;
*/

	if(c == '*'){
		fmul(p,q);
		return;
	}
	if(q->f == ZERO)
		error(25);
	if(c != MODD)
		fdiv(p,q);
	else  {         /* floating mod - yeuch */
		q->f = fmod(p->f, q->f);
/*
		if( (x = p->f/q->f) < ZERO)
			q->f = p->f + floor(-x) * q->f;
		else
			q->f = p->f - floor(x) * q->f;
*/
	}
}

static	void
mdm(p,q,c)              /* integer * / mod */
valp    p,q;
int	c;
{
	itype  ll;

	if(c=='*'){
#ifdef	BIG_INTS
		ll = mmult_ply(p->i, q->i, 0);

		if(vartype != RVAL)
			q->i = ll;
		else {
			cvt(p);
			cvt(q);
			fmul(p, q);
		}
#else
		long    l = (long)p->i * q->i;
		if(l > 32767 || l < -32768){    /* overflow */
			q->f = l;
			vartype = RVAL;
		}
		else q->i = (itype)l;
#endif
		return;
	}
	if(!q->i)                       /* zero divisor error */
		error(25);
	ll = p->i % q->i;
	if(c != MODD){
		if(ll && c == '/'){
#ifdef	SOFTFP
			cvt(p);
			cvt(q);
			fdiv(p,q);
#else
			q->f = (double)p->i / (double)q->i;
#endif
			vartype = RVAL;
		}
		else
			q->i = p->i / q->i;
	}
	else
		q->i = ll;
}

static	void
fads(p,q,c)             /* floating + - */
valp    p,q;
int	c;
{
	if(c=='+')
		fadd(p,q);
	else
		fsub(p,q);
}

static	void
ads(p,q,c)              /* integer + - */
valp    p,q;
int	c;
{
	long   l;
	itype	ii;

	l = p->i;
	if(c == '+'){
		l += q->i;
		if(!IS_OVER(q->i, p->i, l)){	 /* overflow */
			q->i = (itype)l;
			return;
		}
	}
	else if( (ii = -q->i) != q->i){
		l += ii;
		if(!IS_OVER(ii, p->i, l)){	 /* overflow */
			q->i = (itype)l;
			return;
		}
	}
	cvt(p);
	cvt(q);
	vartype = RVAL;
	if(c=='+')
		fadd(p,q);
	else
		fsub(p,q);
}

#define	APRXVAL	(1e-9)

static	int
aprx(p, q)
valp	p, q;
{
	double	x;

	if(vartype != RVAL)
		return(p->i == q->i);

	vartype = IVAL;
	if(p->f == q->f)
		return(1);

	if(q->f == ZERO){
		/*
		 * I know that p->f is not zero since p->f != q->f
		 */
		x = p->f;
	}
	else if(p->f == ZERO)
		x = q->f;
	else {
		if( (x = (p->f / q->f)) < ZERO)
			x += ONE;
		else
			x -= ONE;
	}
	if(x < ZERO)
		return( x >= -APRXVAL);
	return(x <= APRXVAL);
}

static	void
comop(p,q,c)                    /* comparison operations */
valp    p,q;
int	c;
{
	if(c == APRX)
		q->i = aprx(p, q) ? -1 : 0;
	else
		compare(c,cmp(p,q));
}

static	void
fandor(p,q,c)                   /* floating logical AND/OR/XOR */
valp    p,q;
int	c;
{
	p->i = IS_ZERO(*p) ? 0 : -1;
	q->i = IS_ZERO(*q) ? 0 : -1;
	vartype = IVAL;
	andor(p,q,c);
}

static	void
andor(p,q,c)                    /* integer logical */
valp    p,q;
int	c;
{
	itype	i,j;

	i = p->i;
	j = q->i;
	switch(c){
	case ANDD:
		i &= j;
		break;
	case ORR:
		i |= j;
		break;
	case XORR:
		i ^= j;
		break;
	case IMPP:
		i = (~i) | (i & j);
		break;
	case EQVV:
		i = ~(i ^ j);
		break;
	}
	q->i = i;
}

/* down to about here */

/* MACRO */

/* convert + put the value in res into p */

void
putin(p,var)
value   *p;
int	var;
{
	if(vartype != (char)var){
		if(var != RVAL){
			if(conv(&res))
				error(35);
		}
		else
			cvt(&res);
	}
	if(var != RVAL)
		p->i = res.i;
	else
#ifdef	mips
		*p = res;
#else
		p->f = res.f;
#endif
}

/* MACRO */

void
negate()                /* negate the value in res */
{
	itype	t;

	if(vartype != RVAL){
		t = res.i;
		res.i = -t;
		if(t != res.i)		/* normal case */
			return;
		cvt(&res);		/* negate -maxint */
		vartype = RVAL;
	}
	res.f = -res.f;
}

/* MACRO */

void
notit()                 /* logical negation */
{
	if(vartype != RVAL){
		res.i = ~res.i;
		return;
	}
	res.i = IS_ZERO(res) ? -1 : 0;
	vartype = IVAL;
}

double	log(double), exp(double);

/*ARGSUSED*/
static	void
fexp(p,q,c)                     /* floating exponentiation */
valp    p,q;
int	c;
{
	double  x;

	if(p->f < ZERO)
		error(41);
	else if(q->f == ZERO)
		q->f = ONE;
	else if(p->f == ZERO)            /* could use pow - but not on v6 */
		q->f = ZERO;
	else {
		if( (x = log(p->f) * q->f) > LOGMAXVAL){ /* should be bigger */
			c_error(40);
			x = LOGMAXVAL;
		}
		q->f = exp(x);
	}
}

#ifdef	BIG_INTS

itype
mmult_ply(p, q, err)
itype p, q;
int	err;
{
	unsigned long	aa, bb;
	unsigned long	result;
	int	minus = 0;

	if(p < 0){
		minus = 1;
		aa = -p;
	}
	else
		aa = p;
	if(q < 0){
		minus ^= 1;
		bb = -q;
	}
	else
		bb = q;
	/*
	 * we use the smallest value as the loop variable, to reduce time
	 * whether this improves performance depends on the relative sizes
	 * of bb and aa.
	 */
	if(bb > aa){
		result = aa;
		aa = bb;
		bb = result;
	}
	result = 0;
	while(bb){
		if(aa & TOP_BIT)
			goto over;
		if(bb & 1){
			result += aa;
			if(result & TOP_BIT)
				goto over;
		}
		aa <<= 1;
		bb >>= 1;
	}
	return( (itype) (minus ? -result : result) );
over:
	if(err)
		error(err);
	vartype = RVAL;
	return( (itype)0);
}

#endif
