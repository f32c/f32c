

__attribute__((optimize("-Os"))) int
atoi(const char *c)
{
	int i = 0;
	int sign = 1;

	if (*c == '-') {
		sign = -1;
		c++;
	}
	for (; *c != '\0'; c++) {
		if (*c >= '0' && *c <= '9')  
			i = i * 10 + (*c - '0');
		else
			break;
	}

	return (sign * i);
}
