/*
** File:	USBSlaveFT232Emu.c
**
** Source:	Example Code supplied with v1.4.4 of the VNC2 Toolchain
**				USBSlaveFT232App project
**
** Description:	This project demonstrates configuring the VNC2 to function
**				similar to a FT232 USB Slave IC from FTDI
**				USB to UART in a dual-threaded application
**
** Demonstrates:FT232 Emulation including USB Config Descriptors
**				DMA, GPIO, UART
**
** Companion Code for AN_197 FT232 Emulation With a Vinculum-II
**
*/

// Include header files here
#include "vos.h"
#include "DMA.h"

#include "USBSlaveFT232Emu.h"

// A thread is created for each direction USB -> UART and UART -> USB
/* FTDI:STP Thread Prototypes */
vos_tcb_t *tcbUARTTX;
vos_tcb_t *tcbUARTRX;

// All I/O and port configuration is done through main() and UartTx()
// UartRX() cannot start processign data until all of the configuration is
// complete.  A semaphore is used to accomplish this task.
vos_semaphore_t semConfigured;	// This is used to block the UART RX thread
								// until the FT232 and UART bits are configured

// The next three variable declarations define the USB Config Descriptors
// used with the FT232Slave driver.  See AN_168.

unsigned char mfg_string[18] =
		{
			18,			// bLength
			USB_DESCRIPTOR_TYPE_STRING,		// bDescriptorType
						// bString
			0x41, 0x00,	// 'A'
			0x43, 0x00,	// 'C'
			0x4D, 0x00,	// 'M'
			0x45, 0x00,	// 'E'
			0x20, 0x00,	// ' '
			0x4c, 0x00,	// 'L'
			0x74, 0x00,	// 't'
			0x64, 0x00 	// 'd'
		};

unsigned char desc_string[28] =
		{
			28,			// bLength
			USB_DESCRIPTOR_TYPE_STRING,		// bDescriptorType
						// bString
			0x56, 0x00,	// 'V'
			0x4e, 0x00,	// 'N'
			0x43, 0x00,	// 'C'
			0x32, 0x00,	// '2'
			0x20, 0x00,	// ' '
			0x61, 0x00,	// 'a'
			0x73, 0x00,	// 's'
			0x20, 0x00,	// ' '
			0x46, 0x00,	// 'F'
			0x54, 0x00,	// 'T'
			0x32, 0x00,	// '2'
			0x33, 0x00,	// '3'
			0x32, 0x00 	// '2'
		};

unsigned char sernum_string[18] =
		{
			18,			// bLength
			USB_DESCRIPTOR_TYPE_STRING,		// bDescriptor Type
						// bString
			0x56, 0x00,	// 'V'
			0x4e, 0x00,	// 'N'
			0x43, 0x00,	// 'C'
			0x32, 0x00,	// '2'
			0x30, 0x00,	// '0'
			0x30, 0x00,	// '0'
			0x30, 0x00,	// '0'
			0x31, 0x00 	// '1'
		};

// set up the USB config descriptors
usbslaveft232_ioctl_cb_descriptors_t descriptors_cb;

// Declare the two threads
void uartTx();
void uartRx();
/* FTDI:ETP */

/* Declaration for IOMUx setup function */
void iomux_setup(void);

/* Main code - entry point to firmware */
void main(void)
{
	usbSlaveFt232_init_t ft232Context;

	/* FTDI:SDD Driver Declarations */
	// UART Driver configuration context
	uart_context_t uartContext;
	// GPIO Port A configuration context
	gpio_context_t gpioContextA;
	// USB Slave FT232 configuration context
	usbSlaveFt232_init_t usbslaveFT232Context;
	/* FTDI:EDD */

	/* FTDI:SKI Kernel Initialisation */
	vos_init(50, VOS_TICK_INTERVAL, VOS_NUMBER_DEVICES);
	vos_set_clock_frequency(VOS_48MHZ_CLOCK_FREQUENCY);
	vos_set_idle_thread_tcb_size(512);
	/* FTDI:EKI */

	// Configure all the I/O pins for the UART and GPIO
	// See USBSlaveFT232Emu_iomux.c
	iomux_setup();

	// Establish the transmit and receive buffer sizes
	ft232Context.in_ep_buffer_len = 128;
	ft232Context.out_ep_buffer_len = 128;
	/* FTDI:SDI Driver Initialisation */
	// Initialise USB Slave Port 0
	usbslave_init(0, VOS_DEV_USBSLAVE_1);

	// Initialise UART
	uartContext.buffer_size = VOS_BUFFER_SIZE_128_BYTES;
	uart_init(VOS_DEV_UART,&uartContext);

	// Initialise GPIO A
	gpioContextA.port_identifier = GPIO_PORT_A;
	gpio_init(VOS_DEV_GPIO_PORT_A,&gpioContextA);

	// Initialise USB Slave FT232 Driver
	usbslaveFT232Context.in_ep_buffer_len = 128;
	usbslaveFT232Context.out_ep_buffer_len = 128;
	usbslaveft232_init(VOS_DEV_USBSLAVE_FT232, &usbslaveFT232Context);
	/* FTDI:EDI */

	// initialise semaphore for thread synchronisation
	vos_init_semaphore(&semConfigured,0);

	/* FTDI:SCT Thread Creation */
	tcbUARTTX = vos_create_thread_ex(31, 4096, uartTx, "uartTx", 0);
	tcbUARTRX = vos_create_thread_ex(24, 4096, uartRx, "uartRx", 0);
	/* FTDI:ECT */

	// Start VOS
	vos_start_scheduler();

// Put this function to sleep.  VOS and the threads do all the
// rest of the work.
main_loop:
	goto main_loop;
}

/* FTDI:SSP Support Functions */

VOS_HANDLE ft232_slave_attach(VOS_HANDLE hUSB, unsigned char devSlaveFT232)
{
	common_ioctl_cb_t ft232_iocb;
	VOS_HANDLE hSlaveFT232;

	// open FT232 driver
	hSlaveFT232 = vos_dev_open(devSlaveFT232);

	// initialize request control block
	vos_memset(&descriptors_cb,0,sizeof(usbslaveft232_ioctl_cb_descriptors_t));

	// set all of the USB descriptor data according to AN_168
	// set device descriptors in request control block
	descriptors_cb.device_descriptor.idVendor 		= USB_VID_FTDI;	// 0x0403 is FTDI default
	descriptors_cb.device_descriptor.idProduct 		= 0x6001;		// 0x6001 is FT232 default
	descriptors_cb.device_descriptor.iManufacturer 	= FT232_STRING_INDEX_MANUFACTURER;	// = 1
	descriptors_cb.device_descriptor.iProduct 		= FT232_STRING_INDEX_PRODUCT;		// = 2
	descriptors_cb.device_descriptor.iSerialNumber 	= FT232_STRING_INDEX_SERIAL_NUMBER; // = 3
	descriptors_cb.device_descriptor.use 			= 1;

	// set configuration descriptors in request control block
	descriptors_cb.config_descriptor.bmAttributes 	= 0xC0;			// self powered, no remote wake
	descriptors_cb.config_descriptor.bMaxPower 		= 0x01;			// only 2mA (current = value * 2)
	descriptors_cb.config_descriptor.use 			= 1;			//	note: 500mA maximum (0xFA)

	// set the string descriptors in request control block
	// notice the type-cast to properly fill the structure
	descriptors_cb.manufacturer_string 				= (usb_deviceStringDescriptor_t *) mfg_string;
	descriptors_cb.product_string 					= (usb_deviceStringDescriptor_t *) desc_string;
	descriptors_cb.serial_number_string 			= (usb_deviceStringDescriptor_t *) sernum_string;

	// finally make the call to set the descriptors
	ft232_iocb.ioctl_code	= VOS_IOCTL_USBSLAVEFT232_SET_DESCRIPTORS;
	ft232_iocb.set.data 	= &descriptors_cb;
	if (vos_dev_ioctl(hSlaveFT232,&ft232_iocb) != USBSLAVE_OK)
	{
		vos_dev_close(hSlaveFT232);
		hSlaveFT232 = NULL;
	}

	// attach FT232 to USB Slave port
	ft232_iocb.ioctl_code 	= VOS_IOCTL_USBSLAVEFT232_ATTACH;
	ft232_iocb.set.data   	= hUSB;
	if (vos_dev_ioctl(hSlaveFT232, &ft232_iocb) != USBSLAVE_OK)
	{
		vos_dev_close(hSlaveFT232);
		hSlaveFT232 = NULL;
	}

	// now that everything is set up, return the handle
	return hSlaveFT232;
}

void ft232_slave_detach(VOS_HANDLE hSlaveFT232)
{
	common_ioctl_cb_t ft232_iocb;

	// Close out the FT232Slave device
	if (hSlaveFT232)
	{
		ft232_iocb.ioctl_code = VOS_IOCTL_USBSLAVEFT232_DETACH;

		vos_dev_ioctl(hSlaveFT232, &ft232_iocb);
		vos_dev_close(hSlaveFT232);
	}
}

void initialize_uart(VOS_HANDLE hUart)
{
	// All of the UART parameters are configured here.
	// Note that the PC application UART settings *DO NOT* have any effect on the VNC2 UART settings.
	//
	// Settings made here must match the device to which the UART is attached.

	common_ioctl_cb_t uart_iocb;

	// setup the UART interface
	uart_iocb.ioctl_code = VOS_IOCTL_COMMON_ENABLE_DMA;
	uart_iocb.set.param = DMA_ACQUIRE_AS_REQUIRED;
	vos_dev_ioctl(hUart, &uart_iocb);

	// set baud rate
	uart_iocb.ioctl_code = VOS_IOCTL_UART_SET_BAUD_RATE;
	uart_iocb.set.uart_baud_rate = UART_BAUD_115200;
	vos_dev_ioctl(hUart, &uart_iocb);

	// set flow control
	uart_iocb.ioctl_code = VOS_IOCTL_UART_SET_FLOW_CONTROL;
	uart_iocb.set.param = UART_FLOW_RTS_CTS;
	vos_dev_ioctl(hUart, &uart_iocb);

	// set data bits
	uart_iocb.ioctl_code = VOS_IOCTL_UART_SET_DATA_BITS;
	uart_iocb.set.param = UART_DATA_BITS_8;
	vos_dev_ioctl(hUart, &uart_iocb);

	// set stop bits
	uart_iocb.ioctl_code = VOS_IOCTL_UART_SET_STOP_BITS;
	uart_iocb.set.param = UART_STOP_BITS_1;
	vos_dev_ioctl(hUart, &uart_iocb);

	// set parity
	uart_iocb.ioctl_code = VOS_IOCTL_UART_SET_PARITY;
	uart_iocb.set.param = UART_PARITY_NONE;
	vos_dev_ioctl(hUart, &uart_iocb);
}

void initialize_gpio(VOS_HANDLE hGPIO)
{
	gpio_ioctl_cb_t gpio_iocb;

	// Set all pins to output using an ioctl.
	gpio_iocb.ioctl_code = VOS_IOCTL_GPIO_SET_MASK;
	gpio_iocb.value = 0xFF;
	// Send the ioctl to the device manager.
	vos_dev_ioctl(hGPIO, &gpio_iocb);
}

/* FTDI:ESP */

void open_drivers(void)
{
	/* Code for opening and closing drivers - move to required places in Application Threads */
	// With this application note, all base drivers can be opened together, so this function is left intact.
	/* FTDI:SDA Driver Open */
	hUSBSLAVE_1 = vos_dev_open(VOS_DEV_USBSLAVE_1);
	hUART = vos_dev_open(VOS_DEV_UART);
	hGPIO_PORT_A = vos_dev_open(VOS_DEV_GPIO_PORT_A);
	/* FTDI:EDA */
}

void attach_drivers(void)
{
	/* FTDI:SUA Layered Driver Attach Function Calls */
	// The only layered driver in use is the FT232Slave driver.
	hUSBSLAVE_FT232 = ft232_slave_attach(hUSBSLAVE_1, VOS_DEV_USBSLAVE_FT232);
	/* FTDI:EUA */
}

void close_drivers(void)
{
	/* FTDI:SDB Driver Close */
	// As with the open, all base drivers can be closed here.
	// Note that the FT232Slave driver needs to be closed before calling this function
	vos_dev_close(hUSBSLAVE_1);
	vos_dev_close(hUART);
	vos_dev_close(hGPIO_PORT_A);
	/* FTDI:EDB */
}

/* Application Threads */

// Declare global read and write buffers
unsigned char readbuf[BUFFER_SIZE];
unsigned char writebuf[BUFFER_SIZE];

void uartTx()
{
	common_ioctl_cb_t iocb;
	unsigned char b;
	unsigned char led = 0xFF;
	unsigned short bytesTransferred;

	// All VNC2 configuration is done in this uartTx thread
	open_drivers();

	hUSBSLAVE_FT232 = ft232_slave_attach(hUSBSLAVE_1, VOS_DEV_USBSLAVE_FT232);

	if (!hUSBSLAVE_FT232)
		return;		// The FT232Slave driver failed to attach to the USB Slave

	// Initialize UART - reading the values set above
	initialize_uart(hUART);

	// Port A, bit7 is the only one in use wiht this application.
	// It is set as an output to drive an LED.
	initialize_gpio(hGPIO_PORT_A);

	// Unblock other threads now that everything is configured
	vos_signal_semaphore(&semConfigured);

	// The code above will only be executed once

	// The while() loop copies data from USB -> UART
	while (1)
	{
		// Check whether any bytes are available from the USB port
		iocb.ioctl_code = VOS_IOCTL_COMMON_GET_RX_QUEUE_STATUS;
		iocb.get.queue_stat = 0;
		vos_dev_ioctl(hUSBSLAVE_FT232, &iocb);

		// If no bytes are available, wait a bit and return to teh top of the while() loop to try again
		if (iocb.get.queue_stat == 0)
		{
			vos_delay_msecs(5);	// delay timing can be varied to alter performance
			continue;
		}

		// make sure we don't try to read more data than our application buffer can hold!
		if (iocb.get.queue_stat > BUFFER_SIZE)
			iocb.get.queue_stat = BUFFER_SIZE;

		// read the available bytes from the USB port
		vos_dev_read(hUSBSLAVE_FT232, &writebuf[0], iocb.get.queue_stat, &bytesTransferred);

		// turn on the LED
		led = 0x00;
		vos_dev_write(hGPIO_PORT_A, &led, 1, NULL);

		// send the bytes just read out the UART port
		vos_dev_write(hUART, &writebuf[0], iocb.get.queue_stat, &bytesTransferred);

		// turn off the LED
		led = 0xFF;
		vos_dev_write(hGPIO_PORT_A, &led, 1, NULL);
	}

	return;
}
void uartRx()
{
	common_ioctl_cb_t iocb;
	unsigned char b;
	unsigned short bytesTransferred;
	unsigned char led = 0xFF;

	// wait for other thread to initialize the hardware and drivers....
	vos_wait_semaphore(&semConfigured);

	// as with the uartTx thread, the while() loop copies data from UART -> USB
	while (1)
	{
		// see if any data is available from the UART
		iocb.ioctl_code = VOS_IOCTL_COMMON_GET_RX_QUEUE_STATUS;
		iocb.get.queue_stat = 0;
		vos_dev_ioctl(hUART, &iocb);

		// if not, wait a bit and return to the top of the while() loop
		if (iocb.get.queue_stat == 0)
		{
			vos_delay_msecs(5);	// delay timing can be varied to alter performance
			continue;
		}

		// make sure we don't try to read more data than our application buffer can hold!
		if (iocb.get.queue_stat > BUFFER_SIZE)
			iocb.get.queue_stat = BUFFER_SIZE;

		// read the data from the UART into the buffer
		vos_dev_read(hUART, &readbuf[0], iocb.get.queue_stat, &bytesTransferred);

		// turn on the LED
		led = 0x00;
		vos_dev_write(hGPIO_PORT_A, &led, 1, NULL);

		// send the bytes just read to the USB port
		vos_dev_write(hUSBSLAVE_FT232, &readbuf[0], iocb.get.queue_stat, &bytesTransferred);

		// turn off the LED
		led = 0xFF;
		vos_dev_write(hGPIO_PORT_A, &led, 1, NULL);
	}

return;
}
