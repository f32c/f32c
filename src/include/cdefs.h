
#ifndef	_CDEFS_H_
#define	_CDEFS_H_


#define	__dead		__attribute__((__noreturn__))
#define	__pure		__attribute__((__const__))
#define	__unused	__attribute__((__unused__))
#define	__used		__attribute__((__used__))
#define	__packed	__attribute__((__packed__))
#define	__aligned(x)	__attribute__((__aligned__(x)))
#define	__section(x)	__attribute__((__section__(x)))

#define	__noinline	__attribute__ ((__noinline__))

#define	__predict_true(exp)	__builtin_expect((exp), 1)
#define	__predict_false(exp)	__builtin_expect((exp), 0)

#define	__offsetof(type, field)	__builtin_offsetof(type, field)

#endif	/* !_CDEFS_H_ */
