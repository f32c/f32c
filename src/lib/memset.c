
__attribute__((optimize("-Os"))) void *
memset(char *b, int c, unsigned int len)
{

	for (; len != 0; len--)
		*b++ = c;

	return (b);
}
