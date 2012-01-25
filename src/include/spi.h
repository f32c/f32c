
#ifndef _SPI_H_
#define	_SPI_H_

#define SPI_PORT_FLASH		0
#define SPI_PORT_SDCARD		4

#define	spi_start_transaction(port)	OUTB(IO_SPI_FLASH + port, 0);
#define	spi_stop_transaction(port)	OUTB(IO_SPI_FLASH + port, SPI_CEN);

int spi_byte(int, int);
int spi_byte_in(int);

#endif /* !_IO_H_ */

