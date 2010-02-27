

#define	_C_LABEL(x)	x

#define	GLOBAL(sym)						\
	.globl sym; sym:

#define	ENTRY(sym)						\
	.text; .globl sym; .ent sym; sym:

#define	ASM_ENTRY(sym)						\
	.text; .globl sym; .type sym,@function; sym:

#define	IMPORT(sym, size)	\
	.extern _C_LABEL(sym),size

#define	EXPORT(x)		\
	.globl	_C_LABEL(x);	\
	_C_LABEL(x):

