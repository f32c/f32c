
__attribute__((optimize("-Os"))) void *
memset(char *b, int c, unsigned int len)
{

	while (len != 0) {
		*b++ = c;
		len--;
	}

	return (b);
}
