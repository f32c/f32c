
#ifndef _STRING_H_
#define _STRING_H_

#define strcpy(dst, src) 					\
	if (sizeof(src) != sizeof(void *))			\
		memcpy((dst), (src), sizeof(src));		\
	else							\
		_strcpy(dst, src);				\

void memcpy(char *, const char *, int);

#endif /* !_STRING_H_ */
