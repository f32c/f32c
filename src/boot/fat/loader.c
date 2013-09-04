
#include <sys/param.h>

#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>


static const char *bootfiles[] = {
	"1:/boot/bootme.bin",
	"/boot/kernel",
	"/boot/basic.bin",
	NULL
};


#define LOAD_COOKIE	0x10adc0de

#define	LOADADDR	0x80000000


void
main(void)
{
	int i, fd = -1;
	char *cp = (char *) LOADADDR;

	printf("ULX2S FAT bootloader v 0.1 "
#if _BYTE_ORDER == _BIG_ENDIAN
	    "(f32c/be)"
#else
	    "(f32c/le)"
#endif
	    "\n");

	if (*((int *) cp) == LOAD_COOKIE) {
		printf("Trying %s... ", &cp[4]);
		fd = open(&cp[4], O_RDONLY);
		if (fd < 0)
			printf("not found\n");
	}

	for (i = 0; fd < 0 && bootfiles[i] != NULL; i++) {
		printf("Trying %s... ", bootfiles[i]);
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

	printf("Invalidating I-cache...\n");
	cp = (char *) LOADADDR;
	for (i = 0; i < 8192; i += 4, cp += 4) {
		__asm __volatile__(
			"cache	0, 0(%0)"
			: 
			: "r" (cp)
		);
	}

	cp = (char *) LOADADDR;
	printf("Starting at %p\n", cp);

	__asm __volatile__(
		".set noreorder;"
		"lui $4, 0x8000;"	/* stack mask */
		"lui $5, 0x0010;"	/* top of the initial stack */
                "and $29, %0, $4;"	/* clear low bits of the stack */
                "move $31, $0;"		/* return to ROM loader when done */
		"jr %0;"
		"or $29, $29, $5;"      /* set the stack pointer */
		".set reorder;"
		: 
		: "r" (cp)
	);
}
