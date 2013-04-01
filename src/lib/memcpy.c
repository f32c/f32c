
__attribute__((optimize("-Os"))) void *
memcpy(int *dst, const int *src, unsigned int len)
{
	char *from = (char *) src;
	char *to = (char *) dst;
	
	for (; len != 0; len--)
		*to++ = *from++;

	return (dst);
}
