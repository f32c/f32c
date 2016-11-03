/*
** Filename: USBSlaveFT232App.h
**
** Automatically created by Application Wizard 1.2.4.1
**
** Part of solution Samples in project USBSlaveFT232App
**
** Comments:
**
** Important: Sections between markers "FTDI:S*" and "FTDI:E*" will be overwritten by
** the Application Wizard
*/
#include "vos.h"

/* FTDI:SHF Header Files */
#include "USB.h"
#include "USBSlave.h"
#include "ioctl.h"
#include "UART.h"
#include "GPIO.h"
#include "USBSlaveFT232.h"
/* FTDI:EHF */

/* FTDI:SDC Driver Constants */
#define VOS_DEV_USBSLAVE_1 0
#define VOS_DEV_UART 1
#define VOS_DEV_GPIO_PORT_A 2
#define VOS_DEV_USBSLAVE_FT232 3

#define VOS_NUMBER_DEVICES 4
/* FTDI:EDC */

/* FTDI:SDH Driver Handles */
VOS_HANDLE hUSBSLAVE_1; // USB Slave Port 1
VOS_HANDLE hUART; // UART Interface Driver
VOS_HANDLE hGPIO_PORT_A; // GPIO Port A Driver
VOS_HANDLE hUSBSLAVE_FT232; // Emulates an FT232 device using the USB Slave Interface
/* FTDI:EDH */

#define BUFFER_SIZE 128

#define LED_ON  0xFF
#define LED_OFF 0x00
