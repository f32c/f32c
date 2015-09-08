/*
 * BASIC by Phil Cockcroft
 */
/*
 *      This file contains the main routines of the interpreter.
 */


/*
 *      the core is arranged as follows: -
 * -------------------------------------------------------------------  - - -
 * | file    |  text   |  string | user  | array |  simple    |  for/ | unused
 * | buffers |   of    |  space  | def   | space |  variables | gosub | memory
 * |         | program |         | fns   |       |            | stack |
 * -------------------------------------------------------------------  - - -
 * ^         ^         ^         ^       ^       ^            ^       ^
 * filestart fendcore  ecore     estring edefns  earray       vend    vvend
 *                        ^eostring           ^estarr
 */

#define         PART1
#include        "bas.h"
#undef          PART1

extern	void	_exit();

static	CHAR    *eql(const CHAR *, const CHAR *, const CHAR *);
static	void	docont(void);
static	void	free_ar(struct entry *);

static	SIGFUNC	trap(int);
#ifndef f32c
static  SIGFUNC seger(int), mcore(int), quit1(int), catchfp(int);
#ifdef  SIGTSTP
static  SIGFUNC	onstop(int);
#endif
#endif /* !f32c */

#ifdef MSDOS
static int	lcount;
#endif

/*
 *      The main program , it sets up all the files, signals,terminal
 *      and pointers and prints the start up message.
 *      It then calls setexit().
 * IMPORTANT NOTE:-
 *              setexit() sets up a point of return for a function
 *      It saves the local environment of the calling routine
 *      and uses that environment for further use.
 *              The function reset() uses the information saved in
 *      setexit() to perform a non-local goto , e.g. poping the stack
 *      until it looks as though it is a return from setexit()
 *      The program then continues as if it has just executed setexit()
 *      This facility is used all over the program as a way of getting
 *      out of functions and returning to command mode.
 *      The one exception to this is during error trapping , The error
 *      routine must pop the stack so that there is not a recursive call
 *      on execute() but if it does then it looks like we are back in
 *      command mode. The flag ertrap is used to signal that we want to
 *      go straight on to execute() the error trapping code. The pointers
 *      must be set up before the execution of the reset() , (see error ).
 *              N.B. reset() NEVER returns , so error() NEVER returns.
 */

static int firstrun = 1;

int
main(int argc, char **argv)
{
	int i = 0;
	int fp;

#ifdef f32c
	setup_f32c();
	maxfiles = MAXFILES;
#else
	catchsignal();
#endif
	startfp();              /* start up the floating point hardware */

	setup_fb();		/* video framebuffer */
#ifndef f32c
	setupfiles(argc,argv);
	setupmyterm();		/* set up files after processing files */
#endif
	program = 0;
	clear();
	prints("Rabbit BASIC version 2.1.3 (built " __DATE__ ")\n");
	if(setexit() == ERR_RESET){
		drop_fns();
		execute();	/* execute the line */
	}
	drop_fns();
	docont();
	stocurlin=0;            /* say we are in immeadiate mode */
	if(cursor)              /* put cursor on a blank line */
		prints( (char *)nl);
	
	if (firstrun && (
#ifdef f32c
	    (fp = open("d:autoexec.bas",0)) > 0 ||
#endif
	    (fp = open("autoexec.bas",0)) > 0)) {
		firstrun = 0;
		readfi(fp, 0, 0);
		close(fp);
        	clear();
        	if (program) {
        		stocurlin=program;
        		point= program->lin;
        		elsecount=0;
        		execute();
		}
	}
	firstrun = 0;

	prints("Ready\n");

	for(;;){
		do{
			trapped=0;
			line[0] = '>';
			line[1] = 0;
			VOID edit( (ival)1, (ival)1, (ival)0);
		}while( trapped || ( !(i=compile(1, nline, 0)) && !linenumber));
		if(!linenumber)
			break;
		insert(i);
	}
	if(inserted){
		inserted=0;
		clear();
		closeall();
	}

#ifdef MSDOS
	lcount = 0;
#endif
	clr_stack(bstack);	/* reset the gosub stack */
	bstack = estack = 0;
	if(str_used)		/* free any spare strings */
		FREE_STR(str_used);

	trap_env.e_stolin = 0;	/* disable error traps */
	intrap=0;               /* say we are not in the error trap */
	trapped=0;              /* say we haven't got a cntrl-c */
	cursor=0;               /* cursor is at start of line */
	elsecount=0;            /* disallow elses as terminators */
	point=nline;            /* start executing at start of input line */
	stocurlin=0;            /* start of current line is null- see 'next' */
	execute();              /* execute the line */
	return(-1);             /* see note below */
}

/*
 *      Execute will return by calling reset and so if execute returns then
 *    there is a catastrophic error and we should exit with -1 or something
 */

/*
 *      compile converts the input line (in line[]) into tokenised
 *    form for execution(in nline). If the line starts with a linenumber
 *    then that is converted to binary and is stored in 'linenumber' N.B.
 *    not curline (see evalu() ). A linenumber of zero is assumed to
 *    be non existant and so the line is executed immeadiately.
 *      The parameter to compile() is an index into line that is to be
 *    ignored, e.g. the prompt.
 */


int
compile(fl, fline, hasnolnumb)
int     fl, hasnolnumb;
CHAR	*fline;
{
	CHAR   *p, *k, *q;
	const	struct tabl    *l;
	lnumb	lin=0;
	CHAR	*tmp;
	CHAR    charac;

	p= &line[fl];
	q=fline;
	while(*p ==' ')
		p++;
	if(!hasnolnumb){
		/*LINTED*/
		while(isdigit(*p)){                    /* get line number */
			if(lin >= 6553)
				error(7);
			lin = lin*10 + (*p++ -'0');
		}
		while(*p==' ')
			*q++ = *p++;
	}
	if(!*p){
		*q = 0;
		linenumber =lin;
		return(0);      /* no characters on the line */
	}
	while(*p){
		/*LINTED*/
		if(!isalpha(*p)){
			/* not a keyword. check for special characters */
			switch(*p++){
			case '"':
			case '`':	/* quoted strings */
				*q++ = charac = *(p-1);
				while(*p && *p != charac)
					*q++ = *p++;
				if(*p)
					*q++ = *p++;
				continue;
			case '?':
				*q++ = (CHAR)QPRINT;
				continue;
			case '\'':	/* a rem statement */
				*q++ = (CHAR)QUOTE;
				while(*p)
					*q++ = *p++;
				continue;
			case '<':
				if(*p == '='){
					*q++ = (CHAR)LTEQ;
					p++;
					continue;
				}
				if(*p == '>'){
					*q++ = (CHAR)NEQE;
					p++;
					continue;
				}
				break;
			case '>':
				if(*p == '='){
					*q++ = (CHAR)GTEQ;
					p++;
					continue;
				}
				break;
			case '=':
				if(*p == '='){
					*q++ = (CHAR)APRX;
					p++;
					continue;
				}
				break;
			}
			*q++ = *(p-1);
			continue;
		}
		/*
		 * now do a quick check on the first character
		 */
		charac = toupper(*p);
		
		for(l = table ; l->string ; l++)
			if(charac == *l->string)
				break;
		/*
		 * not found. not a keyword
		 */
		if(l->string == 0){
			*q++ = *p++;
			/*LINTED*/
			while(isalpha(*p))
				*q++ = *p++;
			continue;
		}
		/*
		 * get the length of the word
		 */
		/*LINTED*/
		for(k = p, p++ ; isalnum(*p) || *p == '_'; p++);

		/* special case for FN */
		if(p >= k + 2 && charac == 'f' && tolower(k[1]) == 'n'){
			/*
			 * and make certain it isn't fnend
			 */
			if(p != k+5 || tolower(k[2]) != 'e' ||
				tolower(k[3]) != 'n' || tolower(k[4]) != 'd'){
				*q++ = (CHAR)FN;
				for(k += 2; k < p ;)
					 *q++ = *k++;
				continue;
			}
		}
		if(*p == '$')
			p++;
		/*
		 * check entry in the table
		 */
		for(; l->string ; l++)
			if (charac == *l->string &&
				    (tmp = eql(k, l->string, p)) != 0){
				if(l->chval > 0377){
					*q++ = (CHAR)(EXFUNC + (l->chval >> 8));
					*q++ = (CHAR)(l->chval & MASK);
				}
				else
					*q++ = (CHAR)l->chval;
				p = tmp;
				if(l->chval == DATA || l->chval == REM)
					while(*p)
						*q++ = *p++;
				break;
			}
		if(!l->string)
			while(k < p)
				*q++ = *k++;
	}
	*q='\0';
	linenumber=lin;
	return(q-fline);                /* return length of line */
}

/*
 *      eql() returns true if the strings are the same .
 *    this routine is only called if the first letters are the same.
 *    hence the increment of the pointers , we don't need to compare
 *    the characters they point to.
 *      To increase speed this routine could be put into machine code
 *    the overheads on the function call and return are excessive
 *    for what it accomplishes. (it fails most of the time , and
 *    it can take a long time to load a large program ).
 */

static CHAR *
eql(p, q, end)
const CHAR   *p, *q, *end;
{
	p++, q++;
	while(p < end){
		if(*p != *q && tolower(*p) != tolower(*q))
			return(0);
		p++, q++;
	}
#ifndef	NO_SCOMMS
	if(*p == '.' && *q)
		return((char *) &p[1]);
#endif
	if(*q)
		return(NULL);
	return((char *) p);
}

/*
 *      Puts a line in the table of lines then sets a flag (inserted) so that
 *    the variables are cleared , since it is very likely to have moved
 *    'ecore' and so the variables will all be corrupted. The clearing
 *    of the variables is not done in this routine since it is only needed
 *    to clear the variables once and that is best accomplished in main
 *    just before it executes the immeadiate mode line.
 *      If the line existed before this routine is called then it is deleted
 *    and then space is made available for the new line, which is then
 *    inserted.
 *      The structure of a line in memory has the following structure:-
 *              struct olin{
 *                      unsigned linnumb;
 *                      unsigned llen;
 *                      char     lin[1];
 *                      }
 *      The linenumber of the line is stored in linnumb , If this is zero
 *    then this is the end of the program (all searches of the line table
 *    terminate if it finds the linenumber is zero.
 *      The variable 'llen' is used to store the length of the line (in
 *    characters including the above structure and any padding needed to
 *    make the line an even length.
 *      To search through the table of lines then:-
 *    XXXX g it as a variable
 *    length array ( impossible in 'pure' C ).
 *      The pointers used by the program storage routines are:-
 *              fendcore = start of text storage segment
 *              ecore = end of text storage
 *                    = start of data segment (string space ).
 *    strings are stored after the text but before the numeric variables
 *    only 512 bytes are allocated at the start of the program for strings
 *    but clear can be called to get more core for the strings.
 */

void
insert(lsize)
int    lsize;
{
	lpoint p, op;
	lnumb	l;

	inserted=1;                  /* say we want the variables cleared */
	l= linenumber;
	last_ins_line = 0;
	for(op = 0, p = program; p ; op = p, p = p->next)
		if(p->linnumb >= l){
			if(p->linnumb != l){
				if(p->linnumb == CONTLNUMB)
					continue;
				break;
			}
			if(!op)
				program = p->next;
			else
				op->next = p->next;
			mfree( (MEMP)p);
			break;
		}
	if(!lsize)	/* if no line to put in just ignore */
		return;
	ins_line(op, lsize);
}

void
ins_line(op, lsize)
lpoint op;
int	lsize;
{
	lpoint p;
							/* align the length */
	/*
	 * no longer needed.
	 *
	lsize = (lsize + sizeof(struct olin) + WORD_SIZ - 1) & ~WORD_MASK;
	 */
	lsize += sizeof(struct olin);

	p = mmalloc((ival)lsize);
	VOID str_cpy(nline, p->lin);    /* move the line into the space */
	p->linnumb = linenumber;        /* give it a linenumber */
	if(!op){
		p->next = program;
		program = p;
	}
	else {
		p->next = op->next;
		op->next = p;
	}
	last_ins_line = p;
}

/*
 *      The interpreter needs three variables to control the flow of the
 *    the program. These are:-
 *              stocurlin : This is the pointer to the start of the current
 *                          line it is used to index the next line.
 *                          If the program is in immeadiate mode then
 *                          this variable is NULL (very important for 'next')
 *              point:      This points to the current location that
 *                          we are executing.
 *              curline:    The current line number ( zero in immeadiate mode)
 *                          this is not needed for program exection ,
 *                          but is used in error etc. It could be made faster
 *                          if this variable is not used....
 */

/*
 *      The main loop of the execution of a program.
 *      It does the following:-
 *              FOR(ever){
 *                      save point so that resume will go to the right place
 *                      IF cntrl-c THEN stop
 *                      IF NOT a reserved word THEN do_assignment
 *                              ELSE IF legal command THEN execute_command
 *                      IF return is NORMAL THEN
 *                              BEGIN
 *                                  IF terminator is ':' THEN continue
 *                                  ELSE IF terminator is '\0' THEN
 *                                         goto next line ; continue
 *                                  ELSE IF terminator is 'ELSE' AND
 *                                              'ELSES' are enabled THEN
 *                                                  goto next line ; continue
 *                              END
 *                      ELSE IF return is < NORMAL THEN continue
 *                                      ( used by goto etc. ).
 *                      ELSE IF return is > NORMAL THEN
 *                           ignore_rest_of_line ; goto next line ; continue
 *                      }
 *      All commands return a value ( if they return ). This value is NORMAL
 *    if the command is standard and does not change the flow of the program.
 *    If the value is greater than zero then the command wants to miss the
 *    rest of the line ( comments and data ).
 *      If the value is less than zero then the program flow has changed
 *    and so we should go back and try to execute the new command ( we are
 *    now at the start of a command ).
 */

void
execute()
{
	int    c, i = NORMAL;
	lpoint p;

	for(;;){
#ifdef MSDOS
		if(++lcount > 100){
			lcount = 0;
			if(CHK_KEY())
				trap(0);
		}
#endif
#ifdef f32c
		if (sio_getchar(0) == 3)
			trap(0);
#endif
		savepoint=point;
		if(trapped)
			dobreak();
		if(tron_flag && stocurlin)
			prsline("**", stocurlin);

		if( ((c = getch()) & SPECIAL) == 0){
			if(!c)
				i = GTO;
			else {
				point--;
				assign(ISFUNC|IS_MPR);
				i = NORMAL;
			}
		}
		else {
			if (c == EXCMD) {
				c = getch();
				/* execute the command */
				i = (*xcmdf[c&0177])();
			} else if(c >= MAXCOMMAND)
				error(8);
			else {
				/* execute the command */
				i = (*commandf[c&0177])();
			}
#ifndef f32c
			update_x11(0);
#endif
		}
		if(i == NORMAL){
			if((c=getch())==':')
				continue;	/* `else` is a terminator */
			if(c && (c != ELSE || !elsecount))
				error(SYNTAX);
		}
		else if(i < NORMAL)
			continue;
		
		if(stocurlin){            /* not in immeadiate mode */
			p = stocurlin->next;	/* goto next line */
			stocurlin=p;
			if(p){
				point=p->lin;
				elsecount=0;            /* disable `else`s */
				continue;
			}
		}
		break;
	}
	reset();				/* end of program */
}

/*
 * save the current running environment
 */

void
save_env(e)
struct	env	*e;
{
	e->e_point = point;
	e->e_stolin = stocurlin;
	e->e_ertrap = trap_env.e_stolin;
	e->e_elses = elsecount;
}

/*
 * save the current running environment
 */

void
ret_env(e)
struct	env	*e;
{
	point = e->e_point;
	stocurlin = e->e_stolin;
	trap_env.e_stolin = e->e_ertrap;
	elsecount = e->e_elses;
}

/*
 *      The error routine , this is called whenever there is any error
 *    it does some tidying up of file descriptors and sets the error line
 *    number and the error code. If there is error trapping ( errortrap is
 *    non-zero and in runmode ), then save the old pointers and set up the
 *    new pointers for the error trap routine.
 *    Otherwise print out the error message and the current line if in
 *    runmode.
 *      Finally call reset() ( which DOES NOT return ) to pop
 *    the stack and to return to the main routine.
 */

static	const	char	_on_line_[] = " on line ";

void
error(i)
int     i;                      /* error code */
{
	forstp	fp;

	if(newentry){
		drop_val(newentry, 1);
		newentry = 0;
	}
	if(readfile){                   /* close file descriptor */
		VOID close(readfile);   /* from loading a file */
		readfile=0;
	}
	if(renstr != 0){
		mfree(renstr);
		renstr = 0;
	}
	if(str_used)
		FREE_STR(str_used);
	evallock=0;                     /* stop the recursive eval message */
	fnlock = 0;
	ecode=i;                        /* set up the error code */
	if(stocurlin)
		elinnumb = getrline(stocurlin);/* set up the error line number*/
	else
		elinnumb=0;
					/* we have error trapping */
	if(stocurlin && trap_env.e_stolin && !inserted){
		point = savepoint;	/* go back to start of command */
		save_env(&err_env);
		ret_env(&trap_env);
		intrap=1;               /* say we are trapped */
		/*
		 * return to enclosing function level. (if any)
		 */
		for(fp = estack ; fp ; fp = fp->prev)
			if(fp->fortyp == FNTYP){
				str_used = fp->fnSBEG;
				str_uend = fp->fnSEND;
				longjmp(fp->fnenv, ERR_RESET);
			}
		errreset();             /* no return - goes to main */
	}
	else  {                         /* no error trapping */
		if(cursor){
			prints( (char *)nl);
			cursor=0;
		}
		prints( (char *)ermesg[i-1]);		/* error message */
		if(stocurlin)
			prsline(_on_line_, stocurlin);
		prints( (char *)nl);
		reset();                /* no return - goes to main */
	}
}

void
c_error(err)
int	err;
{
	if(trap_env.e_stolin != 0 && stocurlin && !inserted)
		error(err);
	if(cursor){
		prints( (char *)nl);
		cursor=0;
	}
	prints("Warning: ");
	prints( (char *)ermesg[err-1]);		/* error message */
	if(stocurlin)
		prsline(_on_line_, stocurlin);
	prints( (char *)nl);
}


/*
 *      This is executed by the ON ERROR construct it checks to see
 *    that we are not executing an error trap then set up the error
 *    trap pointer.
 */

void
errtrap()
{
	lpoint p;
	lnumb	l;

	l=getlin();
	if(l == NOLNUMB)
		error(SYNTAX);
	check();
	if(intrap)
		error(8);
	if(l == 0){
		trap_env.e_stolin = 0;
		return;
	}
	p = getsline(l);
	trap_env.e_stolin = p;
	trap_env.e_point = p->lin;
	trap_env.e_ertrap = 0;
	trap_env.e_elses = 0;
}

/*
 *      The 'resume' command , checks to see that we are actually
 *    executing an error trap. If there is an optional linenumber then
 *    we resume from there else we resume from where the error was.
 */

int
resume()
{
	lpoint p;
	lnumb	i;
	int	c;

	if(!intrap)
		error(8);
	c = getch();
	if(c != NEXT){
		point--;
		i= getlin();
	}
	else
		i = 0;
	check();
	if(i != NOLNUMB && i != 0){
		p = getsline(i);
		ret_env(&err_env);
		stocurlin= p;                   /* resume at that line */
		point= p->lin;
		elsecount=0;
	}
	else {
		ret_env(&err_env);
		if(c == NEXT){
			if( (p = stocurlin->next) == 0)
				reset();
			stocurlin= p;          /* resume at next line */
			point= p->lin;
			elsecount=0;
		}
	}
	intrap=0;                               /* get out of the trap */
	return(-1);                             /* return to re-execute */
}

/*
 *      The 'error' command , this calls the error routine ( used in testing
 *    an error trapping routine.
 */

int
doerror()
{
	itype	i;

	i=evalint();
	check();
	if(i<1 || i >MAXERR)
		error(22);      /* illegal error code */
	error( (int)i);
	normret;
}

int
tron()
{
	tron_flag = 1;
	normret;
}

int
troff()
{
	tron_flag = 0;
	normret;
}

/*
 *      This routine is used to clear space for strings and to reset all
 *    other pointers so that it effectively clears the variables.
 */

void
clear()
{
	/*
	 * reset the gosub stack, clear the stack before the symbol
	 * table, because of multiline functions and ncall
	 */
	clr_stack(savbstack);
	clr_stack(bstack);
	savestack = savbstack = bstack = estack = 0;

	set_mem(tcharmap, (ival)TMAPSIZ, RVAL);
	/*
	 * clear the variables
	 */
	clear_htab(&hshtab);
	/*
	 * free any spare string blocks
	 */
	DROP_STRINGS();

	datastolin = 0;		/* reset the pointer to data */
	datapoint = 0;		/* reset the pointer to data */
	contpos = 0;
}


/*
 * free one entry
 */
void
free_entry(op)
struct	entry	*op;
{
	if(op->vtype == UNK_VAL){
		mfree( (MEMP)op);
		return;
	}
	if(op->dimens){
		if(op->vtype == SVAL)
			free_ar(op);
		mfree( (MEMP)op->_darr);
	}
	else if(op->vtype & ISFUNC){
		if(op->_deffn != 0)
			mfree( (MEMP)op->_deffn);
	}
	else if(op->vtype == SVAL && !(op->flags & IS_FSTRING)){
		if(op->_dstr != 0)
			mfree( (MEMP)op->_dstr);
	}
	mfree( (MEMP)op);
}

static	void
free_ar(op)
struct	entry	*op;
{
	int	j = 1;
	stringp sp;
	int	i;

	for(i = 0 ; i < op->dimens ; i++)
		j *= op->_dims[i];
	/*LINTED pointer conversion */
	for(sp = (stringp)op->_darr ; j ; sp++, j--)
		if(sp->str)
			mfree( (MEMP)sp->str);
}

/* clear the hash table*/

void
clear_htab(htab)
struct	hash	*htab;
{
	struct entry   **p, *op;
	int	i = 0;

	for(p = htab->hasht ; i < HSHTABSIZ ; i++, p++)
		while( (op = *p) != 0){
			*p = op->link;
			free_entry(op);
		}
}

void
clr_stack(sptr)
forstp	sptr;
{
	forstp np;
	struct	entry	*ep;

	while(sptr){
		if(sptr->fortyp == FNTYP){
			ep = sptr->fnvar;
			ep->_deffn->ncall--;
			if(ep->vtype == SVAL && ep->_deffn->mline == IS_MFN){
				if(sptr->fnsval.str != 0){
					mfree( (MEMP)sptr->fnsval.str);
					sptr->fnsval.str = 0;
				}
			}
			if(sptr->fnLOCAL)
				recover_vars(sptr, 1);
			if(str_used)
				FREE_STR(str_used);
			str_used = sptr->fnSBEG;
			str_uend = sptr->fnSEND;
		}
		np = sptr->next;
		mfree( (MEMP)sptr);
		sptr = np;
	}
}

/*
 * when closing a blocked file. zap all fstring variables.
 * do this quickly by just resetting the bit and then setting their
 * pointers to zero
 */

void
kill_fstrs(bstr, estr)
CHAR	*bstr, *estr;
{
	struct entry   **p, *op;

	for(p = hshtab.hasht ; p < &hshtab.hasht[HSHTABSIZ]; p++)
		for(op = *p ; op ; op = op->link)
			if( (op->flags & IS_FSTRING) == 0)
				continue;
			else if(op->_dstr >= bstr && op->_dstr < estr){
				op->flags &= ~IS_FSTRING;
				op->_dstr = 0;
				op->_dslen = 0;
			}
}

/*
 * drop all variables which are not common, only used in chain
 */
void
ch_clear(doall)
int	doall;
{
	struct	hash	tmphshtab;
	struct	entry	**p, **q;
	struct	entry	*ep, **nep, **neq, *tep = 0;

	q = tmphshtab.hasht;
	for(p = hshtab.hasht ; p < &hshtab.hasht[HSHTABSIZ] ; p++, q++){
		ep = *p;
		neq = q;
		nep = p;
		for(*neq = *nep = 0 ; ep ; ep = tep){
			tep = ep->link;
			ep->link = 0;
			if(!doall && (ep->flags & IS_COMMON) == 0){
				*nep = ep;
				nep = &ep->link;
			}
			else {
				*neq = ep;
				neq = &ep->link;
			}
		}
	}
	clear();
	hshtab = tmphshtab;
}

void
add_entry(op)
struct	entry	*op;
{
	int	i;

	i = MKhash(op->ln_hash);
	op->link = hshtab.hasht[i];
	hshtab.hasht[i] = op;
}

/*
 *      mtest() is used to set the amount of core for the current program
 *    it uses brk() to ask the system for more core.
 *      The core is allocated in 1K chunks, this is so that the program does
 *    not spend most of is time asking the system for more core and at the
 *    same time does not hog more core than is neccasary ( be friendly to
 *    the system ).
 *      Any test that is less than 'ecore' is though of as an error and
 *    so is any test greater than the size that seven memory management
 *    registers can handle.
 *      If there is this error then a test is done to see if 'ecore' can
 *    be accomodated. If so then that size is allocated and error() is called
 *    otherwise print a message and exit the interpreter.
 *      If the value of the call is less than 'ecore' we have a problem
 *    with the interpreter and we should cry for help. (It doesn't ).
 */

void *
mmalloc(len)
ival	len;
{
	void	*p;

	if ((p = malloc((unsigned int)len)) != NULL)
		return(p);
	clear();
	if ((p = malloc((unsigned int)len)) != NULL)
		return(p);
	prints("out of core\n");        /* print message */
	VOID quit();                    /* exit flushing buffers */
	NO_RET;				/* should never be reached */
}

void
mfree(mem)
MEMP	mem;
{

	free( (void *)mem);
}

int
mtestalloc(len)
ival	len;
{
	void	*p;

	if( (p = malloc((unsigned int)len)) != NULL) {
		mfree(p);
		return (1);
	}
	return (0);
}


/*
 *      This routine tries to set up the system to catch all the signals that
 *    can be produced. (except kill ). and do something sensible if it
 *    gets one. ( There is no way of producing a core image through the
 *    sending of signals).
 */

#ifndef f32c
#ifndef	MSDOS
/*ARGSUSED*/
static	SIGFUNC	squit(int x) { VOID quit(); }
static	SIGFUNC sexit(int x) { _exit(x); }
#endif

static	const	struct	mysigs {
	int	sigval;
	SIGFUNC	(*sigfunc)(int);
} traps[] = {
#ifndef	MSDOS
	{SIGHUP, 	squit},           /* hang up */
#endif
	{SIGINT,	trap},
#ifndef	MSDOS
	{SIGQUIT, 	quit1},
	{SIGILL,	sexit},
	{SIGTRAP, 	sexit},
	{SIGIOT, 	sexit},
#ifdef	SIGEMT
	{SIGEMT, 	sexit},
#endif
	{SIGFPE,	catchfp},	/* fp exception */
	/* SIGKILL, 0,			/ * kill    */
	{SIGBUS,	seger},		/* seg err */
	{SIGSEGV, 	mcore},         /* bus err */
	/* SIGSYS,	0, */
	{SIGPIPE,	sexit},
	{SIGALRM,	squit},
	{SIGTERM,	sexit},
	{SIGUSR1,	sexit},
#ifdef	SIGUSR2
	{SIGUSR2,	sexit},
#endif
#ifdef	SIGTSTP
	{SIGTSTP,	onstop},
#endif
#endif
};

void
catchsignal()
{
	const	struct mysigs	*sp;

	for(sp = traps ; sp < &traps[sizeof(traps) / sizeof(traps[0])]; sp++)
		if(sp->sigval)
			VOID signal(sp->sigval, sp->sigfunc);
}

/*
 *      this routine deals with floating exceptions via fpfunc
 *    this is a function pointer set up in fpstart so that trapping
 *    can be done for floating point exceptions.
 */

/*ARGSUSED*/
static	SIGFUNC
catchfp(x)
int	x;
{
#ifndef	MSDOS
	VOID signal(SIGFPE,catchfp); /* restart catching */
#endif
	if(fpfunc== 0)          /* this is set up in fpstart() */
		_exit(1);
	(*fpfunc)();
}

/*
 *      we have a segmentation violation and so should print the message and
 *    exit. Either a kill() from another process or an interpreter bug.
 */

/*ARGSUSED*/
static	SIGFUNC
seger(x)
int	x;
{
	prints("segmentation violation\n");
	_exit(-1);
	/*NOTREACHED*/
}

/*
 *      This does the same for bus errors as seger() does for segmentation
 *    violations. The interpreter is pretty nieve about the execution
 *    of complex expressions and should really check the stack every time,
 *    to see if there is space left. This is an easy error to fix, but
 *    it was not though worthwhile at the moment. If it runs out of stack
 *    space then there is a vain attempt to call mcore() that fails and
 *    so which produces another bus error and a core image.
 */

/*ARGSUSED*/
static	SIGFUNC
mcore(x)
int	x;
{
	prints("bus error\n");
	_exit(-1);
	/*NOTREACHED*/
}
#endif /* !f32c */

/*
 *      Called by the cntrl-c signal (number 2 ). It sets 'trapped' to
 *    signify that there has been a cntrl-c and then re-enables the trap.
 *      It also bleeps at you.
 */

/*ARGSUSED*/
static	SIGFUNC
trap(x)
int	x;
{
	VOID signal(SIGINT, SIG_IGN);/* ignore signal for the bleep */
	VOID write(1, "\07", 1);     /* bleep */
	VOID signal(SIGINT, trap);   /* re-enable the trap */
	trapped=1;              /* say we have had a cntrl-c */
#ifdef	SIG_JMP
	if(ecalling){
		ecalling = 0;
		longjmp(ecall, 1);
		/*NOTREACHED*/
	}
#endif
}

#ifndef f32c
/*
 *      called by cntrl-\ trap , It prints the message and then exits
 *    via quit() so flushing the buffers, and getting the terminal back
 *    in a sensible mode.
 */

/*ARGSUSED*/
static	SIGFUNC
quit1(x)
int	x;
{
#ifndef	MSDOS
	VOID signal(SIGQUIT,SIG_IGN);/* ignore any more */
#endif
	if(cursor){             /* put cursor on a new line */
		prints( (char *)nl);
		cursor=0;
	}
	prints("quit\n\r");     /* print the message */
	VOID quit();            /* exit */
}
#endif /* !f32c */

/*
 *      resets the terminal , flushes all files then exits
 *    this is the standard route exit from the interpreter. The seger()
 *    and mcore() traps should not go through these traps since it could
 *    be the access to the files that is causing the error and so this
 *    would produce a core image.
 *      From this it may be gleened that I don't like core images.
 */

int
quit()
{
	flushall();                     /* flush the files */
#if 0 // XXX #ifndef f32c
	rset_term(1);
#endif
	if(cursor)
		prints( (char *)nl);
	exit(0);                       /* goodbye */
	normret;
}

static	void
docont()
{
	if(stocurlin){
		contpos=0;
		clr_stack(savbstack);
		if(cancont){
			savestack = estack;
			savbstack = bstack;
			bstack = estack = 0;
			contpos=cancont;
		}
		else
			savbstack = savestack = 0;
	}
	cancont=0;
}

#ifndef f32c
#ifdef  SIGTSTP
extern	int	kill(pid_t, int);
/*
 * support added for job control
 */
/*ARGSUSED*/
static	SIGFUNC
onstop(x)
int	x;
{
	flushall();                     /* flush the files */
	if(cursor){
		prints( (char *)nl);
		cursor = 0;
	}
#ifdef  SIG_JMP
	VOID sigsetmask(0);                  /* Urgh !!!!!! */
#endif
	VOID signal(SIGTSTP, SIG_DFL);
	VOID kill(0,SIGTSTP);
	/* The PC stops here */
	VOID signal(SIGTSTP,onstop);
}
#endif
#endif /* !f32c */
