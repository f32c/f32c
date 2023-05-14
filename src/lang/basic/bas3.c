/*
 * BASIC by Phil Cockcroft
 */
#include        "bas.h"

/*
 *      This file contains the numeric evaluation routines and some
 *    of the numeric functions.
 */

/*
 *      evalint() is called by a routine that requires an integer value
 *    e.g. string functions. It will always return an integer. If
 *    the result will not overflow an integer -1 is returned.
 *      N.B. most ( all ) routines assume that a negative return is an
 *    error.
 */

union	ffn_vars {
	struct	{
		value	_ovr;
		value	_nvr;
	} _ivs;
	struct	{
		STR	_ostr;
		STR	_nstr;
	} _svs;
};

#define	ovr	_ivs._ovr
#define	nvr	_ivs._nvr
#define	ostr	_svs._ostr
#define	nstr	_svs._nstr

static	void	recov_parms(struct entry **, int, union ffn_vars *, int);
static	void	setdrg(int);
static	void	hyper_sc(int);

#ifndef SOFTFP
extern	double  sin(double);
extern	double  cos(double);
extern	double	asin(double);
extern	double	acos(double);
extern	double  atan(double);
extern	double	exp(double);
extern	double	log(double);
extern	double  sqrt(double);
static	const	double	logmaxval = LOGMAXVAL;
static	const	double	TWO = 2.0;
static	const	double	INSIG = MAX_INSIG;
static	const	double	logof2 = 0.69314718055994530942;
#endif

itype
evalint()
{
	eval();
	if(vartype != RVAL)
		return(res.i);
	if(conv(&res)){
		error(INTOVER);
#if 0
		if(res.f < ZERO)
			res.i = -MAX_INT-1;
		else
			res.i = MAX_INT;
#endif
	}
	return(res.i);
}

/*
 * evalreal is called in a similar manner to evalint but it always returns
 * a real value (in res).
 */

void
evalreal()
{
	eval();
	if(vartype != RVAL){
		cvt(&res);
		vartype= RVAL;
	}
}

/*
 *      This structure is only ever used by eval() and so is not declared
 *    in 'bas.h' with the others.
 */

struct  m {
	value   r1;
	int     lastop;
	int	mvalue;
	char    vty;
};

/*
 *      eval() will evaluate any numeric expression and return the result
 *    in the UNION 'res'.
 *      A valid expression can be any numeric expression or a string
 *    comparison expression e.g. "as" <> "gh" . String expressions can
 *    themselves be used in relational tests and also be used with the
 *    logical operators. e.g. "a" <> "b" and "1" <> a$ is a valid
 *    expression.
 */

#define	SETNOT		1
#define	SETMINUS	2

void
eval()
{
	int    c;
	struct	m	*j;
	int    i;
	value	*pp;
	int	firsttime;
	int	unaries[2];
	struct	m	restab[6];

	j=restab;
	j->mvalue=0;
	unaries[0] = unaries[1] = 0;
	firsttime = 1;

for(;;){
	c=getch();
	if(c=='-' && firsttime){
		if((unaries[0] == SETMINUS) || unaries[1])
			error(SYNTAX);
		unaries[1] = unaries[0];
		unaries[0] = SETMINUS;
		continue;
	}
	else if(c==NOTT){
		if(unaries[0] == SETNOT){
			unaries[0] = unaries[1];
			unaries[1] = 0;
			firsttime++;
			continue;
		}
		if(unaries[1])
			error(SYNTAX);
		unaries[1] = unaries[0];
		unaries[0] = SETNOT;
		firsttime++;
		continue;
	}
	else if(c & SPECIAL){
		if(c == IFUNCN)	/* functions that don't have brackets */
			(*functs[*point++ & 0177])();
		else if(c == IFUNCA){	/* functions that do have brackets */
			c = (int)*point++ & 0177;
			if(*point++ !='(')
				error(SYNTAX);  /* functions that do */
			(*functb[c])();
			if(getch()!=')')
				error(SYNTAX);
		}
		else if(c == OFUNC)
			error(SYNTAX);
		else if(c == FN)
			ffn((struct entry *)0, (STR)0);
		else
			goto err1;
#ifdef	NaN
		if(vartype == RVAL && NaN(res.f))
			(*fpfunc)();
#endif
	}
	else if(isalpha(c)){
		CHAR    *sp = --point;

		pp= (value *)getname(0);         /* we have a variable */
#if 0
		if(pp == 0){
			point = sp;
			ffn((struct entry *)0, (STR)0);
#ifdef	NaN
			/*LINTED*/
			if(vartype == RVAL && NaN(res.f))
				(*fpfunc)();
#endif
			goto ex;
		}
#endif
		if(vartype== SVAL){       /* a string !!!!!! */
			if(firsttime){  /* no need for checktype() since */
				point = sp;     /* we know it's a string */
				stringcompare();
				goto ex;
			}
			else error(2);          /* variable required */
		}
		if(vartype == IVAL)
			res.i = pp->i;
		else
			res = *pp;
	}
	else if(isdigit(c) || c=='.' || c == '&'){
		if(!getnumb(--point, &point))   /* we have a number */
			error(36);      	/* bad number */
	}
	else if(c=='('){                /* bracketed expression */
		eval();                 /* recursive call of eval() */
		if(getch()!=')')
			error(SYNTAX);
	}
	else  {
err1:           /* get here if the function we tried to access was not   */
		/* a legal maths func. or a string variable */
		/* stringcompare() will give a syntax error if not a valid */
		/* string. therefore this works ok */
		point--;
		if(!firsttime)
			error(SYNTAX);
		stringcompare();
	}
ex:
	/*
	 * now perform unary operations.
	 * only do this if we have some
	 */
	if(unaries[0]){
		if(unaries[0] == SETMINUS)
			negate();	/* unary minus */
		else
			notit();	/* unary not */
		if(unaries[1] == SETMINUS)
			negate();
		else if(unaries[1] == SETNOT)
			notit();
		unaries[0] = unaries[1] = 0;
	}
	firsttime = 1;
	switch(c = getch()){            /* get the precedence of the */
	case '^':			/* operator */
		i = 5;
		break;
	case '*':
	case '/':
	case '\\':
	case MODD:
		firsttime = 0;
		i = 4;
		break;
	case '+':
	case '-':
		firsttime = 0;
		i = 3;
		break;
	case APRX:
	case EQL:            /* comparison operators */
	case LTEQ:
	case NEQE:
	case LTTH:
	case GTEQ:
	case GRTH:
		i = 2;
		break;
	case ANDD:		/* logical operators */
	case ORR:
	case XORR:
	case IMPP:
	case EQVV:
		i = 1;
		break;
	default:
		i=0;
		break;
	}

#if 1
	while(j->mvalue >= i){
		if(! j->mvalue ){               /* end of expression */
			point--;
			return;
		}
		if(j->vty!=vartype){            /* make both parameters */
			if(vartype != RVAL)             /* the same type */
				cvt(&res);
			else
				cvt(&j->r1);  /* if changed then they must be */
			vartype= RVAL;              /* changed to reals */
		}
		(*mbin[(j->mvalue<<1)+vartype])(&j->r1,&res,j->lastop);
#ifdef	NaN
		if(vartype == RVAL && NaN(res.f))
			(*fpfunc)();
#endif
		j--;                    /* execute it then pop the stack and */
	}				/* deal with the next operator */
	(++j)->lastop=c;                        /* precedence */
	j->r1 = res;
	j->mvalue= i;
	j->vty=vartype;
#else
ame:    if(j->mvalue < i){         /* current operator has higher */
		(++j)->lastop=c;                        /* precedence */
		j->r1 = res;
		j->mvalue= i;
		j->vty=vartype;
		continue;
	}
	if(! j->mvalue ){               /* end of expression */
		point--;
		return;
	}
	if(j->vty!=vartype){            /* make both parameters */
		if(vartype != RVAL)             /* the same type */
			cvt(&res);
		else
			cvt(&j->r1);    /* if changed then they must be */
		vartype= RVAL;              /* changed to reals */
	}
	(*mbin[(j->mvalue<<1)+vartype])(&j->r1,&res,j->lastop);
#ifdef	NaN
	if(vartype == RVAL && NaN(res.f))
		(*fpfunc)();
#endif
	j--;                    /* execute it then pop the stack and */
	goto ame;               /* deal with the next operator */
#endif
	}
}

/*
 *      The rest of the routines in this file evaluate functions and are
 *    relatively straight forward.
 */

void
tim()
{
	struct timespec ts;
	static uint64_t t0;

	clock_gettime(CLOCK_MONOTONIC, &ts);
	if (t0 == 0)
		t0 = ts.tv_sec;
	res.f = 1.0 * (ts.tv_sec - t0) + ts.tv_nsec / 1000000000.0;
	vartype = RVAL;
}

#ifdef	RAND48

extern	double	drand48(void);
extern	long	lrand48(void);
extern	void	srand48(long);

void
rnd()
{
	itype	rnumb;

	if(*point != '('){
		res.i = (itype)lrand48();
		vartype = IVAL;
		return;
	}
	point++;
	rnumb = evalint();
	if(getch()!=')')
		error(SYNTAX);
	if(rnumb == 0){
		res.f = drand48();
		vartype = RVAL;
	}
	else {
		res.i = lrand48() % rnumb + 1;
		vartype = IVAL;
	}
}

/*
 *      This routine is the command 'random' and is placed here for some
 *    unknown reason it just sets the seed to rnd to the value from
 *    the time system call ( is a random number ).
 */

int
brandom()
{
	long    m;

	VOID time(&m);
	srand48((long)m);
	normret;
}

#else

void
rnd()
{
	static  const	double  recip32 = 32767.0;
#ifdef	SOFTFP
	value   temp;
#endif
	int    rn;

	rn = rand() & 077777;
	if(*point!='('){
		res.i= (short)rn;
		vartype= IVAL;
		return;
	}
	point++;
	eval();
	if(getch()!=')')
		error(SYNTAX);
	if(!IS_ZERO(res)){
		if(vartype == RVAL && conv(&res))
			error(FUNCT);
		res.i= rn % res.i + 1;
		vartype= IVAL;
		return;
	}
#ifndef SOFTFP
	res.f = (double)rn / recip32;
#else
	temp.i=rn;
	cvt(&temp);
	res = *( (value *)( &recip32 ) );
	fdiv(&temp,&res);            /* horrible */
#endif
	vartype = RVAL;
}

/*
 *      This routine is the command 'random' and is placed here for some
 *    unknown reason it just sets the seed to rnd to the value from
 *    the time system call ( is a random number ).
 */

int
brandom()
{
	long    m;

	VOID time((void *) &m);
	srand((int)m);
	normret;
}

#endif

void
erlin()
{
	res.i = (itype)elinnumb;
	vartype= IVAL;
#ifndef	BIG_INTS
	if(res.i < 0 ){                      /* make large linenumbers */
#ifndef SOFTFP
		res.f = (unsigned)elinnumb;
		vartype = RVAL;
#else
		overfl=(unsigned)elinnumb;      /* into reals as they */
		over(0,&res);                   /* overflow integers */
#endif
	}
#endif
}

void
erval()
{
	res.i = (itype)ecode;
	vartype= IVAL;
}

void
sgn()
{
	eval();
#ifndef UNPORTABLE
	if(vartype == RVAL){
		if(res.f < ZERO)
			res.i = -1;
		else if(res.f > ZERO)
			res.i = 1;
		else res.i = 0;
		vartype = IVAL;
		return;
	}
#endif
	if(res.i<0)             /* bit twiddling */
		res.i = -1;     /* real numbers have the top bit set if */
	else if(res.i>0)        /* negative and the top word is non-zero */
		res.i= 1;       /* for all non-zero numbers */
	vartype=IVAL;
}

void
babs()
{
	eval();
#ifndef UNPORTABLE
	if(vartype == RVAL){
		if(res.f < ZERO)
#ifndef	SOFTFP
			res.f = -res.f;
#else
			negate();
#endif
		return;
	}
#endif
	if(res.i<0)
		negate();
}

void
len()
{
	STR	st;

	st = stringeval();
	res.i = (itype)st->strlen;
	vartype= IVAL;
	FREE_STR(st);
}

void
ascval()
{
	STR	st;

	st = stringeval();
	if(!st->strlen)
		error(FUNCT);
	res.i = (itype)UC(*st->strval);
	vartype= IVAL;
	FREE_STR(st);
}

void
bsqrtf()
{
	evalreal();
	if(res.f < ZERO){
		c_error(37);      /* negative square root */
		return;
	}
#ifndef SOFTFP
	res.f = sqrt(res.f);
#else
	sqrt(&res);
#endif
}

void
blogf()
{
	evalreal();
	if(res.f <= ZERO){
		c_error(38);      /* bad log value */
		return;
	}
#ifndef SOFTFP
	res.f = log(res.f);
#else
	log(&res);
#endif
}

void
blog10f()
{
	static	const	double	log10val = 2.30258509299404568402;

	evalreal();
	if(res.f <= ZERO){
		c_error(38);      /* bad log value */
		return;
	}
#ifndef SOFTFP
	res.f = log(res.f) / log10val;
#else
	log(&res);
	fdiv(&log10val, &res);
#endif
}

void
bexpf()
{
	evalreal();
#ifndef SOFTFP
	if(res.f > logmaxval){
		c_error(39);
		res.f = logmaxval;
	}
	res.f = exp(res.f);
#else
	if(!exp(&res))
		error(39);      /* overflow in exp */
#endif
}

void
pii()
{
#ifndef SOFTFP
	res.f = pivalue;
#else
	movein(&pivalue,&res);
#endif
	vartype= RVAL;
}

/*
 *      This routine will deal with the eval() function. It has to do
 *    a lot of moving of data. to enable it to 'compile' an expression
 *    so that it can be evaluated.
 */

void
evalu()
{
	CHAR   *tmp;
	STR	st;
	int	c;

	if(evallock>10)
		error(43);      /* mutually recursive eval */
	evallock++;
	st = stringeval();
	if(st->strlen > MAXLIN-1)
		error(10);
	else if(!st->strlen)
		error(SYNTAX);
	*strmov(line, st->strval, st->strlen) = 0;
#if 0
	/*
	 * when compiling, the resultant string will be less than or equal
	 * to the length of the original string
	 */
	st->strlen = 0;			/* defeat default copy action */
	RESERVE_SPACE(st, MAXLIN);
#endif
	VOID compile(0, st->strval, 1);
	tmp=point;
	point = st->strval;
	eval();
	c = getch();
	point=tmp;
	evallock--;
	FREE_STR(st);
	if(c)
		error(SYNTAX);
}

void
ffn(pep, strp)
struct	entry	*pep;
volatile STR	strp;
{
	struct  deffn   *p;
	struct	entry	*ep;
	int	i;
	union	ffn_vars *cur_arg;
	struct	entry	**rp, *rep;
	CHAR    *spoint;
	struct	forst	*fp;
	volatile char	vty = 0;
	char	ctype;
	STR	st;
	volatile STR	retst = 0;
	union	ffn_vars args[FN_MAX_ARGS];

	if( (ep = pep) == 0){
		if(!isalpha(*point))
			error(SYNTAX);
		ep = getnm(ISFUNC, 0);
		if(!ep)
			error(UNDEFFN);
		ctype = IS_MFN;
		vty = vartype;
		if( (strp && vty != SVAL) || (!strp && vty == SVAL))
			error(UNDEFFN);
		retst = strp;
	}
	else
		ctype = IS_MPR;
	p = ep->_deffn;
	if(p->narg){
		if(*point++!='(')
			error(SYNTAX);
		rp = p->vargs;
		for(cur_arg = args, i=0 ;; cur_arg++, rp++){
			rep = *rp;
			if(rep->vtype == SVAL){
				if(rep->flags & IS_FSTRING)
					error(3);
				st = ALLOC_STR( (ival)0);
				st->strval = rep->_dst.str;
				st->strlen = rep->_dst.len;
				RESERVE_SPACE(st, (ival)rep->_dst.len);
				cur_arg->ostr = st;
				cur_arg->nstr = stringeval();
			}
			else {
				cur_arg->ovr = rep->_dval; /* save values */
				eval();
				putin(&cur_arg->nvr,
						(int) (rep->vtype & NVALMASK));
			}
			if(++i >= p->narg)
				break;
			if( getch() != ',' )
				error(SYNTAX);
		}
		if( getch() != ')' )
			error(SYNTAX);
					      /* got arguments in nvrs[] */
					      /* put in new values */

		rp = p->vargs;
		for(cur_arg = args, i=0; i < p->narg; i++, cur_arg++, rp++){
			rep = *rp;
			if(rep->vtype == SVAL)
				stringassign(&rep->_dst, rep, cur_arg->nstr, 1);
			else
				rep->_dval = cur_arg->nvr;
		}
	}
	if(p->mline != IS_FN){
		if(p->mline != ctype)
			error(56);
		if(ctype == IS_MPR)
			check();
		if(p->ncall >= MAX_FCALLS)
			error(44);
		fp = mmalloc((ival)(sizeof(struct forst) +
		    sizeof(struct JMPBUF)));
		fp->fnJMP = (struct JMPBUF *)(fp + 1);
		if((fp->prev = estack) != 0)
			fp->prev->next = fp;
		else
			bstack = fp;
		fp->next = 0;
		estack = fp;
		if(p->mline == IS_MFN){
			if(vty == RVAL)
				fp->fnval.f = ZERO;
			else if(vty == SVAL){
				fp->fnsval.str = 0;
				fp->fnsval.len = 0;
			}
			else
				fp->fnval.i = 0;
		}
		fp->fnvar = ep;
		fp->fnLOCAL = 0;	/* by default there is no hash table */
		fp->stolin = stocurlin;
		fp->pt = point;
		fp->elses = elsecount;
		fp->fortyp = FNTYP;	/* get the right type */
		fp->fnSBEG = str_used;
		fp->fnSEND = str_uend;
		str_used = str_uend = 0;
		stocurlin = p->mpnt;
		point = stocurlin->lin;
		elsecount = 0;
		p->ncall++;
		if(setjmp(fp->fnenv) != NORM_RESET)
			execute();
		/*
		 * get the right values for local vars
		 * setjmp does not save register vars
		 */
		for(fp = estack ; fp ; fp = fp->prev)
			if(fp->fortyp == FNTYP)
				break;
		if(!fp)	/* fire door to stop improper stacking */
			reset();
		ep = fp->fnvar;
		p = ep->_deffn;
		/*
		 * recover all environment
		 */
		stocurlin = fp->stolin;
		point = fp->pt;
		elsecount = fp->elses;
		if(p->mline == IS_MFN){
			if(vty == SVAL){
				retst->strval = fp->fnsval.str;
				retst->strlen = fp->fnsval.len;
				RESERVE_SPACE(retst, (ival)fp->fnsval.len);
			}
			else {
				res = fp->fnval;
				vartype = vty;
			}
		}

		recov_parms(p->vargs, p->narg, args, 0);
		if( (estack = fp->prev) == 0)
			bstack = 0;
		else
			fp->prev->next = 0;
		clr_stack(fp);	/* WARNING - also recovers any local vars */
		return;
	}
	if(++fnlock >= MAX_FCALLS)
		error(44);
	spoint=point;
	point=p->exp;
	if(vty == SVAL){
		/*
		 * this is horrible. We must recover this string
		 */
		st = stringeval();
		COPY_OVER_STR(retst, st);
		FREE_STR(st);
	}
	else
		eval();
	if(fnlock > 0)
		fnlock--;
	recov_parms(p->vargs, p->narg, args, 1);
	if(getch())
		error(SYNTAX);
	point= spoint;
	if(vty != SVAL && vartype != vty){
		if(vartype != RVAL)
			cvt(&res);
		else if(conv(&res))
			error(INTOVER);
		vartype = vty;
	}
}

static	void
recov_parms(arp, nargs, args, tofree)
struct	entry	**arp;
int	nargs;
union	ffn_vars *args;
int	tofree;
{
	int    i;
	union	ffn_vars *cur_arg;
	struct	entry	**rp, *rep;
	STR	ost = 0;

	for(rp = arp, cur_arg = args, i=0; i < nargs; i++, cur_arg++,rp++){
		rep = *rp;
		if(rep->vtype == SVAL){
			stringassign(&rep->_dst, rep, cur_arg->ostr, 1);
			if(ost == 0)
				ost = cur_arg->ostr;
		}
		else
			rep->_dval = cur_arg->ovr;
	}
	if(ost && tofree)
		FREE_STR(ost);
}

void
drop_fns()
{
	forstp	fp, nfp = 0;
	struct entry	*ep;

	for(fp = bstack ; fp ; fp = nfp){
		nfp = fp->next;
		if(fp->fortyp == FNTYP){
			ep = fp->fnvar;
			ep->_deffn->ncall--;
			if(ep->vtype == SVAL && ep->_deffn->mline == IS_MFN){
				if(fp->fnsval.str != 0){
					mfree( (MEMP)fp->fnsval.str);
					fp->fnsval.str = 0;
				}
			}
			if(fp->next)
				fp->next->prev = fp->prev;
			else
				estack = fp->prev;
			if(fp->prev)
				fp->prev->next = fp->next;
			else
				bstack = fp->next;
			if(fp->fnLOCAL)
				recover_vars(fp, 0);
			if(str_used)
				FREE_STR(str_used);
			str_used = fp->fnSBEG;
			str_uend = fp->fnSEND;
			mfree( (MEMP)fp);
		}
	}
}

int
fnend()
{
	forstp	fp;

	check();
	for(fp = estack ; fp ; fp = fp->prev)
		if(fp->fortyp == FNTYP)
			break;
	if(!fp)
		error(51);
	longjmp(fp->fnenv, NORM_RESET);
	normret;
}

int
fncmd()
{
	struct	entry	*ep;
	forstp	fp;
	STR	st;

	if(!isalpha(*point))
		error(SYNTAX);
	ep = getnm(ISFUNC, 0);
	if(!ep)
		error(UNDEFFN);
	if(ep->_deffn->mline == IS_FN)
		error(UNDEFFN);
	if(ep->_deffn->mline == IS_MPR){
/*
		check();
*/
		ffn(ep, (STR)0);
		normret;
	}
	if(getch() != '=')
		error(SYNTAX);
	for(fp = estack ; fp ; fp = fp->prev)
		if(fp->fortyp == FNTYP)
			break;
	if(!fp || fp->fnvar != ep)
		error(UNDEFFN);
	if(vartype == SVAL){
		st = stringeval();
		check();
		stringassign(&fp->fnsval, ep, st, 0);
	}
	else {
		eval();
		check();
		putin(&fp->fnval, (int)(ep->vtype & NVALMASK));
	}
	normret;
}

void
recover_vars(sptr, doit)
forstp	sptr;
int	doit;
{
	loc_sav_t *ls;
	struct	loc_sav_e *lse;
	loc_sav_t *nls;

	ls = sptr->fnLOCAL;
	sptr->fnLOCAL = 0;
	while(ls != 0){
		nls = ls->next;
		lse = ls->arg;
		if(!doit){
			for(; ls->narg ; ls->narg--, lse++)
				if(lse->lentry)
					free_entry(lse->lentry);
		}
		else {
			for(; ls->narg ; ls->narg--, lse++){
				drop_val(lse->hentry, 0);
				if(lse->lentry)
					add_entry(lse->lentry);
				free_entry(lse->hentry);
			}
		}
		mfree( (MEMP)ls);
		ls = nls;
	}
}

/* int() - return the greatest integer less than x */

void
intf()
{
#ifndef SOFTFP
	extern	double  floor();

	eval();
	if(vartype != RVAL)
		return;
	res.f = floor(res.f);
	if(!conv(&res))
		vartype= IVAL;
#else
	value   temp;
	static  double  ONE = 1.0;

	eval();
	if(vartype != RVAL)             /* conv and integ truncate not round */
		return;
#ifndef UNPORTABLE
	if(res.f >= ZERO){
#else
	if(res.i>=0){                   /* positive easy */
#endif
		if(!conv(&res))
			vartype= IVAL;
		else integ(&res);
		return;
	}
	temp = res;
	integ(&res);
	if(cmp(&res,&temp)){            /* not got an integer subtract one */
		res = *((value *)&ONE);
		fsub(&temp,&res);
		integ(&res);
	}
	if(!conv(&res))
		vartype= IVAL;
#endif                                  /* not floating point */
}

void
bfixf()
{
	extern	double  floor();

	eval();
	if(vartype != RVAL)
		return;

	if(res.f < ZERO)
		res.f = -floor(-res.f);
	else
		res.f = floor(res.f);
}

static	char	*
real_memory()
{
	itype	l;
	char	*p;
#ifdef	pdp11
	l = evalint();
	p = (char *)l;
#else
#ifdef	BIG_INTS
	l = evalint();
	p = (char *)l;
#else
#ifdef	MSDOS
	l = evalint();
	p = (char *)l;
#else
	long   ll;	/* really only for a vax */

	evalreal();
	if(res.f > 0x7fff000 || res.f < 0)      /* check this */
		error(FUNCT);
	ll = res.f;
	p = (char *)ll;
#endif
#endif
#endif
	return(p);
}

static	jmp_buf	pksig_catch;

static	SIGFUNC
pksig_catchf(sig)
int	sig;
{

	longjmp(pksig_catch, sig);
}

static	int
pkpok(loc, val, mode)
char	*loc;
itype	val;
int	mode;
{
	int	rval = -1;
	SIGFUNC	(*old_bus)(int), (*old_seg)(int);

	old_bus = signal(SIGBUS, pksig_catchf);
	old_seg = signal(SIGSEGV, pksig_catchf);

	switch(setjmp(pksig_catch)){
	case 0:
		if(mode)
			rval = (int)UC(*loc);
		else
			*loc = (char) val;
		break;
	case SIGBUS:
		break;
	case SIGSEGV:
		break;
	default:
		break;
	}
	VOID signal(SIGBUS, old_bus);
	VOID signal(SIGSEGV, old_seg);
	return(rval);
}

void
peekf()
{
	char   *p;

	p = real_memory();
	res.i = (itype)pkpok(p, (itype)0, 1);
	vartype = IVAL;
}

int
poke()                		/* sp = approx position of stack */
{                                       /* can give bus errors */
	char   *p;
	itype	i;

	p = real_memory();
	if(getch() != ',')
		error(SYNTAX);
	i = evalint();
	check();
	if(i<0 || i > 255)
		error(FUNCT);
	VOID pkpok(p, i, 0);
	normret;
}


static void
setdrg(tofrom)
int	tofrom;
{
#ifndef	SOFTFP
	static	const	double	grad_to_rad = PI_VALUE/200;
	static	const	double	deg_to_rad = PI_VALUE/180;

	if(drg_opt == OPT_RAD)
		return;
	if(tofrom){
		/* for sin and cos. and tan */
		if(drg_opt == OPT_GRAD)
			res.f *= grad_to_rad;
		else
			res.f *= deg_to_rad;
	}
	else {	/* for atan */
		if(drg_opt == OPT_GRAD)
			res.f /= grad_to_rad;
		else
			res.f /= deg_to_rad;
	}
#endif
}

void
bsinf()
{
	evalreal();
	setdrg(1);
#ifndef SOFTFP
	res.f = sin(res.f);
#else
	sin(&res);
#endif
}

void
bcosf()
{
	evalreal();
	setdrg(1);
#ifndef SOFTFP
	res.f = cos(res.f);
#else
	cos(&res);
#endif
}

void
btanf()
{
	double	x;

	evalreal();
	setdrg(1);
#ifndef	SOFTFP
	x = cos(res.f);
	if(x == ZERO){
		c_error(25);
		res.f = BIG;
	}
	else
		res.f = sin(res.f) / x;
#else
	tan(&res);
#endif
}

void
batanf()
{
	evalreal();
#ifndef SOFTFP
	res.f = atan(res.f);
#else
	atan(&res);
#endif
	setdrg(0);
}

void
basinf()
{
	evalreal();
#ifndef	SOFTFP
	res.f = asin(res.f);
#endif
	setdrg(0);
}

void
bacosf()
{
	evalreal();
#ifndef	SOFTFP
	res.f = acos(res.f);
#endif
	setdrg(0);
}
/*
 * hyperbolic functions
 */
#ifndef	SOFTFP
static	int
hyp_sign(xp)
double	*xp;
{
	int	r;

	if(*xp < ZERO){
		r = -1;
		*xp = - *xp;
	}
	else
		r = 1;
	return(r);
}
#endif

static	void
hyper_sc(sin_cos_tan)
int	sin_cos_tan;
{
	double	x, y;
	int	sign;

	evalreal();

#ifndef	SOFTFP
	sign = hyp_sign(&res.f);
	if(res.f >= 20.0){
		switch(sin_cos_tan){
		case 2:	/*TANH*/
			res.f = (sign > 0) ? ONE : -ONE;
			break;
		case 1: /*COSH*/
		case 0: /*SINH*/
			/* there is a discontinuity here from a
			 * number <= logmaxval to > logmaxval.
			 * can solve this problem if we do
			 * exp(res.f - ln2) between logmaxval and
			 * logmaxval + ln2
			 */
			if(res.f > logmaxval){
				if(res.f > logmaxval + logof2){
					c_error(34);
					res.f = BIG;
				}
				else
					res.f = exp(res.f - logof2);
			}
			else
				res.f = exp(res.f) / TWO;
			if(sin_cos_tan == 0 && sign < 0)
				res.f = -res.f;
			break;
		}
		return;
	}
	x = exp(res.f);
	y = ONE / x;
	switch(sin_cos_tan){
	case 2:	/*TANH*/
		res.f = (x - y) / (x + y);
		break;
	case 1: /*COSH*/
		res.f = (x + y) / TWO;
		break;
	case 0: /*SINH*/
		res.f = (x - y) / TWO;
		break;
	}
	if(sin_cos_tan != 1 && sign < 0)
		res.f = -res.f;
#endif
}

static	void
ahyper_sc(sin_cos_tan)
int	sin_cos_tan;
{
	double	x;
	int	neg;

	evalreal();

#ifndef	SOFTFP
	x = res.f;
	neg = hyp_sign(&x);
	switch(sin_cos_tan){
	case 2:	/* TANH */
		if(x >= ONE)
			goto setnan;
		res.f = log(ONE + (res.f + res.f) / ( ONE - res.f)) / TWO;
		break;
	case 1:	/* COSH */
		if(res.f < ONE)
			goto setnan;
		if(x < INSIG)
			res.f = log(x + sqrt(x * x - ONE));
		else 
			res.f = log(x) + logof2;
		break;
	case 0: /* SINH */
		if(x < INSIG)
			res.f = log(x + sqrt(x * x + ONE));
		else
			res.f = log(x) + logof2;
		if(neg < 0)
			res.f = -res.f;
		break;
	}
	return;
setnan:
	c_error(34);
	res.f = (neg > 0) ? BIG : BIGminus;
#endif
}

void
bsinh()
{
	hyper_sc(0);
}

void
bcosh()
{
	hyper_sc(1);
}

void
btanh()
{
	hyper_sc(2);
}

void
basinh()
{
	ahyper_sc(0);
}

void
bacosh()
{
	ahyper_sc(1);
}

void
batanh()
{
	ahyper_sc(2);
}

/*
 * the option command.
 */

int
bopts()
{
	int	c;
	itype	memsiz;

	if( (c = getch()) == OPT_BASE){
		VOID base();
		normret;
	}
	if(c != OFUNC)
		error(SYNTAX);
		
	switch(c = UC(*point++)){
#ifndef	SOFTFP
	case OPT_GRAD:
	case OPT_DEG:
#endif
	case OPT_RAD:
		drg_opt = c;
		break;

	case OPT_MEM:
		memsiz = evalint();
		if(memsiz <= 0)
			memsiz = MAX_MEM_DEFAULT;
		else if(memsiz > MAX_MEM_MAX)
			memsiz = MAX_MEM_MAX;
		break;
	default:
		error(SYNTAX);
		break;
	}
	normret;
}

/*
 * the "system" function, returns the status of the command it executes
 */

void
ssystem()
{
	STR	st;

	st = stringeval();
	NULL_TERMINATE(st);

	flushall();

	res.i = (itype)do_system(st->strval);
	vartype = IVAL;
	FREE_STR(st);
}

/*
 * perform a system call. parameters are taken as is
 */
#define	MAX_SYS_ARGS	6


static	int	sys_error;

void
bsyscall()
{
	int	nargs;
	int	args[MAX_SYS_ARGS];
	itype	scall;
	itype	rval;

	sys_error = 0;
	scall = evalint();

	if(scall < 1 || scall > 10000)
		error(FUNCT);	

	for(nargs = 0 ; nargs < MAX_SYS_ARGS ; nargs++)
		args[nargs] = 0;

	for(nargs = 0; getch() == ',' ; nargs++){
		if(nargs >= MAX_SYS_ARGS)
			error(FUNCT);
		args[nargs] = (int)evalint();
	}
	point--;
	errno = 0;
	rval = syscall(scall, args[0],args[1],args[2],args[3],args[4],args[5]);
	sys_error = errno;
	vartype = IVAL;
	res.i = rval;
}

void
bsyserr()
{
	res.i = (ival)sys_error;
	vartype = IVAL;
}

static	void
bminmax(is_min)
int	is_min;
{
	value	curval;
	char	vtyp;
	int	rc;

	eval();
	curval = res;
	vtyp = vartype;
	if(getch() != ',')
		error(SYNTAX);
	do {
		eval();
		if(vtyp != vartype){
			if(vartype != RVAL)
				cvt(&res);
			else
				cvt(&curval);
			vartype = RVAL;
			vtyp = RVAL;
		}
		rc = cmp(&res, &curval);
		if( (rc < 0 && is_min) || (rc > 0 && !is_min)){
			curval = res;
			vtyp = vartype;
		}
	}while(getch() == ',');
	res = curval;
	vartype = vtyp;
	point--;
}

void
bmax()
{
	bminmax(0);
}

void
bmin()
{
	bminmax(1);
}

void
bcreal()
{
	evalreal();
}

void
bcint()
{
	ival	ret;

	ret = evalint();
	res.i = ret;
	vartype = IVAL;
}

/*
 * matrix commands.
 */
static	void	chk_dims(struct entry *, struct entry *);
static	int	mat_len(struct entry *);
static	void	matmuli(struct entry *, struct entry *, struct entry *,
					ival, ival, ival);
static	void	matmulr(struct entry *, struct entry *, struct entry *,
					ival, ival, ival);

int
bmat()
{
	struct	entry	*lhep;
	struct	entry	*arg1;
	struct	entry	*arg2;
	struct	entry	*newent;
	int	c;
	int	rcnt;
	valp	vp, xp, zp;
	ival	*vpp, *xpp, *zpp;
	char	vty;
	ival	da1, da2, db2, db1;

	c = getch();
	switch(c){
	case INPUT:
		return(matinput());
	case READ:
		do {
			lhep = getmat(0);
			matread((MEMP)lhep->_darr, (int)vartype, mat_len(lhep));
		} while(getch() == ',');
		point--;
		normret;
	case PRINT:
		return(matprint());
	default:
		point--;
		break;
	}
	lhep = getmat(1);
	newent = newentry;
	vty = vartype;
	if(getch() != '=')
		error(4);

	c = getch();
	switch(c){
	default:
		point--;
		break;
	}
	arg1 = getmat(0);

	c = getch();
	if(istermin(c)){
		point--;
		if(lhep == 0){
			lhep = newent;
			vartype = vty;
			def_darr(lhep, arg1->_dims[0],
				(arg1->dimens > 1) ? arg1->_dims[1] : 0);
			newentry = 0;
		}
		else
			chk_dims(lhep, arg1);
		VOID strmov(lhep->_darr, arg1->_darr,
				(ival)(mat_len(lhep) * TYP_SIZ(lhep->vtype)));
		normret;
	}
	switch(c){
	case '.':
		arg2 = getmat(0);
		if(arg1->dimens > 1){
			da1 = arg1->_dims[1];
			da2 = arg1->_dims[0];
		}
		else {
			da1 = arg1->_dims[0];
			da2 = 1;
		}
		if(arg2->dimens > 1){
			db1 = arg2->_dims[1];
			db2 = arg2->_dims[0];
		}
		else {
			db1 = arg2->_dims[0];
			db2 = 1;
		}
		if(da2 != db1)
			error(58);
		if(lhep == 0){
			lhep = newent;
			vartype = vty;
			def_darr(lhep, da1, (db2 > 1) ? db2 : 0);
			newentry = 0;
		}
		else {
			/*
			 * result cannot be one of the two parameters
			 */
			if(lhep == arg1 || lhep == arg2)
				error(58);
			if(lhep->vtype != arg1->vtype || lhep->_dims[0] != da1)
				error(58);
			if(db2 > 1){
				if(lhep->dimens <= 1 || lhep->_dims[1] != db2)
					error(58);
			}
			else {
				if(lhep->dimens > 1 && lhep->_dims[1] != 1)
					error(58);
			}
		}
		/*
		 * now do matrix multiplication
		 */
		if(vartype == RVAL)
			matmulr(lhep, arg1, arg2, da1, da2, db2);
		else
			matmuli(lhep, arg1, arg2, da1, da2, db2);
		break;
	case '+':
	case '-':
		arg2 = getmat(0);
		chk_dims(arg1, arg2);
		if(lhep == 0){
			lhep = newent;
			vartype = vty;
			def_darr(lhep, arg1->_dims[0],
				(arg1->dimens > 1) ? arg1->_dims[1] : 0);
			newentry = 0;
		}
		else
			chk_dims(lhep, arg1);
		rcnt = mat_len(lhep);
		xp = (valp)(MEMP)arg1->_darr;
		zp = (valp)(MEMP)arg2->_darr;
		vp = (valp)(MEMP)lhep->_darr;

		if(vartype == RVAL){
			if(c == '+'){
				for(; rcnt ; rcnt--){
					vp->f = xp->f + zp->f;
					vp++;
					xp++;
					zp++;
				}
			}
			else for(; rcnt ; rcnt--){
				vp->f = xp->f - zp->f;
				vp++;
				xp++;
				zp++;
			}
		}
		else {
			xpp = &xp->i;
			vpp = &vp->i;
			zpp = &zp->i;
			if(c == '+'){
				for(; rcnt ; rcnt--){
					long	l = *xpp + *zpp;
					if(IS_OVER(*zpp, *xpp, l))
						error(INTOVER);
					*vpp = l;
					vpp++;
					xpp++;
					zpp++;
				}
			}
			else {
				for(; rcnt ; rcnt--){
					long	l = *xpp - *zpp;
					if(IS_OVER(*zpp, *xpp, l))
						error(INTOVER);
					*vpp = l;
					vpp++;
					xpp++;
					zpp++;
				}
			}
		}
		break;
	case '*':
		if(lhep == 0){
			lhep = newent;
			vartype = vty;
			def_darr(lhep, arg1->_dims[0],
				(arg1->dimens > 1) ? arg1->_dims[1] : 0);
			newentry = 0;
		}
		else
			chk_dims(lhep, arg1);
		eval();
		if(vartype != lhep->vtype){
			if(vartype != RVAL)
				cvt(&res);
			else if(conv(&res))
				error(INTOVER);
			vartype = lhep->vtype;
		}

		rcnt = mat_len(lhep);
		xp = (valp)(MEMP)arg1->_darr;
		vp = (valp)(MEMP)lhep->_darr;

		if(vartype == RVAL){
			for(; rcnt ; rcnt--){
				vp->f = xp->f * res.f;
				vp++;
				xp++;
			}
		}
		else {
			xpp = &xp->i;
			vpp = &vp->i;
			for(; rcnt ; rcnt--){
#ifdef	BIG_INTS
				*vpp = mmult_ply(*xpp, res.i, INTOVER);
#else
				long	l = *xpp * res.i;
				if(IS_OVER(res.i, *xxp, l))
					error(INTOVER);
				*vpp = l;
#endif
				vpp++;
				xpp++;
			}
		}
		break;
	default:
		error(SYNTAX);
	}
	normret;
}

#if 0
#define	MAT_LEN(lhep, cnt)	\
	do { \
		(cnt) = (lhep)->_dims[0]; \
		if((lhep)->dimens > 1) \
			(cnt) *= (lhep)->_dims[1]; \
	} while(0)
#define	mat_len(lhep) \
	(((lhep)->dimens > 1 ) ? ((lhep)->_dims[0] * (lhep)->_dims[1]) : \
							(lhep)->_dims[0])
#else
static	int
mat_len(lhep)
struct	entry	*lhep;
{
	int	rcnt;

	rcnt = lhep->_dims[0];
	if(lhep->dimens > 1)
		rcnt *= lhep->_dims[1];
	return(rcnt);
}
#endif

static void
chk_dims(lhep, arg1)
struct	entry	*lhep, *arg1;
{
	if(lhep->vtype == arg1->vtype && lhep->dimens == arg1->dimens &&
	   lhep->_dims[0] == arg1->_dims[0] && (lhep->dimens == 1 ||
					lhep->_dims[1] == arg1->_dims[1]))
		return;
	error(58);
}

/*
 * matrix multiplication (finally!!)
 */
static void
matmulr(lhep, arg1, arg2, da1, da2, db2)
struct	entry *lhep, *arg1, *arg2;
ival	da1, da2, db2;
{
	ival	i,j,k;
	valp	vp, vpp, zp, zpp, xp, xpp;
	double	x;

	vpp = (valp)(MEMP)arg1->_darr;
	zpp = (valp)(MEMP)lhep->_darr;
	for(i =  0 ; i < da1 ; i++){
		/*
		 * VP = arg1, ZP = lhep
		 * vp = arg1->[i];
		 * zp = lhep->[i];
		 * xp = arg2->[?,j]
		 */
		zp = zpp;
		xpp = (valp)(MEMP)arg2->_darr;
		for(j = 0 ; j < db2 ; j++){
			x = ZERO;
			vp = vpp;
			xp = xpp;
			for(k = 0 ; k < da2 ; k++){
				x = x + vp->f * xp->f;
				xp += db2;
				vp++;
			}
			zp->f = x;
			zp++;
			xpp++;
		}
		vpp += da2;
		zpp += db2;
	}
}

static void
matmuli(lhep, arg1, arg2, da1, da2, db2)
struct	entry *lhep, *arg1, *arg2;
ival	da1, da2, db2;
{
	ival	i,j,k;
	ival	*vp, *vpp, *zp, *zpp, *xp, *xpp;
	long	x, l, ll;

	vpp = (ival *)(MEMP)arg1->_darr;
	zpp = (ival *)(MEMP)lhep->_darr;
	for(i =  0 ; i < da1 ; i++){
		/*
		 * VP = arg1, ZP = lhep
		 * vp = arg1->[i];
		 * zp = lhep->[i];
		 * xp = arg2->[?,j]
		 */
		zp = zpp;
		xpp = (ival *)(MEMP)arg2->_darr;
		for(j = 0 ; j < db2 ; j++){
			x = 0;
			vp = vpp;
			xp = xpp;
			for(k = 0 ; k < da2 ; k++){
#ifdef	BIG_INTS
				l = mmult_ply(*xp, *vp, INTOVER);
#else
				l = *vp * *xp;
				if(IS_OVER(*vp, *xp, l))
					error(INTOVER);
#endif
				
				ll = x + l;
				if(IS_OVER(x, l, ll))
					error(INTOVER);
				x = ll;
				xp += db2;
				vp++;
			}
			*zp = x;
			zp++;
			xpp++;
		}
		vpp += da2;
		zpp += db2;
	}
}
