/*
 * BASIC by Phil Cockcroft
 */
/*
 *      This file contains all the variables and definitions needed by
 *    all the C parts of the interpreter.
 */

#include <assert.h>
#include <ctype.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/fcntl.h>
#include <time.h>
#include <sys/time.h>
#include <unistd.h>

#define	BLOCKSIZ 512

#define	DEB printf("%s: %s() %d\n", __FILE__, __FUNCTION__, __LINE__);

#define	BIG_INTS
//#define	RAND48
/*
 * include the correct include file for the current machine
 */

//#include "conf.h"

typedef char	CHAR;

#define VOID	/**/
#define UC(c)	((c) & MASK)

#ifndef	WORD_SIZ
#define	WORD_SIZ	4
#endif

#if	WORD_SIZ == 4
#define	WORD_SHIFT	2
#define	WORD_MASK	3
#else
#if	WORD_SIZ == 2
#define	WORD_SHIFT	1
#define	WORD_MASK	1
#else
#define	WORD_SHIFT	3
#define	WORD_MASK	7
#endif
#endif

#ifndef	MAX_MEM_DEFAULT

/*
 * Default values for the memory allocation scheme when using OWN_ALLOC
 * These are deemed ok for normal use.
 */
#define	MAX_MEM_DEFAULT	1000
#ifdef	BIG_INTS
#define	MAX_MEM_MAX	1000000	/* Approx 4Gbytes */
#else
#define	MAX_MEM_MAX	32000
#endif

#endif

/*
 * maximum size of an array - 200M elements
 */
#ifndef	MAX_ARRAY
#define	MAX_ARRAY	200000000
#endif

#define MASK            0377

#define SPECIAL         0200            /* top bit set */

/*
 * expanded function values
 */
#define	EXFUNC	0370
#define	IFUNCN	0371
#define	IFUNCA	0372
#define	SFUNCN	0373
#define	SFUNCA	0374
#define	OFUNC	0375
#define	EXCMD	0376

#define	MKIFN(x) ((1<<8) | SPECIAL | (x))
#define	MKIFA(x) ((2<<8) | SPECIAL | (x))
#define	MKSFN(x) ((3<<8) | SPECIAL | (x))
#define	MKSFA(x) ((4<<8) | SPECIAL | (x))
#define	MKOFN(x) ((5<<8) | SPECIAL | (x))
#define	MKXCMD(x) ((6<<8) | SPECIAL | (x))

#define NORMAL          0               /* normal return from a command */
#define GTO             1               /* ignore rest of line return */
#define normret		return(NORMAL)

#define SYNTAX          1               /* error code */
#define VARREQD         2               /* error code */
#define OUTOFSTRINGSPACE 3              /* ditto */
#define BADDATA         26              /* error message values */
#define OUTOFDATA       27
#define FUNCT           33
#define FLOATOVER       34
#define INTOVER         35
#define REDEFFN         45
#define UNDEFFN         46
#define CANTCONT        47
#define	BADFORMAT	53
#define	WR_ERR		60
#define MAXERR          60              /* maximum value of error code */


#ifdef	MSDOS
#define	MAX_STR		255	/* maximum length of a string */
#define	MAX_FCALLS	10	/* max number of recursive fcalls */
#else
#define	MAX_STR		32767	/* maximum length of a string */
#define	MAX_FCALLS	100	/* max number of recursive fcalls */
#endif
#define MAXLIN          255	/* maximum length of input line */

#define	DEF_AR_SIZ	10	/* default array size */

#define	RVAL		0
#define	IVAL		1
#define	SVAL		2
#define	UNK_VAL		0x44	/* unknown type */
#define	NVALMASK	1
#define	ISFUNC		0200

#define HSHTABSIZ       37              /* size of initial hash table */
#define	MKhash(x)	((x) % HSHTABSIZ)
#define	TMAPSIZ		(128 - 'A')	/* length of defint array */

/*      definitions of some simple functions */
/*      istermin()      - true if character is a terminator */

#define istermin(c)  (!(c)|| (c)==':' ||((CHAR)(c)==(CHAR)ELSE && elsecount))

#define	TYP_SIZ(typ)	(typ_siz[UC(typ)])

/*
 *      values of constants from the symbol table
 */

#define FN              0263
#define	FNEND		0262
#define	MIDSTR		0271		/* mid$ command */
#define MAXCOMMAND      0330            /* maximum allowed command code */
#define DATA            0236
#define QUOTE           0233
#define ERROR           0231
#define	QPRINT		0232
#define GOSUB           0226
#define FOR             0224
#define IF              0221
#define INPUT           0212
#define	PRINT		0206
#define	READ		0235
#define	RANDOM		0222
#define RUNN            0201
#define REM             0203
#define GOTO            0202
#define	LET		0205
#define	NEXT		0225
#define WHILE           0257
#define WEND            0260
#define REPEAT          0255
#define UNTIL           0256
#define ELSE            0331
#define THEN            0332
#define ON              0230
#define RESUME          0220
#define RESTORE         0240
#define TABB            0333            /* tab command */
#define STEP            0334
#define TO              0335
#define AS              0345
#define OUTPUT          0346
#define APPEND          0347
#define TERMINAL        0351
#define	RECORD		0352
#define	RECORDSIZ	0353
#define	ALL		0354
#define	USING		0356

/* circular operations */

#define	OPT_RAD		00
#define	OPT_DEG		01
#define	OPT_GRAD	02
#define	OPT_MEM		03
#define	OPT_BASE	0241

/*      logical operators */

#define MODD            0341
#define ANDD            0336
#define ORR             0337
#define XORR            0340
#define NOTT            0350
#define	IMPP		0357
#define	EQVV		0360

/*      comparison operators */

#define EQL             '='
#define LTEQ            0342
#define NEQE            0343
#define LTTH            '<'
#define GTEQ            0344
#define GRTH            '>'
#define	APRX		0355

/*      values used for file maintainance */

#define _READ           01
#define _WRITE          02
#define _EOF            04
#define _TERMINAL       010
#define _BLOCKED        020

#define MAXFILES        15

/*	values used for strings/int/float options */

#define	D_STR	'$'
#define	D_INT	'%'
#define	D_FLT	'#'

/*	The escape char */

#define	ESCAPE	'\033'

#include        <setjmp.h>
//#include        <signal.h>
#include        <sys/types.h>

#define	NORM_RESET	1
#define	ERR_RESET	2

#define setexit()       setjmp(rcall)
#define reset()         longjmp(rcall, NORM_RESET)
#define	errreset()	longjmp(rcall, ERR_RESET)

#define	NO_RET		for(;;)

/*
 * various type definitions
 */

#ifdef	BIG_INTS
typedef	long	itype;
typedef	long	ival;
#define	TOP_BIT	0x80000000L
#define	IS_OVER(x, y, l)	( (~((x) ^ (y)) & ((l) ^ (y))) & TOP_BIT)
#else
typedef	short	itype;
typedef	int	ival;
#define	TOP_BIT	0x8000
#define	IS_OVER(x, y, l)	( (l) > 32767 || (l) < -32768)
#endif

typedef	unsigned lnumb;

typedef struct  olin    *lpoint;        /* typedef for pointer to a line */
typedef struct  deffn   *deffnp;        /* pointer to a function definition */
typedef struct  filebuf *filebufp;      /* pointer to a filebuffer */
typedef struct  forst   *forstp;        /* pointer to a for block */
typedef	struct	stringd	*stringp;
typedef CHAR    *memp;                  /* a memory pointer */
typedef struct	str_info *STR;

/*      typedef fo the standard dual type of variable */

typedef union {
	itype   i;
	double  f;
} value, *valp;

typedef	void	*MEMP;
typedef	void	(*voidf_t[])(void);
typedef	STR	(*strf_t[])(void);
typedef	int	(*intf_t[])(void);
typedef	void	mbinf_t(valp, valp, int);
typedef	void	(*mathf_t[])(valp, valp, int);
typedef	char	*str_t[];

/*      all structures must have an exact multiple of the size of an int
 *    to the start of the next structure
 */

struct	olin	{                    /* structure for a line */
	struct	olin	*next;
	lnumb	linnumb;
	CHAR	lin[1];
};

struct	stringd	{
	memp	str;
	ival	len;
};

/*
 * array subscripts are now stored in the same dynamic memory as
 * the array members so dims is now a pointer to where they start
 * (subscripts are stored after the array members)
 * this means that the number of subscripts can be effectively unlimited
 * (dimens is a char so limit is 127). lines are a max of 256 chars so
 * cannot actually define more than 125 or so dimens on one line
 */
#define	MAXDIMS	64	/* lots of dimensions ( could go up to 127 ) */

struct	arrayd	{
	memp	dptr;
	itype	*dims;
};

#define	IS_FN	0
#define	IS_MFN	1
#define	IS_MPR	2
#ifdef	MSDOS
#define	FN_MAX_ARGS	8	/* thats enough isn't it */
#else
#define	FN_MAX_ARGS	127	/* thats enough isn't it */
#endif

struct  deffn  {                /* structure for a user definable function */
	short	ncall;
	char	mline;
	char    narg;
	struct	entry	**vargs;	/* points to list of params */
	lpoint	mpnt;			/* list stored after deffn struct */
	CHAR    exp[1];
};

#define	IS_FSTRING	1
#define	IS_COMMON	2
#define	IS_LOCAL	4

struct  entry   {               /* the structure for a long name storage */
	struct  entry   *link;
	unsigned ln_hash;        /* hash value of entry */
	char	vtype;
	char	dimens;
	char	flags;
	char	namlen;
	union	entry_vals {
		value	_dt;
		struct	stringd	_ds;
		struct	arrayd	_da;
		struct	deffn	*_df;
	} d;
	CHAR    _name[1];	/* name of entry. Length is dynamic */
};


#define	_dval	d._dt
#define	_dst	d._ds
#define	_dstr	d._ds.str
#define	_dslen	d._ds.len
#define	_darr	d._da.dptr
#define	_dims	d._da.dims
#define	_deffn	d._df

/*
 * structure to hold pointers to saved local vars when using them
 * in functions and procedures
 */
#define	LOC_SAV_E	7

typedef	struct	loc_s_l {
	struct	loc_sav_e {
		struct	entry	*lentry;
		struct	entry	*hentry;
	} arg[LOC_SAV_E];
	int	narg;
	struct	loc_s_l	*next;
} loc_sav_t;

struct	hash	{
	struct	entry	*hasht[HSHTABSIZ];
};

struct  filebuf {               /* the file buffer structure */
	struct	filebuf	*next;
	int	filedes;        /* system file descriptor */
	ival	posn;           /* cursor / read positon */
	itype   userfiledes;    /* user name */
	int	use;            /* flags */
	int	bufsiz;		/* size of buffer */
	unsigned long	inodnumber;    /* to stop people reading and writing */
	unsigned long	device; /* to the same file at the same time */
	unsigned nleft;         /* number of characters in buffer */
	CHAR	buf[sizeof(int)];/* the buffer itself -dynamically alloced*/
};

#define	FORTYP	0
#define	GOSTYP	1
#define	WHLTYP	2
#define	REPTYP	3
#define	FNTYP	4	/* type is for a multiline function */

#define	DIR_DEC	0	/* only for 'for' loops */
#define	DIR_INC	1

struct  forst {                 /* for / gosub stack */
	struct	forst	*prev;
	struct	forst	*next;
	struct	entry	*fnnm;  /* pointer to variable */
	char    fortyp, elses;  /* type of structure , elsecount on return */
	char	forvty;		/* type of value fnnm is */
	char	fordir;		/* direction of loop. Quicker on non vaxen */
	lpoint  stolin;         /* pointer to return start of line */
	CHAR    *pt;            /* return value for point */
	union	{
		struct	forp	{
			value   _final;          /* the start and end values */
			value   _step;
		} _ff;
		struct	fntyp	{
			union	{
				value	_fnval;
				struct	stringd	_fnsval;
			} _ret;
			loc_sav_t	*_fnlocal;
			struct	JMPBUF	{
				jmp_buf	_fnenv;
				STR	_fnstr_beg;
				STR	_fnstr_end;
			} *_jmp;
		} _fn;
		struct	loopp	{
			lpoint	_lpend;	/* support for multiline loops */
			CHAR	*_lppt;
		} _lp;
	} forps;
};

#define	final	forps._ff._final
#define	step	forps._ff._step
#define	fnvar	fnnm
#define	fnval	forps._fn._ret._fnval
#define	fnsval	forps._fn._ret._fnsval
#define	fnenv	forps._fn._jmp->_fnenv
#define	fnLOCAL	forps._fn._fnlocal
#define	fnJMP	forps._fn._jmp
#define	fnSBEG	forps._fn._jmp->_fnstr_beg
#define	fnSEND	forps._fn._jmp->_fnstr_end

#define	fnlpend	forps._lp._lpend
#define	fnlppt	forps._lp._lppt

struct tabl {                   /* structure for symbol table */
	const	char    *string;
	const	int     chval;
};

/*
 * structure to hold runtime environment for error traps and cont's
 */
struct	env	{
	CHAR	*e_point;	/* saved value of point */
	lpoint	e_stolin;	/* saved value of stocurlin */
	lpoint	e_ertrap;	/* saved value of error trap location */
	char	e_elses;	/* saved value of elsecount */
};

/*
 * chosen so that a STR still fits in a 64 byte allocation block
 * we use a local buffer because most strings are short, and this
 * helps the allocation and manipulation of strings.
 */

#if WORD_SIZ == 2
#define	LOC_BUF_SIZ	52
#else
#if WORD_SIZ == 8
#define	LOC_BUF_SIZ	80	/* use a 128 byte block */
#endif
#endif

#ifndef	LOC_BUF_SIZ
#define	LOC_BUF_SIZ	40
#endif

struct	str_info {
	CHAR	*strval;
	unsigned int	strlen;
	CHAR	*allocstr;
	unsigned int	alloclen;
	struct	str_info *next;
	struct	str_info *prev;
	CHAR	locbuf[LOC_BUF_SIZ];
};

#ifndef SOFTFP

#define fadd(p,q)       ((q)->f += (p)->f)
#define fsub(p,q)       ((q)->f = (p)->f - (q)->f)
#define fmul(p,q)       ((q)->f *= (p)->f)
#define fdiv(p,q)       ((q)->f = (p)->f / (q)->f)

#define conv(p) \
	( ((p)->f > MAXint || (p)->f < MINint) ? 1 : _conv(p) )

extern	int	_conv(value *);

#define cvt(p)  (p)->f = (p)->i

#else

extern	int	conv(value *);

#endif

#ifdef	IEEEMATHS

/*
 * On the symmetric 375 ns32000 port the compiler has a terrible
 * data input conversion routine
 * I have commented any of the values that are bad
 */

/*
 * maximum number inputable to the interpreter
 */
#define BIGval     1.7976931348623157e308
#define	BIGEXP	3276

#define	LOGMAXVAL	709.782712893383996	/* maxvalue for exp */
					/* should be 709.78271289338 */

#else

#define BIGval     1.701411835e37
#define	BIGEXP	1000

#define	LOGMAXVAL	88.02969
#endif

#define	MAX_INSIG	1e19	/* apprx maximum value where sqr(x*x -1) = x */

#ifdef	BIG_INTS
#define	MAX_INT	2147483647
#else
#define	MAX_INT 32767
#endif

#ifndef	UNPORTABLE
#define	IS_ZERO(x)	((vartype == RVAL) ? ((x).f == ZERO) : ((x).i == 0))
#else
#define	IS_ZERO(x)	((x).i == 0)
#endif

#define	PI_VALUE	3.14159265358979323846        /* value of pi */

/*      declarations to stop the C compiler complaining */

#ifdef	MSDOS
#define	putch	myputch
char	*ctime();
char	*getenv();
#define	do_system	system
#endif

#define	SIGFUNC	void

#define	NOLNUMB	65534
#define	CONTLNUMB 65533

extern	const	mathf_t	mbin;

filebufp getf(ival, int);
lpoint  getbline(void), getsline(lnumb);
lnumb	getrline(lpoint);
void	prsline(const char *, lpoint);
struct	entry	*getnm(int, int);
struct	entry	*dup_var(struct entry *);
lnumb	getlin(void);
itype	evalint(void);
char    *printlin(lnumb);
CHAR	*str_cpy(CHAR *, CHAR *);
CHAR	*strmov(CHAR *, CHAR *, ival);
int	slen(const char *);

int	cmp(value *, value *);
int	getch(void), getnumb(CHAR *, CHAR **);
int	checktype(void), compile(int, CHAR *, int), edit(ival, ival, ival);
int	putfile(filebufp, CHAR *, int);

void    *mmalloc(ival);
int	mtestalloc(ival);
void	mfree(MEMP);
MEMP    getname(int);
struct	entry *getmat(int);

void	evalreal(void), clear_htab(struct hash *);
void	recover_vars(forstp, int);
void	ffn(struct entry *, STR);
void	error(int), clear(void), eval(void), c_error(int);
void	check(void), putin(value *, int), prints(const char *), printd(lnumb);
void	readfi(int, lpoint, int), compare(int, int), stringcompare(void);
STR	stringeval(void), mgcvt(void), mathpat(STR);
void	stringassign(stringp, struct entry *, STR, int);
void	closeall(void), clr_stack(forstp);
void	setupfiles(int, char **), setupmyterm(void);
void	setup_f32c(void);
void	setup_fb(void);
void	update_x11(int);
void	errtrap(void), flushall(void), insert(int), negate(void);
void	ins_line(lpoint, int);
void	set_mem(CHAR *, ival, int);
void	clr_mem(CHAR *, ival);
void	save_env(struct env *), ret_env(struct env *);
void	assign(int),ch_clear(int), dobreak(void), drop_fns(void);
void	drop_val(struct entry *, int), execute(void);
void	free_entry(struct entry *), add_entry(struct entry *);
void	fpcrash(void),kill_fstrs(CHAR *, CHAR *);
void	notit(void), startfp(void);
void	errtrap(void);
void	dostop(int);
void	catchsignal(void);
int	fin1ch(filebufp);
int	do_system(CHAR *);
void	matread(MEMP, int, int);
int	matinput(void);
int	matprint(void);

void	COPY_OVER_STR(STR, STR);
void	FREE_STR(STR);
void	RESERVE_SPACE(STR, ival);
void	NULL_TERMINATE(STR);
STR	ALLOC_STR(ival);
void	DROP_STRINGS(void);
void	def_darr(struct entry *, int, int);
itype	mmult_ply(itype, itype, int);

void    rnd(void),pii(void),erlin(void),erval(void),tim(void),
	sgn(void),len(void),babs(void),val(void),ascval(void),instr(void),
	eofl(void),fposn(void),bsqrtf(void),blogf(void),bexpf(void),
	evalu(void),intf(void),peekf(void),bsinf(void),bcosf(void),
	batanf(void),mkint(void),mkdouble(void),ssystem(void),blog10f(void),
	btanf(void),bfixf(void),binval(void),bsinh(void),bcosh(void),
	btanh(void), basinh(void), bacosh(void), batanh(void),
	basinf(void), bacosf(void), bvarptr(void), bsyscall(void),
	bsyserr(void), bmax(void), bmin(void), bcreal(void), bcint(void),
	rinstr(void), curkeys(void);

STR	rightst(void),leftst(void),
	strng(void),estrng(void),chrstr(void),nstrng(void),space(void),
	xlate(void),mkistr(void),mkdstr(void),hexstr(void),octstr(void),
	datef(void), binstr(void), decstr(void), blower(void), bupper(void);

int	endd(void),runn(void),gotos(void),rem(void),lets(void),list(void),
	print(void),stop(void),bdelete(void),editl(void),input(void),
	clearl(void),save(void),load(void),neww(void),
	bas_exec(void), resume(void),
	iff(void),brandom(void),dimensio(void),forr(void),next(void),
	gosub(void),retn(void),onn(void),doerror(void),
	dauto(void),readd(void),dodata(void),cls(void),restore(void),
	base(void),bfopen(void),fclosef(void),merge(void),chain(void),
	deffunc(void),cont(void),lhmidst(void),linput(void),poke(void),
	rept(void),untilf(void),whilef(void),wendf(void),renumb(void),
	fnend(void), fncmd(void), blset(void), brset(void), bfield(void),
	bput(void), bget(void), bdefint(void), bdefstr(void), bdefdbl(void),
	bcommon(void), blocal(void), defproc(void), bopts(void),
	tron(void), troff(void), bdir(void), bdirl(void), bdeffn(void),
	bmat(void), bwrite(void), berase(void),
	file_kill(void), file_mkdir(void), file_copy(void), file_rename(void),
	file_cd(void), file_pwd(void), file_more(void),
	plot(void), lineto(void), rectangle(void), circle(void), text(void),
	vidmode(void), drawable(void), visible(void),
	ink(void), paper(void), loadjpg(void),
	sprgrab(void), sprload(void), sprtrans(void),
	sprput(void), sprfree(void);

int	bas_sleep(void), bauds(void);
int	quit(void);


/*   definition of variables for other source files */

extern	uint32_t freq_khz, tsc_hi, tsc_lo;
extern  int     baseval;
extern	int	drg_opt;
extern	int	tron_flag;
extern  const	char    nl[];
extern  CHAR    line[];
extern  CHAR    nline[];
extern  lnumb	linenumber;
extern	struct	entry	*curentry;
extern	struct	entry	*newentry;
extern	forstp	savbstack;
extern	forstp	savestack;
extern	forstp	bstack;
extern	forstp	estack;
extern	STR	str_used;
extern	STR	str_uend;
extern	int	maxfiles;
extern	int	ncurfiles;
extern  lpoint  program;
extern	filebufp filestart;
extern  ival    cursor;
extern	struct	env	cont_env;
extern	struct	env	err_env;
extern	struct	env	trap_env;
extern  lpoint  stocurlin;
extern  CHAR    *point;
extern  CHAR    *savepoint;
extern  char    elsecount;
extern  char    vartype;
extern  char    intrap;
extern  char    trapped;
extern  char    inserted;
extern	lpoint	last_ins_line;
extern  int     readfile;
extern	int	lp_fd;
extern  lnumb	elinnumb;
extern  ival    ecode;
extern  lpoint  datastolin;
extern  CHAR    *datapoint;
extern  int     evallock;
extern  int     fnlock;
extern	MEMP	renstr;
extern  lnumb	autostart;
extern  lnumb	autoincr;
extern  int     ter_width;
extern  char    contpos;
extern  char    cancont;
extern  char    noedit;

#ifdef	SOFTFP
extern  long    overfl;
#endif
extern  value   res;
extern	void	(*fpfunc)(void);

extern  const	double  pivalue;
extern  const	double  MAXint,MINint;
extern	const	double	ZERO;
extern	const	double	ONE;
extern	const	double	BIG;
extern	const	double	BIGminus;

extern  jmp_buf rcall;

#ifdef  SIG_JMP
extern  jmp_buf ecall;
extern  char    ecalling;
#endif

extern  struct  hash	hshtab;
extern	CHAR	tcharmap[];

extern	const	voidf_t	functs;
extern  const	voidf_t	functb;
extern  const	strf_t	strngcommand;
extern  const	strf_t	strngncommand;
extern  const	str_t   ermesg;
extern  const	struct  tabl    table[];
extern	const	int	typ_siz[];

/*
 *      PART1 is declared only once and so allocates storage for the
 *    variables only once , otherwise the definiton for the variables
 *    ( in all source files except bas1.c ). is declared as external.
 */

#ifdef  PART1

int     baseval=1;              /* value of the initial base for arrays */
int	drg_opt = OPT_RAD;
const	char    nl[]="\n";	/* a new_line character */
CHAR    line[MAXLIN+2];         /* the input line */
CHAR    nline[MAXLIN];          /* the array used to store the compiled line */
lnumb	linenumber;             /* linenumber form compile */

int	tron_flag;			/* trace flag */

struct	entry	*curentry;
struct	entry	*newentry;

lpoint	program;		/* start of program */

filebufp filestart;		/* pointer to first filebuf */
int	maxfiles;
int	ncurfiles;

forstp	bstack;			/* pointers to the for/next stack */
forstp	estack;
forstp	savbstack;		/* saved for/next stack after break */
forstp	savestack;

STR	str_used;		/* currently used strings */
STR	str_uend;

struct	env	cont_env;	/* saved env after ctrl-c or stop - for cont */
struct	env	err_env;	/* saved env after an error */
struct	env	trap_env;	/* environment to be used on error goto's */

lpoint  stocurlin;      /* start of current line */
CHAR    *point;         /* pointer to current location */
char    elsecount;      /* flag for enabling ELSEs as terminators */
CHAR    *savepoint;     /* value of point at start of current command */

char    intrap;         /* we are in the error trapping routine */
char    trapped;        /* cntrl-c trap has occured */
char    inserted;       /* the line table has been changed, clear variables */

lpoint	last_ins_line;	/* pointer to last line that was inserted into the
			 * program, If line has no line number, then line
			 * is added after this line.
			 */

lnumb	elinnumb;       /* ditto */
ival    ecode;          /* error code */

char    contpos;	/* flags controlling cont processing */
char    cancont;

ival	cursor;         /* position of cursor on line */

int     readfile;       /* input file , file descriptor */

char    vartype;        /* current type of variable */

lpoint  datastolin;     /* pointer to start of current data line */
CHAR    *datapoint;     /* pointer into current data line */

int     evallock;       /* lock to stop recursive eval function */
int	fnlock;		/* lock to stop recursive user functions */
MEMP	renstr;		/* pointer to an array used by renumber */

lnumb	autostart = 100; /* values for auto command */
lnumb	autoincr = 10;

void	(*fpfunc)(void);

int     ter_width;      /* set from the terms system call */

char    noedit;         /* set if noediting is to be done */

#ifdef SOFTFP
long    overfl;         /* value of overflowed integers, converting to real */
#endif

value   res;            /* global variable for maths function */

const	double  pivalue= PI_VALUE;
#ifndef SOFTFP
const	double  MAXint= MAX_INT;                     /* for cvt */
const	double  MINint= -MAX_INT-1;
#endif
const	double	ZERO = 0.0;
const	double	ONE = 1.0;
const	double	BIG = BIGval;
const	double	BIGminus = -BIGval;


jmp_buf	rcall;

#ifdef  SIG_JMP
jmp_buf ecall;                  /* for use of cntrl-c in edit */
char    ecalling;
#endif

struct  hash   hshtab;			/* hash table pointers */

CHAR	tcharmap[TMAPSIZ];

/*
 *      definition of the command , function and string function 'jump'
 *    tables.
 */

/*      maths functions that do not want an argument */

const	voidf_t	functs = {
	rnd, pii, erlin, erval, tim, bsyserr, curkeys
};

/*      other maths functions */

const	voidf_t    functb = {
	sgn, len, babs, val, ascval, instr, eofl, fposn, bsqrtf, blogf, bexpf,
	evalu,intf,peekf,bsinf,bcosf,batanf,mkint,mkdouble, ssystem, blog10f,
	btanf, bfixf, binval, bsinh, bcosh, btanh, basinh, bacosh, batanh,
	basinf, bacosf, bvarptr, bsyscall, bmax, bmin, bcint, bcreal, rinstr,
};

/*      string function , N.B. date$ is not here. */

const	strf_t	strngcommand = {
	rightst, leftst, strng, estrng, chrstr, nstrng, space,
	xlate, mkistr, mkdstr, hexstr, octstr, binstr, decstr,
	bupper, blower,
};

const	strf_t	strngncommand = {
	datef,
};

/*      commands */

static const intf_t commandf = {
	endd,runn,gotos,rem,list,lets,print,stop,bdelete,editl,input,clearl,
	save,load,neww,
	bas_exec, resume,iff,brandom,dimensio,forr,next,gosub,retn,
	onn,doerror,print,rem,dauto,readd,dodata,cls,restore,base,bfopen,
	fclosef,merge, bauds, quit, bas_sleep,
	chain,deffunc,cont,poke,linput,rept,
	untilf,whilef,wendf,renumb,fnend,fncmd, blset, brset, bfield, bput,
	bget,lhmidst, bdefint, bdefstr, bdefdbl, bcommon, blocal, defproc,
	bdeffn, bopts, tron, troff, bdir, bdirl, bmat, bwrite, berase,
	file_more, file_kill, file_mkdir, file_copy, file_rename,
	file_cd, file_pwd,
	plot, lineto, rectangle, circle, text
};

/*      extended commands */

static const intf_t xcmdf = {
	vidmode, drawable, visible, ink, paper, loadjpg,
	sprgrab, sprload, sprtrans, sprput, sprfree
};

/*      table of error messages */

const	str_t	ermesg = {
	"syntax error",
	"variable required",
	"illegal string assignment",
	"assignment '=' required",
	"line number required",
	"undefined line number",
	"line number overflow",
	"illegal command",
	"string overflow",
	"illegal string size",	/* 10 */
	"illegal function",
	"buffer size overflow in field",
	"illegal edit",
	"cannot creat file",
	"cannot open file",
	"dimension error",
	"subscript error",
	"next without for",
	"undefined array",
	"redimension error",	/* 20 */
	"gosub / return error",
	"illegal error code",
	"illegal string in rset/lset",
	"out of core",
	"zero divisor error",
	"bad data",
	"out of data",
	"bad base",
	"bad file descriptor",
	"unexpected eof",	/* 30 */
	"out of files",
	"line length overflow",
	"argument error",
	"floating point overflow",
	"integer overflow",
	"bad number",
	"negative square root",
	"negative or zero log",
	"overflow in exp",
	"overflow in power",	/* 40 */
	"negative power",
	"badly defined user function",
	"mutually recursive eval",
	"expression too complex",
	"illegal redefinition",
	"undefined user function",
	"can't continue",
	"until without repeat",
	"wend without while",
	"no wend statement found",	/* 50 */
	"illegal loop nesting",
	"get/put on unformated file",
	"bad format 'using' string",
	"local not inside function",
	"cannot common local variables",
	"invalid function/procedure call",
	"bad load",
	"Non conformant matrices",
	"Matrix has too many dimensions",
	"File write error",		/* 60 */
	};

/*      tokenising table */

const	struct  tabl    table[]={
	"END",		0200,             /* commands 0200 - 0300 */
	"RUN",		0201,
	"GOTO",		0202,
	"REM",		0203,
	"LIST",		0204,
	"LET",		0205,
	"PRINT",	0206,
	"STOP",		0207,
	"DELETE",	0210,
	"EDIT",		0211,
	"INPUT",	0212,
	"CLEAR",	0213,
	"SAVE",		0214,
	"LOAD",		0215,
	"NEW",		0216,
	"EXEC",		0217,
	"RESUME",	0220,
	"IF",		0221,
	"RANDOM",	0222,
	"DIM",		0223,
	"FOR",		0224,
	"NEXT",		0225,
	"GOSUB",	0226,
	"RETURN",	0227,
	"ON",		0230,
	"ERROR",	0231,
	"?",		0232,
	"'",		0233,
	"AUTO",		0234,
	"READ",		0235,
	"DATA",		0236,
	"CLS",		0237,
	"RESTORE",	0240,
	"BASE",		0241,
	"OPEN",		0242,
	"CLOSE",	0243,
	"MERGE",	0244,
	"BAUDS",	0245,
	"BYE",		0246,
	"SLEEP",	0247,
	"CHAIN",	0250,
	"DEF",		0251,
	"CONT",		0252,
	"POKE",		0253,
	"LINPUT",	0254,
	"REPEAT",	0255,
	"UNTIL",	0256,
	"WHILE",	0257,
	"WEND",		0260,
	"RENUMBER",	0261,
	"FNEND",	0262,
	"FN",		0263,	/* is a command and a function (special) */
	"LSET",		0264,		/* random access files */
	"RSET",		0265,
	"FIELD",	0266,
	"PUT",		0267,
	"GET",		0270,
	"MID$",		0271,
	"DEFINT",	0272,
	"DEFSTR",	0273,
	"DEFDBL",	0274,
	"COMMON",	0275,
	"LOCAL",	0276,
	"DEFPROC",	0277,
	"DEFFN",	0300,
	"OPT",		0301,
	"TRON",		0302,
	"TROFF",	0303,
	"DIR",		0304,
	"DIRL",		0305,
	"MAT",		0306,
	"WRITE",	0307,
	"ERASE",	0310,
	/* filesystem utilities */
	"MORE",		0311,
	"KILL",		0312,
	"MKDIR",	0313,
	"COPY",		0314,
	"RENAME",	0315,
	"CD",		0316,
	"PWD",		0317,
	/* framebuffer commands */
	"PLOT",		0320,
	"LINETO",	0321,
	"RECTANGLE",	0322,
	"CIRCLE",	0323,
	"TEXT",		0324,
	/*
	 * commands go to here
	 */
	/*
	 * seperators go from here
	 */
	"ELSE",		0331,
	"THEN",		0332,
	"TAB",		0333,
	"STEP",		0334,
	"TO",		0335,
	"AND",		0336,
	"OR",		0337,
	"XOR",		0340,
	"MOD",		0341,
	"<=",		0342,
	"<>",		0343,
	">=",		0344,
	"AS",		0345,
	"OUTPUT",	0346,
	"APPEND",	0347,
	"NOT",		0350,
	"TERMINAL",	0351,
	"RECORD",	0352,
	"RECORDSIZE",	0353,
	"ALL",		0354,
	"==",		0355,	/* aprox equal */
	"USING",	0356,
	"IMP",		0357,
	"EQV",		0360,
	/*
	 * at 370 to 376 are the values for extended functions
	 * which are then followed by one of the following after it has
	 * been decoded.
	 */

	/* extended commands */
	"VIDMODE",	MKXCMD(0),
	"DRAWABLE",	MKXCMD(1),
	"VISIBLE",	MKXCMD(2),
	"INK",		MKXCMD(3),
	"PAPER",	MKXCMD(4),
	"LOADJPG",	MKXCMD(5),
	"SPRGRAB",	MKXCMD(6),
	"SPRLOAD",	MKXCMD(7),
	"SPRTRANS",	MKXCMD(8),
	"SPRPUT",	MKXCMD(9),
	"SPRFREE",	MKXCMD(10),

	/* string functs with args */
	"RIGHT$",	MKSFA(0),
	"LEFT$",	MKSFA(1),
	"STRING$",	MKSFA(2),
	"ERMSG$",	MKSFA(3),
	"CHR$",		MKSFA(4),
	"STR$",		MKSFA(5),
	"SPACE$",	MKSFA(6),
	"XLATE", 	MKSFA(7),
	"MKIS$",	MKSFA(010),
	"MKDS$",	MKSFA(011),
	"HEX$", 	MKSFA(012),
	"OCT$",		MKSFA(013),
	"BIN$",		MKSFA(014),
	"DEC$",		MKSFA(015),
	"UPPER$",	MKSFA(016),
	"LOWER$",	MKSFA(017),

	"DATE$",	MKSFN(0),	/* strng funcs without args */

	"SGN",		MKIFA(0),       /* maths functions with args */
	"LEN",		MKIFA(1),
	"ABS",		MKIFA(2),
	"VAL",		MKIFA(3),
	"ASC",		MKIFA(4),
	"INSTR",	MKIFA(5),
	"EOF",		MKIFA(6),
	"POSN",		MKIFA(7),
	"SQRT",		MKIFA(010),
	"LOG",		MKIFA(011),
	"EXP",		MKIFA(012),
	"EVAL",		MKIFA(013),
	"INT",		MKIFA(014),
	"PEEK",		MKIFA(015),
	"SIN",		MKIFA(016),
	"COS",		MKIFA(017),
	"ATAN",		MKIFA(020),
	"MKSI",		MKIFA(021),
	"MKSD",		MKIFA(022),
	"SYSTEM", 	MKIFA(023),
	"LOG10",	MKIFA(024),
	"TAN", 		MKIFA(025),
	"FIX", 		MKIFA(026),
	"BVAL",		MKIFA(027),
	"SINH",		MKIFA(030),
	"COSH",		MKIFA(031),
	"TANH",		MKIFA(032),
	"ASINH",	MKIFA(033),
	"ACOSH",	MKIFA(034),
	"ATANH",	MKIFA(035),
	"ASIN",		MKIFA(036),
	"ACOS",		MKIFA(037),
	"VARPTR",	MKIFA(040),
	"SYSCALL",	MKIFA(041),
	"MAX",		MKIFA(042),
	"MIN",		MKIFA(043),
	"CINT",		MKIFA(044),
	"CREAL",	MKIFA(045),
	"RINSTR",	MKIFA(046),

	"RND",		MKIFN(0),	/* maths funcs without args */
	"PI",		MKIFN(1),
	"ERL",		MKIFN(2),
	"ERR",		MKIFN(3),
	"TIM",		MKIFN(4),
	"SYSERR",	MKIFN(5),
	"CURKEYS",	MKIFN(6),

	"RAD",		MKOFN(0),	/* options */
	"DEG",		MKOFN(1),
	"GRAD",		MKOFN(2),
	"MEMSIZE",	MKOFN(3),
	0,0
};

const	int	typ_siz[] = {
	sizeof(double), sizeof(itype), sizeof(struct stringd)
};

#endif
