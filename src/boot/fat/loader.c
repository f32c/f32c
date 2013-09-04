
#include <sys/param.h>

#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>


static const char *bootfiles[] = {
	"/basic.bin",
	"1:/basic.bin",
	NULL
};


#define	LOADADDR 0x80000000


void
main(void)
{
	int i, fd = -1;
	char *cp = (char *) LOADADDR;

	printf("FAT bootloader v 0.1 "
#if _BYTE_ORDER == _BIG_ENDIAN
	    "(f32c/be)"
#else
	    "(f32c/le)"
#endif
	    "\n");

	for (i = 0; bootfiles[i] != NULL; i++) {
		printf("Trying %s ... ", bootfiles[i]);
		fd = open(bootfiles[i], O_RDONLY);
		if (fd > 0)
			break;
		printf("not found\n");
	}
	if (fd < 0) {
		printf("Exiting\n");
		return;
	}

	do {
		i = read(fd, cp, 65536);
		cp += i;
	} while (i > 0);
	printf("OK, loaded %d bytes\n", (int) (cp - LOADADDR));

	cp = (char *) LOADADDR;
	printf("Starting at %p\n", cp);

	__asm __volatile__(
		".set noreorder;"
		"lui $4, 0x8000;"       /* stack mask */
		"lui $5, 0x0010;"       /* top of the initial stack */
                "and $29, %0, $4;"      /* clear low bits of the stack */
		"jr %0;"
		"or $29, $29, $5;"      /* set the stack pointer */
		".set reorder;"
		: 
		: "r" (cp)
	);
}
