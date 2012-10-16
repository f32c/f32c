
#include <sys/param.h>
#include <io.h>
#include <sio.h>

#include <mips/asm.h>
#include <mips/cpuregs.h>


/*
 * Set RS-232 baudrate.  Works well with FT-232R from 300 to 3000000 bauds.
 */
__attribute__((optimize("-Os"))) void
sio_setbaud(int bauds)
{
	uint32_t val, freq_khz;

	mfc0_macro(val, MIPS_COP_0_CONFIG);
	freq_khz = ((val >> 16) & 0xfff) * 1000 / ((val >> 29) + 1);

	val = bauds;
	if (bauds > 1000000)
		val /= 10;
	val = val * 1024 / 1000 * 1024 / freq_khz + 1;
	if (bauds > 1000000)
		val *= 10;
	if (bauds > 460800 && bauds <= 1500000)
		val = val * 9 / 10;
	if (bauds == 1500000)
		val = val * 9 / 10;
	OUTH(IO_SIO_BAUD, val);
}
