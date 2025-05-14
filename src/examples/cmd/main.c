#include <unistd.h>

extern void cli(void);

int
main(void)
{
	char line[128];

	/* XXX automount fatfs */
	getcwd(line, 128);

	cli();
}
