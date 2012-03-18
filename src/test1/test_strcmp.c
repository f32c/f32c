
#include <sys/param.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>


int
ref_strcmp(const char *s1, const char *s2)
{

	while (*s1 == *s2++)
		if (*s1++ == 0)
			return (0);
	return (*(const unsigned char *)s1 - *(const unsigned char *)(s2 - 1));
}


int
main(void)
{
	char a[32], b[32];
	int i, j;

	printf("\n");

	do {
		for (i = 0; i < 31; i++) {
			a[i] = (random() & 0x3f) + ' ';
			b[i] = a[i];
		}

		if (((i = random()) & 0xff00) == 0xff00)
			a[i & 0x1f] = (random() & 0x3f) + ' ';

		a[(random() >> 3) & 0x1f] = 0;
		b[(random() >> 3) & 0x1f] = 0;

		i = strcmp(a, b);
		if (i < 0)
			i = -1;
		if (i > 0)
			i = 1;
		j = ref_strcmp(a, b);
		if (j < 0)
			j = -1;
		if (j > 0)
			j = 1;

		if (i != j)
			printf("%s\n%s\n%d %d\n", a, b,
			    strcmp(a, b), ref_strcmp(a, b));
	} while (1);

	return(0);
}
