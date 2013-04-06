
#ifndef _SPI_H_
#define	_SPI_H_

#include <io.h>

#define	SPI_PORT_FLASH		0
#define	SPI_PORT_SDCARD		4

int spi_byte(int, int);
int spi_byte_in(int);
void spi_start_transaction(int);

#endif /* !_SPI_H_ */

