
#ifndef	_TYPES_H_
#define	_TYPES_H_

/* types and consts */
#define	NULL		((void *) 0)
#define	true		1
#define	false		0

typedef	__signed char		__int8_t;
typedef	unsigned char		__uint8_t;
typedef	short			__int16_t;
typedef	unsigned short		__uint16_t;
typedef	int			__int32_t;
typedef	unsigned int		__uint32_t;
typedef	long long		__int64_t;
typedef	unsigned long long	__uint64_t;

typedef	__int32_t		__intptr_t;
typedef	__uint32_t		__uintptr_t;

typedef	__uint8_t		u_char;
typedef	__uint16_t		u_short;
typedef	__uint32_t		u_int;
typedef	__uint64_t		u_long;

/* POSIX sized integers */
typedef	__int8_t		int8_t;
typedef	__int16_t		int16_t;
typedef	__int32_t		int32_t;
typedef	__int64_t		int64_t;
typedef	__uint8_t		uint8_t;
typedef	__uint16_t		uint16_t;
typedef	__uint32_t		uint32_t;
typedef	__uint64_t		uint64_t;
typedef	__intptr_t		intptr_t;
typedef	__uintptr_t		uintptr_t;

/* Byteorder manipulation null-macros */
#define	htonl(x)		(x)
#define	htons(x)		(x)
#define	ntohl(x)		(x)
#define	ntohs(x)		(x)

#endif /* !_TYPES_H_ */

