/*
 * BASIC by Phil Cockcroft
 */
/*
 * terminal specific configuration routines for 80386's
 */

#include <termios.h>

#define	DEFWIDTH 80

static	struct	termios	oterm, nterm;

extern  int     ter_width;
extern  char    noedit;

static  int     got_mode;

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
