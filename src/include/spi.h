
#ifndef _SPI_H_
#define	_SPI_H_

#include <io.h>

#define	SPI_PORT_FLASH		0
#define	SPI_PORT_SDCARD		4

#define	spi_start_transaction(port)					\
	SB(SPI_CEN | SPI_SI, IO_SPI_FLASH, port)

int spi_byte(int, int);
int spi_byte_in(int);

#endif /* !_SPI_H_ */

