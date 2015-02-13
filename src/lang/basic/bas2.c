/*
 * BASIC by Phil Cockcroft
 */
#include        "bas.h"

/*
 *  This file contains the routines to get a variable from its name
 *  To dimension arrays and assignment to a variable.
 *
 *      A variable name consists of a letter followed by an optional
 *    letter or digit followed by the type specifier.
 *      A type specifier is a '%' for an integer a '$' for a string
 *    or is absent if the variable is a real ( Default ).
 *      An integer variable also has the top bit of its second letter
 *    set this is used to distinguish between real and integer variables.
 *      A variable name can be optionally followed by a subscript
 *    turning the variable into a subscripted variable.
 *    A subscript is specified by a list of indexes in square brackets
 *    e.g.  [1,2,3] , a maximum of three subscripts may be used.
 *    All arrays must be specified before use.
 *
 *      The variable to be accessed has its name in the array nm[],
 *    and its type in the variable 'vartype'.
 *
 *      'vartype' is very important as it is used all over the place
 *
 *      The value in 'vartype' can have the following values:-
 *              0:      real variable (Default ).
 *              1:      integer variable.
 *              2:      string variable.
 *
 */

#define LBRACK  '('
#define RBRACK  ')'

static	MEMP	getarray(struct entry *);
static	void	dim_one(void);
static	void	bdeftype(int);
static	int	nam_read(CHAR *, int *);
static	struct	entry	*new_entry(CHAR *, int, int, struct entry *, int);

static const union entry_vals entry_zero;

static	int
nam_read(nam, lp)
CHAR	*nam;
int	*lp;
{
	int	c;
	CHAR	*p = nam;
	int	l;

	c = getch();
	if(!isalpha(c))
		error(VARREQD);
	vartype = (char)tcharmap[c - 'A'];
	for(*p++ = (CHAR)(l = c), c = UC(*point); isalnum(c) || c == '_';
	    c = UC(*++point)){
		l += c;
		*p++ = (CHAR)c;
	}
	*p = 0;
	if(c==D_STR){
		point++;
		vartype = SVAL;
	}
	else if(c==D_INT){
		point++;
		vartype = IVAL;
	}
	else if(c==D_FLT){
		point++;
		vartype = RVAL;
	}
	*lp = l;
	return(p - nam);
}

static	struct	entry	*
new_entry(nam, namlen, l, np, vtype)
CHAR	*nam;
int	namlen, l;
struct	entry	*np;
int	vtype;
{
	struct	entry	*ep;

	ep = (struct entry *)mmalloc((ival)(sizeof(struct entry)+namlen));
	ep->link = 0;
	if(!np)
		hshtab.hasht[MKhash(l)] = ep;
	else
		np->link = ep;
	VOID strmov(ep->_name, nam, namlen+1);
	ep->ln_hash = l;
	ep->namlen = (char)namlen;
	ep->vtype = (char)vtype;
	ep->flags = 0;
	ep->dimens = 0;
	ep->d = entry_zero;
	return(ep);
}

/*
 * getnm will return with nm[] and vartype set appropriately but without
 * any regard for subscript parameters. Called by dimensio() only.
 */

struct	entry	*
getnm(isfunc, mknew)
int	isfunc;
int	mknew;
{
	struct entry   *ep;
	CHAR   *p,*q;
	struct entry   *np;
	int    l;
	char	vtype;
	int	namlen;	/* it would be better if this was a char... */
	int	lbrak;
	CHAR	nam[MAXLIN];

	namlen = nam_read(nam, &l);
	vtype = vartype | isfunc;
	lbrak = (*point != LBRACK);
	for(np = 0,ep=hshtab.hasht[MKhash(l)]; ep ; np = ep,ep=ep->link)
		if(l == ep->ln_hash && namlen==ep->namlen && vtype ==ep->vtype){
			if(!isfunc && lbrak != !ep->dimens)
				continue;
			for(p = ep->_name,q = nam ; *q == *p++ ; )
				if(!*q++)
					return(ep);
		}

	if(mknew)
		newentry = new_entry(nam, namlen, l, np, UNK_VAL);
	return(0);
}

/*
 *      getname() will return a pointer to a variable with vartype
 *    set to the correct type. If the variable is subscripted getarray
 *    is called and the subscripts are evaluated and depending upon
 *    the type of variable the index into that array is returned.
 *      Any simple variable that is not already declared is defined
 *    and has a value of 0 or null (for strings) assigned to it.
 *      In all instances a valid pointer is returned.
 */

#define	FNTYPOK(ep, isfunc) 	(((ep)->vtype & ISFUNC) && \
		((isfunc & IS_MPR) != 0) == ((ep)->_deffn->mline == IS_MPR))

MEMP
getname(isfunc)
int	isfunc;
{
	struct entry   *ep;
	CHAR   *p,*q;
	struct  entry   *np = 0;
	int	l;
	int	namlen;
	CHAR	nam[MAXLIN];
	char	xisfunc = (char)~(isfunc & ISFUNC);
	struct	entry	*xap = 0;


	namlen = nam_read(nam, &l);
	ep = hshtab.hasht[MKhash(l)];
	if(*point==LBRACK){
		for(; ep ; np = ep, ep = ep->link)
			if(l == ep->ln_hash && namlen == ep->namlen &&
					vartype == (char)(ep->vtype & xisfunc))
				for(p = ep->_name,q = nam ; *q == *p++ ; )
					if(!*q++){
						if(isfunc){
							if(FNTYPOK(ep, isfunc)){
								curentry = ep;
								return((MEMP)0);
							}
							if(ep->dimens)
								xap = ep;
						}
						else if(ep->dimens)
							return(getarray(ep));
						break;
					}
		if( (ep = xap) == 0){
			/*
			 * get here if no defined array.
			 * auto define an array of 10 elements
			 */
			ep = new_entry(nam, namlen, l, np, UNK_VAL);
			curentry = ep;
			def_darr(ep, DEF_AR_SIZ, 0);
		}
		return(getarray(ep));
	}
	for(; ep ; np = ep , ep = ep->link)
		if(l == ep->ln_hash && namlen == ep->namlen && !ep->dimens &&
					vartype == (char)(ep->vtype & xisfunc))
			for(p = ep->_name,q = nam ; *q == *p++ ; )
				if(!*q++){
					curentry = ep;
					if(isfunc){
						if(FNTYPOK(ep, isfunc))
							return( (MEMP)0);
						if((ep->vtype & ISFUNC) == 0)
							xap = ep;
						break;
					}
					if(vartype == SVAL)
						return( (MEMP)&ep->_dst);
					else
						return( (MEMP)&ep->_dval);
				}
	if( (ep = xap) == 0)
		ep = new_entry(nam, namlen, l, np, (int)vartype);
	curentry = ep;

/*
	if(vartype == SVAL){
		ep->_dstr = 0;
		ep->_dslen = 0;
		return( (MEMP) &ep->_dst);
	}
	else if(vartype == IVAL)
		ep->_dval.i = 0;
	else
		ep->_dval.f = ZERO;
*/
	if(vartype == SVAL)
		return( (MEMP) &ep->_dst);
	return( (MEMP) &ep->_dval);
}

void
def_darr(ep, siz1, siz2)
struct	entry	*ep;
int	siz1, siz2;
{
	ival	l;

	l = TYP_SIZ(vartype) * siz1;
	if(siz2)
		l *= siz2;
	ep->_darr = (memp)mmalloc( (ival)(l +
				(siz2 ? (sizeof(ival) * 2) : sizeof(ival))));
	/*LINTED*/
	ep->_dims = (ival *)(ep->_darr + l);
	ep->_dims[0] = siz1;
	if(siz2){
		ep->_dims[1] = siz2;
		ep->dimens = 2;	/* double dimension array */
	}
	else
		ep->dimens = 1;	/* single dimension array */
	clr_mem( (memp)ep->_darr, (ival)l);
	ep->vtype = vartype;
}

struct entry	*
getmat(mk)
int	mk;
{
	struct entry   *ep;
	CHAR   *p,*q;
	struct  entry   *np = 0;
	int	l;
	int	namlen;
	CHAR	nam[MAXLIN];

	namlen = nam_read(nam, &l);
	if(vartype == SVAL)
		error(19);

	ep = hshtab.hasht[MKhash(l)];
	for(; ep ; np = ep, ep = ep->link)
		if(l == ep->ln_hash && namlen == ep->namlen && ep->dimens &&
							vartype == ep->vtype)
			for(p = ep->_name,q = nam ; *q == *p++ ; )
				if(!*q++){
					if(ep->dimens > 2)
						error(59);
					return(ep);
				}
	/*
	 * get here if no defined array.
	 * auto define an array of 10 elements
	 */
	ep = new_entry(nam, namlen, l, np, UNK_VAL);
	if(mk){
		newentry = ep;
		return(0);
	}
	def_darr(ep, DEF_AR_SIZ, 0);
	return(ep);
}

/*
 *      getarray() evaluates the subscripts of an array and the tries
 *    to access it. getarray() returns different things dependent
 *    on the type of variable. For an integer or real then the pointer to
 *    the element of the array is returned.
 *      For a string array element then the nm[] array is filled out
 *    with a unique number and then getstring() is called to access it.
 *      The variable hash (in the strarr structure ) is used as the
 *    offset to the next array if the array is real or integer, but
 *    is the base for the unique number to access the string structure.
 *
 *      This is a piece of 'hairy' codeing.
 */

static	MEMP
getarray(ep)
struct	entry	*ep;
{
	itype	l;
	itype   *m;
	int     c;
	int     i=1;
	ival   j=0;

	point++;
	m = ep->_dims + ep->dimens - 1;
	i=1;
	do{
		l = evalint() - baseval;
		if(l >= *m || l < 0)
			error(17);
		j= l + j * *m;
		if( (c = getch()) != ',')
			break;
		m--,i++;
	} while(i <= ep->dimens);
	if(i != ep->dimens || c != RBRACK)
		error(16);
	vartype = ep->vtype;
	curentry = ep;
	j *= TYP_SIZ(ep->vtype);
	return( (MEMP)(ep->_darr + j));
}

/*
 *      dimensio() executes the dim command. It sets up the strarr structure
 *    as needed. If the array is a string array then only the structure
 *    is filled in. This means that elements of a string array do not have
 *    storage allocated until assigned to. If the array is real or integer
 *    then the array is allocated space as well as the strarr array.
 *      This is why the hash element is needed so as to be able to access
 *    the next array.
 */

int
dimensio()
{
	struct	entry	*ep;

	do {
		ep = getnm(0, 1);
		if(ep != 0)
			error(20);
		if(*point++ != LBRACK)
			error(SYNTAX);
		dim_one();
	}while(getch() == ',');
	point--;
	normret;
}

static	void
dim_one()
{
	itype   dims[MAXDIMS];
	long    j;
	int     c;
	char    vty;
	int     i;
	itype   *r;
	struct	entry	*ep;
	int	ii;

	ep = newentry;
	vty = vartype;            /* save copy of type of array */

	for(i = 0, j = 1, r = dims; i < MAXDIMS; i++, r++){
		if( (*r = evalint()) <= 0)
			error(17);
		if(!baseval)
			++*r;
#ifndef pdp11
#ifdef	BIG_INTS
		j =  (long)mmult_ply( (itype)j, *r, 17);
		if(j > MAX_ARRAY)
			error(17);
#else
		if((j *= *r) <= 0 || j > 32767)
			error(17);
#endif
#else
		if( (j=dimmul( (int)j , *r)) <= 0)
			error(17);
#endif
		if((c=getch())!=',')
			break;
	}
	if(i == MAXDIMS || c!=RBRACK)
		error(16);
	i++;
	j *= TYP_SIZ(vty);
	if(!mtestalloc( (ival)(j + (i * sizeof(ival)))))
		error(24);
	ep->_darr = (memp)mmalloc((ival)(j + (i * sizeof(ival))));
	/*LINTED*/
	ep->_dims = (ival *)(ep->_darr + j);
	ep->dimens = (char)i;
	ep->vtype = vty;
	for(ii = 0, i-- ; i >= 0 ; i--, ii++)
		ep->_dims[ii] = dims[i];
	clr_mem( (memp)ep->_darr, (ival)j);
	newentry = 0;
}

void
drop_val(dap, tofree)
struct	entry	*dap;
int	tofree;
{
	struct	entry	*ep, *np;
	int	i = MKhash(dap->ln_hash);

	for(np = 0, ep = hshtab.hasht[i]; ep ; np = ep, ep = ep->link)
		if(ep == dap){
			if(!np)
				hshtab.hasht[i] = dap->link;
			else
				np->link = dap->link;
			if(tofree)
				mfree( (MEMP)dap);
			break;
		}
}

int
berase()
{
	struct	entry	*ep;

	do {
		ep = getnm(0, 0);
		if(*point == LBRACK){
			point++;
			if(getch() != RBRACK)
				error(SYNTAX);
		}
		if(ep != 0){
			drop_val(ep, 0);
			free_entry(ep);
		}
	} while(getch() == ',');
	point--;
	normret;
}

/*
 *      Assign() is called if there is no keyword at the start of a
 *    statement ( Default assignment statement ) and by let.
 *    it just calls the relevent evaluation routine and leaves all the
 *    hard work to stringassign() and putin() to actualy assign the variables.
 */

typedef	struct	{
	valp	val;
	struct entry *eptr;
} as_part;

void
assign(isfunc)
int	isfunc;
{
	as_part *ap;
	int	npart;
	valp	p;
	char   vty;
	int    c;
	STR	st, fstr;
	as_part	aparts[MAXLIN/2];

	p= (valp)getname(isfunc);
	if(p == 0){
		ffn(curentry, (STR)0);
		return;
	}
	vty = vartype;
	ap = aparts;
	ap->val = p;
	ap->eptr = curentry;
	npart = 1;
	while( (c = getch()) == ','){
		npart++;
		ap++;
		ap->val = (valp)getname(0);
		ap->eptr = curentry;
		if(vartype != vty)
			error(4);
	}
	if(c != '=')
		error(4);
	if(vty == SVAL){
		st = stringeval();
		while(npart > 1){
			/*
			 * must duplicate st and then do a stringassign
			 */
			fstr = ALLOC_STR( (ival)0);
			fstr->strlen = st->strlen;
			fstr->strval = st->strval;
			RESERVE_SPACE(fstr, fstr->strlen);
			
			/*LINTED*/
			stringassign( (stringp)ap->val, ap->eptr, fstr, 0);
			ap--;
			npart--;
		}
		/*LINTED*/
		stringassign( (stringp)ap->val, ap->eptr, st, 0);
		return;
	}
	eval();
	putin(p, (int)vty);
	if(--npart > 0){
		if(vty == RVAL)
			for(; npart ; npart--, ap--)
				*ap->val = *p;
		else {
			for(; npart ; npart--, ap--)
				ap->val->i = p->i;
		}
	}
}

void
bvarptr()
{
	valp	p;
	MEMP	rvl;

	p = (valp)getname(0);
	if(vartype == SVAL)
		rvl = (MEMP)(((stringp)p)->str);
	else if(vartype != RVAL)
		rvl = (MEMP)&p->i;
	else
		rvl = (MEMP)p;
	vartype = IVAL;
	res.i = (ival)rvl;
}
	
int
bdefint()
{
	bdeftype(IVAL);
	normret;
}

int
bdefstr()
{
	bdeftype(SVAL);
	normret;
}

int
bdefdbl()
{
	bdeftype(RVAL);
	normret;
}

#define	set_let(c, val)	(tcharmap[(c) - 'A'] = val)

static	void
bdeftype(vty)
int	vty;
{
	int	c, c1;
	int	first = 1;

	for(;;){
		c = getch();
		if(istermin(c)){
			if(first)
				error(SYNTAX);
			point--;
			break;
		}
		first = 0;
		if(!isalpha(c))
			error(SYNTAX);
		c1 = getch();
		if(c1 == '-'){
			c1 = getch();
			if(!isalpha(c1))
				error(SYNTAX);
			if(c1 - c > 'z' - 'a' || c1 < c)
				error(SYNTAX);
			/*
			 * range set
			 */
			while(c <= c1){
				set_let(c, (CHAR)vty);
				c++;
			}
		}
		else if(isalpha(c1) || istermin(c1)){
			set_let(c, (CHAR)vty);
			/*
			 * single character set
			 */
			point--;
		}
		else if(c1 != ',')
			error(SYNTAX);
	}
}

int
bcommon()
{
	struct	entry	*ep;
	do {
		ep = getnm(0, 1);
		if(!ep){
			ep = newentry;
			if(*point == LBRACK){
				if(*++point != RBRACK)
					error(SYNTAX);
				/*
				 * common arrays must first be defined
				 * using dim. So give an error here.
				 */
				error(19);
			}
			else
				ep->vtype = vartype;
			newentry = 0;
		}
		else {
			if(ep->flags & (IS_LOCAL|IS_FSTRING))
				error(55);
			if(*point == LBRACK){
				if(*(point+1) != RBRACK)
					error(SYNTAX);
				point+=2;
				if(ep->dimens == 0)
					error(19);
			}
			else if(ep->dimens != 0 || (ep->flags & ISFUNC))
				error(2);
		}
		ep->flags |= IS_COMMON;
	} while(getch() == ',');
	point--;
	normret;
}

int
blocal()
{
	forstp	fp;
	struct entry	*ep;
	loc_sav_t	*lp;
	struct	loc_sav_e	loc;
	struct	entry	*todrop;

	for(fp = estack ; fp ; fp = fp->prev)
		if(fp->fortyp == FNTYP)
			break;
	if(!fp)
		error(54);
	lp = fp->fnLOCAL;
	do {
		ep = getnm(0, 1);
		loc.lentry = 0;
		loc.hentry = 0;
		todrop = 0;
		if(!ep){
			ep = newentry;
			if(*point == LBRACK){
				if(*++point != RBRACK)
					dim_one();
				else {
					point++;
					/*
					 * allocate a default array for this
					 * var, I suppose this is justified
					 */
					def_darr(ep, DEF_AR_SIZ, 0);
				}
			}
			else
				ep->vtype = vartype;
			newentry = 0;
			loc.hentry = ep;
		}
		else {
			loc.lentry = ep;
			if(*point == LBRACK){
				if(*(point+1) != RBRACK)
					error(SYNTAX);
				point+=2;
/*
				if(ep->dimens == 0)
					error(19);
*/
			}
			else if(ep->dimens != 0 || (ep->flags & ISFUNC))
				error(2);
			loc.hentry = dup_var(ep);
			add_entry(loc.hentry);
			todrop = ep;
		}
		if(lp == 0 || lp->narg >= LOC_SAV_E){
			lp = (loc_sav_t *)mmalloc((ival)sizeof(loc_sav_t));
			lp->narg = 0;
			lp->next = fp->fnLOCAL;
			fp->fnLOCAL = lp;
		}
		loc.hentry->flags |= IS_LOCAL;
		if(todrop)
			drop_val(todrop, 0);
		lp->arg[lp->narg++] = loc;
	} while(getch() == ',');
	point--;
	normret;
}

struct	entry	*
dup_var(oep)
struct	entry	*oep;
{
	struct	entry	*ep;
	ival	i, j, siz;

	ep = (struct entry *)mmalloc( (ival)(sizeof(struct entry)+oep->namlen));
	*ep = *oep;
	ep->link = 0;
	VOID strmov(ep->_name, oep->_name, ep->namlen+1);
	if(ep->dimens){
		/* work out size of the array and allocate again */
		j = TYP_SIZ(ep->vtype);

		for(i = 0 ; i < ep->dimens ; i++)
			j *= ep->_dims[i];
		siz = j + (ep->dimens * sizeof(ival));
		/*
		 * Check to see if we have enough space
		 */
		if(!mtestalloc(siz)){
			mfree( (MEMP)ep);
			error(24);
		}
		/*
		 * reallocate the array and the indexes
		 */
		ep->_darr = (memp)mmalloc(siz);
		/*LINTED*/
		ep->_dims = (ival *)(ep->_darr + j);
		for(i = 0 ; i < ep->dimens ; i++)
			ep->_dims[i] = oep->_dims[i];
		clr_mem(ep->_darr, j);
	}
	else
		ep->d = entry_zero;
	ep->flags &= ~(IS_COMMON|IS_FSTRING);
	return(ep);
}
