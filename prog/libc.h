

void bcopy(const char *, char *, int);
void memset(char *, int, int);
int strlen(const char *);
int msleep(int);
unsigned int mul(unsigned int, unsigned int);
unsigned int div(unsigned int, unsigned int, unsigned int *);
unsigned int random();
char *itoa(int, char *);
void itox(int, char *);

/* va_arg stuff */
typedef	__builtin_va_list	__va_list;
typedef	__va_list		va_list;
#define	va_start(ap, last)	__builtin_va_start((ap), (last))
#define	va_arg(ap, type)	__builtin_va_arg((ap), type)
#define	va_copy(dest, src)	__builtin_va_copy((dest), (src))
#define	va_end(ap)		__builtin_va_end(ap)

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

typedef	__uint8_t		u_char;

extern int keymask;
extern int newkey;
extern int oldkey;
extern int rotpos;

