/*
 * BASIC by Phil Cockcroft
 */

#include <unistd.h>
#include <termios.h>

#include "bas.h"

#define	DEFWIDTH 80

extern	int	ter_width;
extern	char	noedit;

static	struct	termios	oterm, nterm;
static	int	got_mode;

int
bas_exec(void)
{
	/* XXX do nothing - revisit! */
	normret;
}

int
bauds(void)
{
	/* do nothing */
	normret;
}

int
bas_sleep(void)
{

	evalreal();
	check();
	if (res.f < ZERO)
		error(33);	/* argument error */
	usleep(res.f * 1000000.0);

	normret;
}

/*
 * terminal specific configuration routines for 80386's
 */
void

setu_term()
{
	(void) tcgetattr(0, &oterm);
	nterm = oterm;

	nterm.c_lflag &= ~(ECHO|ECHOK|ECHONL|ICANON);
	nterm.c_lflag |= ISIG;
	nterm.c_oflag &= ~OPOST;
	nterm.c_iflag &= ~(IGNCR|INLCR|ICRNL);
	nterm.c_iflag |= ISTRIP;
	nterm.c_cc[VMIN] = 1;
	nterm.c_cc[VTIME] = 0;
	if(ter_width <= 0)
		ter_width=DEFWIDTH;
	got_mode = 1;
}

void
set_term()
{
	if(noedit || !got_mode)
		return;

	(void) tcsetattr(0, TCSADRAIN, &nterm);
}

/*ARGSUSED*/
void
rset_term(type)
int	type;
{
	if(noedit || !got_mode)
		return;

	(void) tcsetattr(0, TCSADRAIN, &oterm);
}
