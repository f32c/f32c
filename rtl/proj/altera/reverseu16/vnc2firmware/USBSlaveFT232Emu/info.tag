<?xml version="1.0"?>
<VinTag>
 <version>1.0.0</version>
 <file name="USBSlaveFT232Emu.c">
  <enum name="IOMUX_SIGNALS" line="24" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\iomux.h">
   <value name="IOMUX_IN_DEBUGGER" const="0"/>
   <value name="IOMUX_IN_UART_RXD" const="1"/>
   <value name="IOMUX_IN_UART_CTS_N" const="2"/>
   <value name="IOMUX_IN_UART_DSR_N" const="3"/>
   <value name="IOMUX_IN_UART_DCD" const="4"/>
   <value name="IOMUX_IN_UART_RI" const="5"/>
   <value name="IOMUX_IN_FIFO_DATA_0" const="6"/>
   <value name="IOMUX_IN_FIFO_DATA_1" const="7"/>
   <value name="IOMUX_IN_FIFO_DATA_2" const="8"/>
   <value name="IOMUX_IN_FIFO_DATA_3" const="9"/>
   <value name="IOMUX_IN_FIFO_DATA_4" const="10"/>
   <value name="IOMUX_IN_FIFO_DATA_5" const="11"/>
   <value name="IOMUX_IN_FIFO_DATA_6" const="12"/>
   <value name="IOMUX_IN_FIFO_DATA_7" const="13"/>
   <value name="IOMUX_IN_FIFO_OE_N" const="14"/>
   <value name="IOMUX_IN_FIFO_RD_N" const="15"/>
   <value name="IOMUX_IN_FIFO_WR_N" const="16"/>
   <value name="IOMUX_IN_SPI_SLAVE_0_CLK" const="17"/>
   <value name="IOMUX_IN_SPI_SLAVE_0_MOSI" const="18"/>
   <value name="IOMUX_IN_SPI_SLAVE_0_CS" const="19"/>
   <value name="IOMUX_IN_SPI_SLAVE_1_CLK" const="20"/>
   <value name="IOMUX_IN_SPI_SLAVE_1_MOSI" const="21"/>
   <value name="IOMUX_IN_SPI_SLAVE_1_CS" const="22"/>
   <value name="IOMUX_IN_SPI_MASTER_MISO" const="23"/>
   <value name="IOMUX_IN_GPIO_PORT_A_0" const="24"/>
   <value name="IOMUX_IN_GPIO_PORT_A_1" const="25"/>
   <value name="IOMUX_IN_GPIO_PORT_A_2" const="26"/>
   <value name="IOMUX_IN_GPIO_PORT_A_3" const="27"/>
   <value name="IOMUX_IN_GPIO_PORT_A_4" const="28"/>
   <value name="IOMUX_IN_GPIO_PORT_A_5" const="29"/>
   <value name="IOMUX_IN_GPIO_PORT_A_6" const="30"/>
   <value name="IOMUX_IN_GPIO_PORT_A_7" const="31"/>
   <value name="IOMUX_IN_GPIO_PORT_B_0" const="32"/>
   <value name="IOMUX_IN_GPIO_PORT_B_1" const="33"/>
   <value name="IOMUX_IN_GPIO_PORT_B_2" const="34"/>
   <value name="IOMUX_IN_GPIO_PORT_B_3" const="35"/>
   <value name="IOMUX_IN_GPIO_PORT_B_4" const="36"/>
   <value name="IOMUX_IN_GPIO_PORT_B_5" const="37"/>
   <value name="IOMUX_IN_GPIO_PORT_B_6" const="38"/>
   <value name="IOMUX_IN_GPIO_PORT_B_7" const="39"/>
   <value name="IOMUX_IN_GPIO_PORT_C_0" const="40"/>
   <value name="IOMUX_IN_GPIO_PORT_C_1" const="41"/>
   <value name="IOMUX_IN_GPIO_PORT_C_2" const="42"/>
   <value name="IOMUX_IN_GPIO_PORT_C_3" const="43"/>
   <value name="IOMUX_IN_GPIO_PORT_C_4" const="44"/>
   <value name="IOMUX_IN_GPIO_PORT_C_5" const="45"/>
   <value name="IOMUX_IN_GPIO_PORT_C_6" const="46"/>
   <value name="IOMUX_IN_GPIO_PORT_C_7" const="47"/>
   <value name="IOMUX_IN_GPIO_PORT_D_0" const="48"/>
   <value name="IOMUX_IN_GPIO_PORT_D_1" const="49"/>
   <value name="IOMUX_IN_GPIO_PORT_D_2" const="50"/>
   <value name="IOMUX_IN_GPIO_PORT_D_3" const="51"/>
   <value name="IOMUX_IN_GPIO_PORT_D_4" const="52"/>
   <value name="IOMUX_IN_GPIO_PORT_D_5" const="53"/>
   <value name="IOMUX_IN_GPIO_PORT_D_6" const="54"/>
   <value name="IOMUX_IN_GPIO_PORT_D_7" const="55"/>
   <value name="IOMUX_IN_GPIO_PORT_E_0" const="56"/>
   <value name="IOMUX_IN_GPIO_PORT_E_1" const="57"/>
   <value name="IOMUX_IN_GPIO_PORT_E_2" const="58"/>
   <value name="IOMUX_IN_GPIO_PORT_E_3" const="59"/>
   <value name="IOMUX_IN_GPIO_PORT_E_4" const="60"/>
   <value name="IOMUX_IN_GPIO_PORT_E_5" const="61"/>
   <value name="IOMUX_IN_GPIO_PORT_E_6" const="62"/>
   <value name="IOMUX_IN_GPIO_PORT_E_7" const="63"/>
   <value name="IOMUX_OUT_DEBUGGER" const="64"/>
   <value name="IOMUX_OUT_UART_TXD" const="65"/>
   <value name="IOMUX_OUT_UART_RTS_N" const="66"/>
   <value name="IOMUX_OUT_UART_DTR_N" const="67"/>
   <value name="IOMUX_OUT_UART_TX_ACTIVE" const="68"/>
   <value name="IOMUX_OUT_FIFO_DATA_0" const="69"/>
   <value name="IOMUX_OUT_FIFO_DATA_1" const="70"/>
   <value name="IOMUX_OUT_FIFO_DATA_2" const="71"/>
   <value name="IOMUX_OUT_FIFO_DATA_3" const="72"/>
   <value name="IOMUX_OUT_FIFO_DATA_4" const="73"/>
   <value name="IOMUX_OUT_FIFO_DATA_5" const="74"/>
   <value name="IOMUX_OUT_FIFO_DATA_6" const="75"/>
   <value name="IOMUX_OUT_FIFO_DATA_7" const="76"/>
   <value name="IOMUX_OUT_FIFO_RXF_N" const="77"/>
   <value name="IOMUX_OUT_FIFO_TXE_N" const="78"/>
   <value name="IOMUX_OUT_PWM_0" const="79"/>
   <value name="IOMUX_OUT_PWM_1" const="80"/>
   <value name="IOMUX_OUT_PWM_2" const="81"/>
   <value name="IOMUX_OUT_PWM_3" const="82"/>
   <value name="IOMUX_OUT_PWM_4" const="83"/>
   <value name="IOMUX_OUT_PWM_5" const="84"/>
   <value name="IOMUX_OUT_PWM_6" const="85"/>
   <value name="IOMUX_OUT_PWM_7" const="86"/>
   <value name="IOMUX_OUT_SPI_SLAVE_0_MOSI" const="87"/>
   <value name="IOMUX_OUT_SPI_SLAVE_0_MISO" const="88"/>
   <value name="IOMUX_OUT_SPI_SLAVE_1_MOSI" const="89"/>
   <value name="IOMUX_OUT_SPI_SLAVE_1_MISO" const="90"/>
   <value name="IOMUX_OUT_SPI_MASTER_CLK" const="91"/>
   <value name="IOMUX_OUT_SPI_MASTER_MOSI" const="92"/>
   <value name="IOMUX_OUT_SPI_MASTER_CS_0" const="93"/>
   <value name="IOMUX_OUT_SPI_MASTER_CS_1" const="94"/>
   <value name="IOMUX_OUT_FIFO_CLKOUT_245" const="95"/>
   <value name="IOMUX_OUT_GPIO_PORT_A_0" const="96"/>
   <value name="IOMUX_OUT_GPIO_PORT_A_1" const="97"/>
   <value name="IOMUX_OUT_GPIO_PORT_A_2" const="98"/>
   <value name="IOMUX_OUT_GPIO_PORT_A_3" const="99"/>
   <value name="IOMUX_OUT_GPIO_PORT_A_4" const="100"/>
   <value name="IOMUX_OUT_GPIO_PORT_A_5" const="101"/>
   <value name="IOMUX_OUT_GPIO_PORT_A_6" const="102"/>
   <value name="IOMUX_OUT_GPIO_PORT_A_7" const="103"/>
   <value name="IOMUX_OUT_GPIO_PORT_B_0" const="104"/>
   <value name="IOMUX_OUT_GPIO_PORT_B_1" const="105"/>
   <value name="IOMUX_OUT_GPIO_PORT_B_2" const="106"/>
   <value name="IOMUX_OUT_GPIO_PORT_B_3" const="107"/>
   <value name="IOMUX_OUT_GPIO_PORT_B_4" const="108"/>
   <value name="IOMUX_OUT_GPIO_PORT_B_5" const="109"/>
   <value name="IOMUX_OUT_GPIO_PORT_B_6" const="110"/>
   <value name="IOMUX_OUT_GPIO_PORT_B_7" const="111"/>
   <value name="IOMUX_OUT_GPIO_PORT_C_0" const="112"/>
   <value name="IOMUX_OUT_GPIO_PORT_C_1" const="113"/>
   <value name="IOMUX_OUT_GPIO_PORT_C_2" const="114"/>
   <value name="IOMUX_OUT_GPIO_PORT_C_3" const="115"/>
   <value name="IOMUX_OUT_GPIO_PORT_C_4" const="116"/>
   <value name="IOMUX_OUT_GPIO_PORT_C_5" const="117"/>
   <value name="IOMUX_OUT_GPIO_PORT_C_6" const="118"/>
   <value name="IOMUX_OUT_GPIO_PORT_C_7" const="119"/>
   <value name="IOMUX_OUT_GPIO_PORT_D_0" const="120"/>
   <value name="IOMUX_OUT_GPIO_PORT_D_1" const="121"/>
   <value name="IOMUX_OUT_GPIO_PORT_D_2" const="122"/>
   <value name="IOMUX_OUT_GPIO_PORT_D_3" const="123"/>
   <value name="IOMUX_OUT_GPIO_PORT_D_4" const="124"/>
   <value name="IOMUX_OUT_GPIO_PORT_D_5" const="125"/>
   <value name="IOMUX_OUT_GPIO_PORT_D_6" const="126"/>
   <value name="IOMUX_OUT_GPIO_PORT_D_7" const="127"/>
   <value name="IOMUX_OUT_GPIO_PORT_E_0" const="128"/>
   <value name="IOMUX_OUT_GPIO_PORT_E_1" const="129"/>
   <value name="IOMUX_OUT_GPIO_PORT_E_2" const="130"/>
   <value name="IOMUX_OUT_GPIO_PORT_E_3" const="131"/>
   <value name="IOMUX_OUT_GPIO_PORT_E_4" const="132"/>
   <value name="IOMUX_OUT_GPIO_PORT_E_5" const="133"/>
   <value name="IOMUX_OUT_GPIO_PORT_E_6" const="134"/>
   <value name="IOMUX_OUT_GPIO_PORT_E_7" const="135"/>
  </enum>
  <struct name="_vos_tcb_t" line="76" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h">
   <member name="next" offset="0" size="16"
    basename="_vos_tcb_t" basetype="STRUCT" baseattr="ptr,"/>
   <member name="state" offset="16" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="orig_priority" offset="24" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="priority" offset="32" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="quantum" offset="40" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="delay" offset="48" size="16"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="sp" offset="64" size="16"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="eax" offset="80" size="32"
    basetype="INT" baseattr="unsigned,"/>
   <member name="ebx" offset="112" size="32"
    basetype="INT" baseattr="unsigned,"/>
   <member name="ecx" offset="144" size="32"
    basetype="INT" baseattr="unsigned,"/>
   <member name="r0" offset="176" size="32"
    basetype="INT" baseattr="unsigned,"/>
   <member name="r1" offset="208" size="32"
    basetype="INT" baseattr="unsigned,"/>
   <member name="r2" offset="240" size="32"
    basetype="INT" baseattr="unsigned,"/>
   <member name="r3" offset="272" size="32"
    basetype="INT" baseattr="unsigned,"/>
   <member name="system_data" offset="304" size="16"
    basetype="VOID" baseattr="ptr,"/>
   <member name="system_profiler" offset="320" size="16"
    basetype="VOID" baseattr="ptr,"/>
   <member name="flags" offset="336" size="16"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="semaphore_list" offset="352" size="16"
    basetype="VOID" baseattr="ptr,"/>
  </struct>
  <struct name="_usb_deviceRequest_t" line="157" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USB.h">
   <member name="bmRequestType" offset="0" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="bRequest" offset="8" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="wValue" offset="16" size="16"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="wIndex" offset="32" size="16"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="wLength" offset="48" size="16"
    basetype="SHORT" baseattr="unsigned,"/>
  </struct>
  <struct name="_usbslave_ioctl_cb_t" line="64" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USBSlave.h">
   <member name="ioctl_code" offset="0" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="ep" offset="8" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="handle" offset="16" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="get" offset="24" size="16"
    basetype="VOID" baseattr="ptr,"/>
   <member name="set" offset="40" size="16"
    basetype="VOID" baseattr="ptr,"/>
   <member name="request" offset="56" size="48"
    basename="__unnamed_struct_5" basetype="STRUCT" baseattr=""/>
  </struct>
  <enum name="dma_status" line="27" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\dma.h">
   <value name="DMA_OK" const="0"/>
   <value name="DMA_INVALID_PARAMETER" const="1"/>
   <value name="DMA_ACQUIRE_ERROR" const="2"/>
   <value name="DMA_ENABLE_ERROR" const="3"/>
   <value name="DMA_DISABLE_ERROR" const="4"/>
   <value name="DMA_CONFIGURE_ERROR" const="5"/>
   <value name="DMA_ERROR" const="6"/>
   <value name="DMA_FIFO_ERROR" const="7"/>
  </enum>
  <struct name="_usb_hubDescriptor_t" line="332" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USB.h">
   <member name="bLength" offset="0" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="bDescriptorType" offset="8" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="bNbrPorts" offset="16" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="wHubCharacteristics" offset="24" size="16"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="bPwrOn2PwrGood" offset="40" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="bHubContrCurrent" offset="48" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="DeviceRemovable" offset="56" size="128"
    basetype="CHAR" baseattr="unsigned," basearray="16,"/>
   <member name="PortPwrCtrlMask" offset="184" size="128"
    basetype="CHAR" baseattr="unsigned," basearray="16,"/>
  </struct>
  <struct name="_usb_hubPortStatus_t" line="391" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USB.h">
   <member name="currentConnectStatus" offset="0" size="1"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="portEnabled" offset="1" size="1"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="portSuspend" offset="2" size="1"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="portOverCurrent" offset="3" size="1"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="portReset" offset="4" size="1"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="resv1" offset="5" size="3"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="portPower" offset="8" size="1"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="portLowSpeed" offset="9" size="1"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="portHighSpeed" offset="10" size="1"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="portTest" offset="11" size="1"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="portIndicator" offset="12" size="1"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="resv2" offset="13" size="3"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="currentConnectStatusChange" offset="16" size="1"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="portEnabledChange" offset="17" size="1"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="portSuspendChange" offset="18" size="1"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="portOverCurrentChange" offset="19" size="1"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="portResetChange" offset="20" size="1"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="resv3" offset="21" size="3"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="portPowerChange" offset="24" size="1"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="portLowSpeedChange" offset="25" size="1"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="portHighSpeedChange" offset="26" size="1"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="portTestChange" offset="27" size="1"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="portIndicatorChange" offset="28" size="1"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="resv4" offset="29" size="3"
    basetype="SHORT" baseattr="unsigned,"/>
  </struct>
  <enum name="USBSLAVE_STATUS" line="121" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USBSlave.h">
   <value name="USBSLAVE_OK" const="0"/>
   <value name="USBSLAVE_INVALID_PARAMETER" const="1"/>
   <value name="USBSLAVE_ERROR" const="2"/>
   <value name="USBSLAVE_FATAL_ERROR" const="255"/>
  </enum>
  <struct name="_usb_deviceEndpointDescriptor_t" line="293" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USB.h">
   <member name="bLength" offset="0" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="bDescriptorType" offset="8" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="bEndpointAddress" offset="16" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="bmAttributes" offset="24" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="wMaxPacketSize" offset="32" size="16"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="bInterval" offset="48" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
  </struct>
  <struct name="_vos_semaphore_list_t" line="150" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h">
   <member name="next" offset="0" size="16"
    basename="_vos_semaphore_list_t" basetype="STRUCT" baseattr="ptr,"/>
   <member name="siz" offset="16" size="8"
    basetype="CHAR" baseattr="signed,"/>
   <member name="flags" offset="24" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="result" offset="32" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="list" offset="40" size="16"
    basename="_vos_semaphore_t" basetype="STRUCT" baseattr="ptr," basearray="1,"/>
  </struct>
  <struct name="_usb_deviceInterfaceDescriptor_t" line="279" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USB.h">
   <member name="bLength" offset="0" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="bDescriptorType" offset="8" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="bInterfaceNumber" offset="16" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="bAlternateSetting" offset="24" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="bNumEndpoints" offset="32" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="bInterfaceClass" offset="40" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="bInterfaceSubclass" offset="48" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="bInterfaceProtocol" offset="56" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="iInterface" offset="64" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
  </struct>
  <struct name="_usb_deviceQualifierDescriptor_t" line="247" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USB.h">
   <member name="bLength" offset="0" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="bDescriptorType" offset="8" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="bcdUSB" offset="16" size="16"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="bDeviceClass" offset="32" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="bDeviceSubclass" offset="40" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="bDeviceProtocol" offset="48" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="bMaxPacketSize0" offset="56" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="bNumConfigurations" offset="64" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="bReserved" offset="72" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
  </struct>
  <struct name="_vos_mutex_t" line="120" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h">
   <member name="threads" offset="0" size="16"
    basename="_vos_tcb_t" basetype="STRUCT" baseattr="ptr,"/>
   <member name="owner" offset="16" size="16"
    basename="_vos_tcb_t" basetype="STRUCT" baseattr="ptr,"/>
   <member name="attr" offset="32" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="ceiling" offset="40" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
  </struct>
  <struct name="_vos_device_t" line="36" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\devman.h">
   <member name="mutex" offset="0" size="48"
    basename="_vos_mutex_t" basetype="STRUCT" baseattr=""/>
   <member name="driver" offset="48" size="16"
    basename="_vos_driver_t" basetype="STRUCT" baseattr="ptr,"/>
   <member name="context" offset="64" size="16"
    basetype="VOID" baseattr="ptr,"/>
  </struct>
  <struct name="_usb_deviceDescriptor_t" line="228" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USB.h">
   <member name="bLength" offset="0" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="bDescriptorType" offset="8" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="bcdUSB" offset="16" size="16"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="bDeviceClass" offset="32" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="bDeviceSubclass" offset="40" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="bDeviceProtocol" offset="48" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="bMaxPacketSize0" offset="56" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="idVendor" offset="64" size="16"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="idProduct" offset="80" size="16"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="bcdDevice" offset="96" size="16"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="iManufacturer" offset="112" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="iProduct" offset="120" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="iSerialNumber" offset="128" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="bNumConfigurations" offset="136" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
  </struct>
  <struct name="_vos_driver_t" line="25" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\devman.h">
   <member name="open" offset="0" size="32"
    basetype="VOID" baseattr=""/>
   <member name="close" offset="32" size="32"
    basetype="VOID" baseattr=""/>
   <member name="read" offset="64" size="32"
    basetype="CHAR" baseattr="signed,"/>
   <member name="write" offset="96" size="32"
    basetype="CHAR" baseattr="signed,"/>
   <member name="ioctl" offset="128" size="32"
    basetype="CHAR" baseattr="signed,"/>
   <member name="interrupt" offset="160" size="32"
    basetype="VOID" baseattr=""/>
   <member name="flags" offset="192" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
  </struct>
  <struct name="_vos_system_data_area_t" line="193" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h">
   <member name="next" offset="0" size="16"
    basename="_vos_system_data_area_t" basetype="STRUCT" baseattr="ptr,"/>
   <member name="tcb" offset="16" size="16"
    basename="_vos_tcb_t" basetype="STRUCT" baseattr="ptr,"/>
   <member name="count" offset="32" size="32"
    basetype="INT" baseattr="unsigned,"/>
   <member name="name" offset="64" size="16"
    basetype="CHAR" baseattr="signed,ptr,"/>
  </struct>
  <struct name="_usb_deviceStringDescriptorZero_t" line="310" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USB.h">
   <member name="bLength" offset="0" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="bDescriptorType" offset="8" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="wLANGID0" offset="16" size="16"
    basetype="SHORT" baseattr="unsigned,"/>
  </struct>
  <enum name="USBSLAVEFT232_STATUS" line="63" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USBSlaveFT232.h">
   <value name="USBSLAVEFT232_OK" const="0"/>
   <value name="USBSLAVEFT232_INVALID_PARAMETER" const="1"/>
   <value name="USBSLAVEFT232_ERROR" const="2"/>
  </enum>
  <struct name="_vos_cond_var_t" line="174" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h">
   <member name="threads" offset="0" size="16"
    basename="_vos_tcb_t" basetype="STRUCT" baseattr="ptr,"/>
   <member name="lock" offset="16" size="16"
    basename="_vos_mutex_t" basetype="STRUCT" baseattr="ptr,"/>
   <member name="state" offset="32" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
  </struct>
  <struct name="_gpio_context_t" line="79" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\GPIO.h">
   <member name="port_identifier" offset="0" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
  </struct>
  <struct name="_uart_context_t" line="109" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\UART.h">
   <member name="buffer_size" offset="0" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
  </struct>
  <struct name="_gpio_ioctl_cb_t" line="84" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\GPIO.h">
   <member name="ioctl_code" offset="0" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="value" offset="8" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
  </struct>
  <struct name="_usb_hubStatus_t" line="378" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USB.h">
   <member name="localPowerSource" offset="0" size="1"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="overCurrent" offset="1" size="1"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="resv1" offset="2" size="14"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="localPowerSourceChange" offset="16" size="1"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="overCurrentChange" offset="17" size="1"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="resv2" offset="18" size="14"
    basetype="SHORT" baseattr="unsigned,"/>
  </struct>
  <struct name="_vos_semaphore_t" line="143" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h">
   <member name="val" offset="0" size="16"
    basetype="SHORT" baseattr="signed,"/>
   <member name="threads" offset="16" size="16"
    basename="_vos_tcb_t" basetype="STRUCT" baseattr="ptr,"/>
   <member name="usage_count" offset="32" size="8"
    basetype="CHAR" baseattr="signed,"/>
  </struct>
  <struct name="_usbslaveft232_ioctl_cb_descriptors_t" line="35" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USBSlaveFT232.h">
   <member name="device_descriptor" offset="0" size="64"
    basename="__unnamed_struct_8" basetype="STRUCT" baseattr=""/>
   <member name="config_descriptor" offset="64" size="24"
    basename="__unnamed_struct_9" basetype="STRUCT" baseattr=""/>
   <member name="zero_string" offset="88" size="16"
    basename="_usb_deviceStringDescriptorZero_t" basetype="STRUCT" baseattr="ptr,"/>
   <member name="manufacturer_string" offset="104" size="16"
    basename="_usb_deviceStringDescriptor_t" basetype="STRUCT" baseattr="ptr,"/>
   <member name="product_string" offset="120" size="16"
    basename="_usb_deviceStringDescriptor_t" basetype="STRUCT" baseattr="ptr,"/>
   <member name="serial_number_string" offset="136" size="16"
    basename="_usb_deviceStringDescriptor_t" basetype="STRUCT" baseattr="ptr,"/>
  </struct>
  <struct name="_usb_deviceConfigurationDescriptor_t" line="261" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USB.h">
   <member name="bLength" offset="0" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="bDescriptorType" offset="8" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="wTotalLength" offset="16" size="16"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="bNumInterfaces" offset="32" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="bConfigurationValue" offset="40" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="iConfiguration" offset="48" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="bmAttributes" offset="56" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="bMaxPower" offset="64" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
  </struct>
  <struct name="_vos_dma_config_t" line="39" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\dma.h">
   <member name="src" offset="0" size="16"
    basename="__unnamed_struct_1" basetype="STRUCT" baseattr=""/>
   <member name="dest" offset="16" size="16"
    basename="__unnamed_struct_2" basetype="STRUCT" baseattr=""/>
   <member name="bufsiz" offset="32" size="16"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="mode" offset="48" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="fifosize" offset="56" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="flow_control" offset="64" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="afull_trigger" offset="72" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
  </struct>
  <enum name="USBSLAVEFT232_STRING_DESCRIPTOR_INDEX" line="56" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USBSlaveFT232.h">
   <value name="FT232_STRING_INDEX_NONE" const="0"/>
   <value name="FT232_STRING_INDEX_MANUFACTURER" const="1"/>
   <value name="FT232_STRING_INDEX_PRODUCT" const="2"/>
   <value name="FT232_STRING_INDEX_SERIAL_NUMBER" const="3"/>
  </enum>
  <enum name="__anon_enum_type_1" line="73" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h">
   <value name="IDLE" const="0"/>
   <value name="BLOCKED" const="1"/>
   <value name="READY" const="2"/>
   <value name="RUNNING" const="3"/>
   <value name="DELAYED" const="4"/>
   <value name="GONE" const="5"/>
  </enum>
  <enum name="__anon_enum_type_2" line="93" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USBSlave.h">
   <value name="USBSLAVE_CONTROL_SETUP" const="0"/>
   <value name="USBSLAVE_CONTROL_OUT" const="1"/>
   <value name="USBSLAVE_CONTROL_IN" const="2"/>
  </enum>
  <enum name="__anon_enum_type_3" line="104" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USBSlave.h">
   <value name="usbsStateNotAttached" const="0"/>
   <value name="usbsStateAttached" const="1"/>
   <value name="usbsStatePowered" const="2"/>
   <value name="usbsStateDefault" const="3"/>
   <value name="usbsStateAddress" const="4"/>
   <value name="usbsStateConfigured" const="5"/>
   <value name="usbsStateSuspended" const="6"/>
  </enum>
  <enum name="__anon_enum_type_4" line="118" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USBSlave.h">
   <value name="usbsEvReset" const="0"/>
   <value name="usbsEvAddressAssigned" const="1"/>
   <value name="usbsEvDeviceConfigured" const="2"/>
   <value name="usbsEvDeviceDeconfigured" const="3"/>
   <value name="usbsEvHubReset" const="4"/>
   <value name="usbsEvHubConfigured" const="5"/>
   <value name="usbsEvHubDeconfigured" const="6"/>
   <value name="usbsEvBusActivity" const="7"/>
   <value name="usbsEvBusInactive" const="8"/>
   <value name="usbsEvPowerInterruption" const="9"/>
  </enum>
  <struct name="__unnamed_struct_1" line="44" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\dma.h">
   <member name="io_addr" offset="0" size="16"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="mem_addr" offset="0" size="16"
    basetype="CHAR" baseattr="unsigned,ptr,"/>
  </struct>
  <struct name="__unnamed_struct_2" line="49" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\dma.h">
   <member name="io_addr" offset="0" size="16"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="mem_addr" offset="0" size="16"
    basetype="CHAR" baseattr="unsigned,ptr,"/>
  </struct>
  <struct name="__unnamed_struct_3" line="77" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USBSlave.h">
   <member name="in_mask" offset="0" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="out_mask" offset="8" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
  </struct>
  <struct name="__unnamed_struct_4" line="82" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USBSlave.h">
   <member name="buffer" offset="0" size="16"
    basetype="CHAR" baseattr="unsigned,ptr,"/>
   <member name="size" offset="16" size="16"
    basetype="SHORT" baseattr="signed,"/>
   <member name="bytes_transferred" offset="32" size="16"
    basetype="SHORT" baseattr="signed,"/>
  </struct>
  <struct name="__unnamed_struct_5" line="84" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USBSlave.h">
   <member name="set_ep_masks" offset="0" size="16"
    basename="__unnamed_struct_3" basetype="STRUCT" baseattr=""/>
   <member name="setup_or_bulk_transfer" offset="0" size="48"
    basename="__unnamed_struct_4" basetype="STRUCT" baseattr=""/>
   <member name="ep_max_packet_size" offset="0" size="32"
    basetype="INT" baseattr="unsigned,"/>
  </struct>
  <struct name="__unnamed_struct_6" line="66" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\ioctl.h">
   <member name="uart_baud_rate" offset="0" size="32"
    basetype="LONG" baseattr="unsigned,"/>
   <member name="spi_master_sck_freq" offset="0" size="32"
    basetype="LONG" baseattr="unsigned,"/>
   <member name="param" offset="0" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="data" offset="0" size="16"
    basetype="VOID" baseattr="ptr,"/>
  </struct>
  <struct name="__unnamed_struct_7" line="73" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\ioctl.h">
   <member name="spi_master_sck_freq" offset="0" size="32"
    basetype="LONG" baseattr="unsigned,"/>
   <member name="queue_stat" offset="0" size="16"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="param" offset="0" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="data" offset="0" size="16"
    basetype="VOID" baseattr="ptr,"/>
  </struct>
  <struct name="__unnamed_struct_8" line="43" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USBSlaveFT232.h">
   <member name="use" offset="0" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="idVendor" offset="8" size="16"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="idProduct" offset="24" size="16"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="iManufacturer" offset="40" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="iProduct" offset="48" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="iSerialNumber" offset="56" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
  </struct>
  <struct name="__unnamed_struct_9" line="48" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USBSlaveFT232.h">
   <member name="use" offset="0" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="bmAttributes" offset="8" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="bMaxPower" offset="16" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
  </struct>
  <struct name="_common_ioctl_cb_t" line="58" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\ioctl.h">
   <member name="ioctl_code" offset="0" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="set" offset="8" size="32"
    basename="__unnamed_struct_6" basetype="STRUCT" baseattr=""/>
   <member name="get" offset="40" size="32"
    basename="__unnamed_struct_7" basetype="STRUCT" baseattr=""/>
  </struct>
  <enum name="GPIO_STATUS" line="69" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\GPIO.h">
   <value name="GPIO_OK" const="0"/>
   <value name="GPIO_INVALID_PORT_IDENTIFIER" const="1"/>
   <value name="GPIO_INVALID_PARAMETER" const="2"/>
   <value name="GPIO_INTERRUPT_NOT_ENABLED" const="3"/>
   <value name="GPIO_ERROR" const="4"/>
   <value name="GPIO_FATAL_ERROR" const="255"/>
  </enum>
  <enum name="UART_STATUS" line="100" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\UART.h">
   <value name="UART_OK" const="0"/>
   <value name="UART_INVALID_PARAMETER" const="1"/>
   <value name="UART_DMA_NOT_ENABLED" const="2"/>
   <value name="UART_ERROR" const="3"/>
   <value name="UART_FATAL_ERROR" const="255"/>
  </enum>
  <enum name="IOMUX_STATUS" line="190" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\iomux.h">
   <value name="IOMUX_OK" const="0"/>
   <value name="IOMUX_INVALID_SIGNAL" const="1"/>
   <value name="IOMUX_INVALID_PIN_SELECTION" const="2"/>
   <value name="IOMUX_UNABLE_TO_ROUTE_SIGNAL" const="3"/>
   <value name="IOMUX_INVLAID_IOCELL_DRIVE_CURRENT" const="4"/>
   <value name="IOMUX_INVLAID_IOCELL_TRIGGER" const="5"/>
   <value name="IOMUX_INVLAID_IOCELL_SLEW_RATE" const="6"/>
   <value name="IOMUX_INVLAID_IOCELL_PULL" const="7"/>
   <value name="IOMUX_ERROR" const="8"/>
  </enum>
  <struct name="_usb_hub_selector_t" line="421" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USB.h">
   <member name="hub_port" offset="0" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="selector" offset="8" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
  </struct>
  <struct name="_usbSlaveFt232_init_t" line="70" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USBSlaveFT232.h">
   <member name="in_ep_buffer_len" offset="0" size="16"
    basetype="SHORT" baseattr="unsigned,"/>
   <member name="out_ep_buffer_len" offset="16" size="16"
    basetype="SHORT" baseattr="unsigned,"/>
  </struct>
  <struct name="_usb_deviceStringDescriptor_t" line="321" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USB.h">
   <member name="bLength" offset="0" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="bDescriptorType" offset="8" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
   <member name="bString" offset="16" size="8"
    basetype="CHAR" baseattr="unsigned,"/>
  </struct>
  <typedef name="usbslave_ep_handle_t" line="31" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USBSlave.h"
   basetype="CHAR" baseattr="unsigned,"/>
  <typedef name="usb_deviceEndpointDescriptor_t" line="301" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USB.h"
   basename="_usb_deviceEndpointDescriptor_t" basetype="STRUCT" baseattr=""/>
  <typedef name="vos_semaphore_list_t" line="156" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basename="_vos_semaphore_list_t" basetype="STRUCT" baseattr=""/>
  <proto name="PF" line="35" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basetype="CHAR" baseattr="signed,">
   <typedef name="__unknown" line="35" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
    basetype="CHAR" baseattr="unsigned,"/>
  </proto>
  <typedef name="usb_deviceInterfaceDescriptor_t" line="290" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USB.h"
   basename="_usb_deviceInterfaceDescriptor_t" basetype="STRUCT" baseattr=""/>
  <typedef name="usb_deviceQualifierDescriptor_t" line="258" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USB.h"
   basename="_usb_deviceQualifierDescriptor_t" basetype="STRUCT" baseattr=""/>
  <typedef name="vos_mutex_t" line="125" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basename="_vos_mutex_t" basetype="STRUCT" baseattr=""/>
  <typedef name="vos_device_t" line="40" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\devman.h"
   basename="_vos_device_t" basetype="STRUCT" baseattr=""/>
  <typedef name="usb_deviceDescriptor_t" line="244" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USB.h"
   basename="_usb_deviceDescriptor_t" basetype="STRUCT" baseattr=""/>
  <typedef name="vos_driver_t" line="33" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\devman.h"
   basename="_vos_driver_t" basetype="STRUCT" baseattr=""/>
  <typedef name="vos_system_data_area_t" line="198" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basename="_vos_system_data_area_t" basetype="STRUCT" baseattr=""/>
  <typedef name="usb_deviceStringDescriptorZero_t" line="318" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USB.h"
   basename="_usb_deviceStringDescriptorZero_t" basetype="STRUCT" baseattr=""/>
  <proto name="PF_IO" line="39" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basetype="CHAR" baseattr="signed,">
   <typedef name="__unknown" line="39" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
    basetype="CHAR" baseattr="unsigned,ptr,"/>
   <typedef name="__unknown" line="39" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
    basetype="SHORT" baseattr="unsigned,"/>
   <typedef name="__unknown" line="39" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
    basetype="SHORT" baseattr="unsigned,ptr,"/>
  </proto>
  <typedef name="vos_cond_var_t" line="178" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basename="_vos_cond_var_t" basetype="STRUCT" baseattr=""/>
  <proto name="PF_INT" line="40" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basetype="VOID" baseattr="">
  </proto>
  <typedef name="gpio_context_t" line="81" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\GPIO.h"
   basename="_gpio_context_t" basetype="STRUCT" baseattr=""/>
  <typedef name="uart_context_t" line="111" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\UART.h"
   basename="_uart_context_t" basetype="STRUCT" baseattr=""/>
  <typedef name="gpio_ioctl_cb_t" line="87" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\GPIO.h"
   basename="_gpio_ioctl_cb_t" basetype="STRUCT" baseattr=""/>
  <proto name="PF_OPEN" line="36" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basetype="VOID" baseattr="">
   <typedef name="__unknown" line="36" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
    basetype="VOID" baseattr="ptr,"/>
  </proto>
  <typedef name="usb_hubStatus_t" line="388" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USB.h"
   basename="_usb_hubStatus_t" basetype="STRUCT" baseattr=""/>
  <typedef name="vos_semaphore_t" line="147" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basename="_vos_semaphore_t" basetype="STRUCT" baseattr=""/>
  <typedef name="usbslaveft232_ioctl_cb_descriptors_t" line="53" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USBSlaveFT232.h"
   basename="_usbslaveft232_ioctl_cb_descriptors_t" basetype="STRUCT" baseattr=""/>
  <typedef name="usb_deviceConfigurationDescriptor_t" line="271" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USB.h"
   basename="_usb_deviceConfigurationDescriptor_t" basetype="STRUCT" baseattr=""/>
  <proto name="PF_CLOSE" line="37" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basetype="VOID" baseattr="">
   <typedef name="__unknown" line="37" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
    basetype="VOID" baseattr="ptr,"/>
  </proto>
  <proto name="PF_IOCTL" line="38" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basetype="CHAR" baseattr="signed,">
   <typedef name="__unknown" line="38" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
    basetype="CHAR" baseattr="unsigned,ptr,"/>
  </proto>
  <typedef name="vos_dma_config_t" line="55" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\dma.h"
   basename="_vos_dma_config_t" basetype="STRUCT" baseattr=""/>
  <typedef name="common_ioctl_cb_t" line="74" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\ioctl.h"
   basename="_common_ioctl_cb_t" basetype="STRUCT" baseattr=""/>
  <typedef name="usb_hub_selector_t" line="424" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USB.h"
   basename="_usb_hub_selector_t" basetype="STRUCT" baseattr=""/>
  <typedef name="usbSlaveFt232_init_t" line="73" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USBSlaveFT232.h"
   basename="_usbSlaveFt232_init_t" basetype="STRUCT" baseattr=""/>
  <typedef name="usb_deviceStringDescriptor_t" line="329" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USB.h"
   basename="_usb_deviceStringDescriptor_t" basetype="STRUCT" baseattr=""/>
  <proto name="fnVoidPtr" line="42" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basetype="VOID" baseattr="">
  </proto>
  <typedef name="vos_tcb_t" line="95" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basename="_vos_tcb_t" basetype="STRUCT" baseattr=""/>
  <typedef name="usb_deviceRequest_t" line="178" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USB.h"
   basename="_usb_deviceRequest_t" basetype="STRUCT" baseattr=""/>
  <typedef name="usbslave_ioctl_cb_t" line="85" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USBSlave.h"
   basename="_usbslave_ioctl_cb_t" basetype="STRUCT" baseattr=""/>
  <typedef name="usb_hubDescriptor_t" line="344" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USB.h"
   basename="_usb_hubDescriptor_t" basetype="STRUCT" baseattr=""/>
  <typedef name="usb_hubPortStatus_t" line="419" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USB.h"
   basename="_usb_hubPortStatus_t" basetype="STRUCT" baseattr=""/>
  <label name="main_loop" line="140" file="USBSlaveFT232Emu.c"/>  <proto name="open_drivers" line="263" file="USBSlaveFT232Emu.c"
   basetype="VOID" baseattr="">
  </proto>
  <proto name="close_drivers" line="280" file="USBSlaveFT232Emu.c"
   basetype="VOID" baseattr="">
  </proto>
  <proto name="main" line="89" file="USBSlaveFT232Emu.c"
   basetype="VOID" baseattr="">
  </proto>
  <proto name="attach_drivers" line="273" file="USBSlaveFT232Emu.c"
   basetype="VOID" baseattr="">
  </proto>
  <proto name="initialize_gpio" line="250" file="USBSlaveFT232Emu.c"
   basetype="VOID" baseattr="">
   <var name="hGPIO" line="250" file="USBSlaveFT232Emu.c"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="SHORT" baseattr="unsigned,"/>
  </proto>
  <proto name="initialize_uart" line="215" file="USBSlaveFT232Emu.c"
   basetype="VOID" baseattr="">
   <var name="hUart" line="215" file="USBSlaveFT232Emu.c"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="SHORT" baseattr="unsigned,"/>
  </proto>
  <proto name="uartRx" line="342" file="USBSlaveFT232Emu.c"
   basetype="VOID" baseattr="">
  </proto>
  <proto name="uartTx" line="293" file="USBSlaveFT232Emu.c"
   basetype="VOID" baseattr="">
  </proto>
  <proto name="ft232_slave_detach" line="202" file="USBSlaveFT232Emu.c"
   basetype="VOID" baseattr="">
   <var name="hSlaveFT232" line="202" file="USBSlaveFT232Emu.c"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="SHORT" baseattr="unsigned,"/>
  </proto>
  <proto name="ft232_slave_attach" line="146" file="USBSlaveFT232Emu.c"
   basetype="SHORT" baseattr="unsigned,">
   <var name="hUSB" line="146" file="USBSlaveFT232Emu.c"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="SHORT" baseattr="unsigned,"/>
   <var name="devSlaveFT232" line="146" file="USBSlaveFT232Emu.c"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="CHAR" baseattr="unsigned,"/>
  </proto>
  <proto name="vos_dma_get_fifo_flow_control" line="82" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\dma.h"
   basetype="CHAR" baseattr="unsigned,">
   <var name="h" line="82" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\dma.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="SHORT" baseattr="unsigned,"/>
  </proto>
  <proto name="vos_start_scheduler" line="53" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basetype="VOID" baseattr="">
  </proto>
  <proto name="vos_signal_semaphore_from_isr" line="168" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basetype="VOID" baseattr="">
   <var name="s" line="168" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basename="_vos_semaphore_t" basetype="STRUCT" baseattr="ptr,"/>
  </proto>
  <proto name="vos_malloc" line="24" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\memmgmt.h"
   basetype="VOID" baseattr="ptr,">
   <var name="size" line="24" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\memmgmt.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="SHORT" baseattr="unsigned,"/>
  </proto>
  <proto name="vos_create_thread_ex" line="98" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basename="_vos_tcb_t" basetype="STRUCT" baseattr="ptr,">
   <var name="priority" line="98" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="CHAR" baseattr="unsigned,"/>
   <var name="stack" line="98" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="SHORT" baseattr="unsigned,"/>
   <var name="function" line="98" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
    type="FUNCTION" storage="AUTO VAR" attr="param,"
    basetype="VOID" baseattr=""/>
   <var name="name" line="98" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="CHAR" baseattr="signed,ptr,"/>
   <var name="arg_size" line="98" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="SHORT" baseattr="signed,"/>
  </proto>
  <proto name="vos_memcpy" line="27" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\memmgmt.h"
   basetype="VOID" baseattr="ptr,">
   <var name="destination" line="27" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\memmgmt.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="VOID" baseattr="ptr,"/>
   <var name="source" line="27" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\memmgmt.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="VOID" baseattr="const,ptr,"/>
   <var name="num" line="27" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\memmgmt.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="SHORT" baseattr="signed,"/>
  </proto>
  <proto name="vos_memset" line="26" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\memmgmt.h"
   basetype="VOID" baseattr="ptr,">
   <var name="dstptr" line="26" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\memmgmt.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="VOID" baseattr="ptr,"/>
   <var name="value" line="26" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\memmgmt.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="INT" baseattr="signed,"/>
   <var name="num" line="26" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\memmgmt.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="SHORT" baseattr="signed,"/>
  </proto>
  <proto name="vos_get_kernel_clock" line="248" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basetype="INT" baseattr="unsigned,">
  </proto>
  <proto name="vos_get_package_type" line="217" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basetype="CHAR" baseattr="unsigned,">
  </proto>
  <proto name="vos_dma_get_fifo_data_register" line="81" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\dma.h"
   basetype="SHORT" baseattr="unsigned,">
   <var name="h" line="81" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\dma.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="SHORT" baseattr="unsigned,"/>
  </proto>
  <proto name="vos_signal_semaphore" line="167" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basetype="VOID" baseattr="">
   <var name="s" line="167" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basename="_vos_semaphore_t" basetype="STRUCT" baseattr="ptr,"/>
  </proto>
  <proto name="vos_dma_get_fifo_data" line="84" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\dma.h"
   basetype="CHAR" baseattr="unsigned,">
   <var name="h" line="84" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\dma.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="SHORT" baseattr="unsigned,"/>
   <var name="dat" line="84" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\dma.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="CHAR" baseattr="unsigned,ptr,"/>
  </proto>
  <proto name="vos_iocell_get_config" line="228" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\iomux.h"
   basetype="CHAR" baseattr="unsigned,">
   <var name="pin" line="228" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\iomux.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="CHAR" baseattr="unsigned,"/>
   <var name="drive_current" line="228" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\iomux.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="CHAR" baseattr="unsigned,ptr,"/>
   <var name="trigger" line="228" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\iomux.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="CHAR" baseattr="unsigned,ptr,"/>
   <var name="slew_rate" line="228" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\iomux.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="CHAR" baseattr="unsigned,ptr,"/>
   <var name="pull" line="228" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\iomux.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="CHAR" baseattr="unsigned,ptr,"/>
  </proto>
  <proto name="vos_iomux_define_bidi" line="225" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\iomux.h"
   basetype="CHAR" baseattr="unsigned,">
   <var name="pin" line="225" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\iomux.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="CHAR" baseattr="unsigned,"/>
   <var name="input_signal" line="225" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\iomux.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="CHAR" baseattr="unsigned,"/>
   <var name="output_signal" line="225" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\iomux.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="CHAR" baseattr="unsigned,"/>
  </proto>
  <proto name="vos_iocell_set_config" line="229" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\iomux.h"
   basetype="CHAR" baseattr="unsigned,">
   <var name="pin" line="229" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\iomux.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="CHAR" baseattr="unsigned,"/>
   <var name="drive_current" line="229" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\iomux.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="CHAR" baseattr="unsigned,"/>
   <var name="trigger" line="229" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\iomux.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="CHAR" baseattr="unsigned,"/>
   <var name="slew_rate" line="229" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\iomux.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="CHAR" baseattr="unsigned,"/>
   <var name="pull" line="229" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\iomux.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="CHAR" baseattr="unsigned,"/>
  </proto>
  <proto name="iomux_setup" line="86" file="USBSlaveFT232Emu.c"
   basetype="VOID" baseattr="">
  </proto>
  <proto name="vos_get_chip_revision" line="220" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basetype="CHAR" baseattr="unsigned,">
  </proto>
  <proto name="vos_wait_semaphore_ex" line="166" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basetype="CHAR" baseattr="signed,">
   <var name="l" line="166" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basename="_vos_semaphore_list_t" basetype="STRUCT" baseattr="ptr,"/>
  </proto>
  <proto name="vos_enable_interrupts" line="72" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\devman.h"
   basetype="VOID" baseattr="">
   <var name="mask" line="72" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\devman.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="INT" baseattr="unsigned,"/>
  </proto>
  <proto name="vos_dev_read" line="54" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\devman.h"
   basetype="CHAR" baseattr="unsigned,">
   <var name="h" line="54" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\devman.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="SHORT" baseattr="unsigned,"/>
   <var name="buf" line="54" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\devman.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="CHAR" baseattr="unsigned,ptr,"/>
   <var name="num_to_read" line="54" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\devman.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="SHORT" baseattr="unsigned,"/>
   <var name="num_read" line="54" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\devman.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="SHORT" baseattr="unsigned,ptr,"/>
  </proto>
  <proto name="vos_dev_open" line="53" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\devman.h"
   basetype="SHORT" baseattr="unsigned,">
   <var name="dev_num" line="53" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\devman.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="CHAR" baseattr="unsigned,"/>
  </proto>
  <proto name="vos_halt_cpu" line="232" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basetype="VOID" baseattr="">
  </proto>
  <proto name="vos_dev_init" line="50" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\devman.h"
   basetype="VOID" baseattr="">
   <var name="dev_num" line="50" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\devman.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="CHAR" baseattr="unsigned,"/>
   <var name="driver_cb" line="50" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\devman.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basename="_vos_driver_t" basetype="STRUCT" baseattr="ptr,"/>
   <var name="context" line="50" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\devman.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="VOID" baseattr="ptr,"/>
  </proto>
  <proto name="vos_dma_get_fifo_count" line="83" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\dma.h"
   basetype="SHORT" baseattr="unsigned,">
   <var name="h" line="83" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\dma.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="SHORT" baseattr="unsigned,"/>
  </proto>
  <proto name="vos_reset_kernel_clock" line="249" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basetype="VOID" baseattr="">
  </proto>
  <proto name="vos_iomux_define_input" line="223" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\iomux.h"
   basetype="CHAR" baseattr="unsigned,">
   <var name="pin" line="223" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\iomux.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="CHAR" baseattr="unsigned,"/>
   <var name="signal" line="223" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\iomux.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="CHAR" baseattr="unsigned,"/>
  </proto>
  <proto name="vos_disable_interrupts" line="73" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\devman.h"
   basetype="VOID" baseattr="">
   <var name="mask" line="73" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\devman.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="INT" baseattr="unsigned,"/>
  </proto>
  <proto name="vos_get_idle_thread_tcb" line="101" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basename="_vos_tcb_t" basetype="STRUCT" baseattr="ptr,">
  </proto>
  <proto name="vos_dev_close" line="57" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\devman.h"
   basetype="VOID" baseattr="">
   <var name="h" line="57" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\devman.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="SHORT" baseattr="unsigned,"/>
  </proto>
  <proto name="vos_wdt_clear" line="245" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basetype="VOID" baseattr="">
  </proto>
  <proto name="vos_heap_size" line="29" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\memmgmt.h"
   basetype="SHORT" baseattr="unsigned,">
  </proto>
  <proto name="vos_dev_ioctl" line="56" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\devman.h"
   basetype="CHAR" baseattr="unsigned,">
   <var name="h" line="56" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\devman.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="SHORT" baseattr="unsigned,"/>
   <var name="cb" line="56" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\devman.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="VOID" baseattr="ptr,"/>
  </proto>
  <proto name="usbslave_init" line="128" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USBSlave.h"
   basetype="CHAR" baseattr="unsigned,">
   <var name="s_num" line="128" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USBSlave.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="CHAR" baseattr="unsigned,"/>
   <var name="d_num" line="128" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USBSlave.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="CHAR" baseattr="unsigned,"/>
  </proto>
  <proto name="vos_dev_write" line="55" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\devman.h"
   basetype="CHAR" baseattr="unsigned,">
   <var name="h" line="55" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\devman.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="SHORT" baseattr="unsigned,"/>
   <var name="buf" line="55" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\devman.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="CHAR" baseattr="unsigned,ptr,"/>
   <var name="num_to_write" line="55" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\devman.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="SHORT" baseattr="unsigned,"/>
   <var name="num_written" line="55" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\devman.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="SHORT" baseattr="unsigned,ptr,"/>
  </proto>
  <proto name="vos_get_clock_frequency" line="210" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basetype="CHAR" baseattr="unsigned,">
  </proto>
  <proto name="vos_set_clock_frequency" line="209" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basetype="VOID" baseattr="">
   <var name="frequency" line="209" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="CHAR" baseattr="unsigned,"/>
  </proto>
  <proto name="vos_dma_enable" line="78" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\dma.h"
   basetype="CHAR" baseattr="unsigned,">
   <var name="h" line="78" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\dma.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="SHORT" baseattr="unsigned,"/>
  </proto>
  <proto name="vos_reset_vnc2" line="235" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basetype="VOID" baseattr="">
  </proto>
  <proto name="vos_heap_space" line="30" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\memmgmt.h"
   basetype="VOID" baseattr="">
   <var name="hfree" line="30" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\memmgmt.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="SHORT" baseattr="unsigned,ptr,"/>
   <var name="hmax" line="30" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\memmgmt.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="SHORT" baseattr="unsigned,ptr,"/>
  </proto>
  <proto name="vos_iomux_define_output" line="224" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\iomux.h"
   basetype="CHAR" baseattr="unsigned,">
   <var name="pin" line="224" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\iomux.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="CHAR" baseattr="unsigned,"/>
   <var name="signal" line="224" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\iomux.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="CHAR" baseattr="unsigned,"/>
  </proto>
  <proto name="vos_wdt_enable" line="244" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basetype="CHAR" baseattr="unsigned,">
   <var name="bitPosition" line="244" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="CHAR" baseattr="unsigned,"/>
  </proto>
  <proto name="vos_dma_wait_on_complete" line="80" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\dma.h"
   basetype="VOID" baseattr="">
   <var name="h" line="80" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\dma.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="SHORT" baseattr="unsigned,"/>
  </proto>
  <proto name="vos_lock_mutex" line="132" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basetype="VOID" baseattr="">
   <var name="m" line="132" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basename="_vos_mutex_t" basetype="STRUCT" baseattr="ptr,"/>
  </proto>
  <proto name="vos_power_down" line="229" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basetype="CHAR" baseattr="unsigned,">
   <var name="wakeMask" line="229" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="CHAR" baseattr="unsigned,"/>
  </proto>
  <proto name="vos_init_mutex" line="131" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basetype="VOID" baseattr="">
   <var name="m" line="131" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basename="_vos_mutex_t" basetype="STRUCT" baseattr="ptr,"/>
   <var name="state" line="131" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="CHAR" baseattr="unsigned,"/>
  </proto>
  <proto name="vos_get_priority_ceiling" line="135" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basetype="CHAR" baseattr="unsigned,">
   <var name="m" line="135" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basename="_vos_mutex_t" basetype="STRUCT" baseattr="ptr,"/>
  </proto>
  <proto name="vos_dma_disable" line="79" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\dma.h"
   basetype="CHAR" baseattr="unsigned,">
   <var name="h" line="79" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\dma.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="SHORT" baseattr="unsigned,"/>
  </proto>
  <proto name="vos_set_priority_ceiling" line="136" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basetype="VOID" baseattr="">
   <var name="m" line="136" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basename="_vos_mutex_t" basetype="STRUCT" baseattr="ptr,"/>
   <var name="priority" line="136" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="CHAR" baseattr="unsigned,"/>
  </proto>
  <proto name="vos_dma_release" line="75" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\dma.h"
   basetype="VOID" baseattr="">
   <var name="h" line="75" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\dma.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="SHORT" baseattr="unsigned,"/>
  </proto>
  <proto name="vos_iomux_disable_output" line="226" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\iomux.h"
   basetype="CHAR" baseattr="unsigned,">
   <var name="pin" line="226" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\iomux.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="CHAR" baseattr="unsigned,"/>
  </proto>
  <proto name="vos_dma_acquire" line="74" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\dma.h"
   basetype="SHORT" baseattr="unsigned,">
  </proto>
  <proto name="vos_delay_msecs" line="103" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basetype="CHAR" baseattr="unsigned,">
   <var name="ms" line="103" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="SHORT" baseattr="unsigned,"/>
  </proto>
  <proto name="vos_stack_usage" line="188" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basetype="SHORT" baseattr="unsigned,">
   <var name="tcb" line="188" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basename="_vos_tcb_t" basetype="STRUCT" baseattr="ptr,"/>
  </proto>
  <proto name="vos_get_profile" line="191" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basetype="INT" baseattr="unsigned,">
   <var name="tcb" line="191" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basename="_vos_tcb_t" basetype="STRUCT" baseattr="ptr,"/>
  </proto>
  <proto name="vos_delay_cancel" line="104" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basetype="VOID" baseattr="">
   <var name="tcb" line="104" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basename="_vos_tcb_t" basetype="STRUCT" baseattr="ptr,"/>
  </proto>
  <proto name="vos_dma_retained_configure" line="77" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\dma.h"
   basetype="CHAR" baseattr="unsigned,">
   <var name="h" line="77" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\dma.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="SHORT" baseattr="unsigned,"/>
   <var name="mem_addr" line="77" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\dma.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="CHAR" baseattr="unsigned,ptr,"/>
   <var name="bufsiz" line="77" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\dma.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="SHORT" baseattr="unsigned,"/>
  </proto>
  <proto name="vos_unlock_mutex" line="134" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basetype="VOID" baseattr="">
   <var name="m" line="134" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basename="_vos_mutex_t" basetype="STRUCT" baseattr="ptr,"/>
  </proto>
  <proto name="usbslaveft232_init" line="76" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USBSlaveFT232.h"
   basetype="CHAR" baseattr="unsigned,">
   <var name="vos_dev_num" line="76" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USBSlaveFT232.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="CHAR" baseattr="unsigned,"/>
   <var name="params" line="76" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\USBSlaveFT232.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basename="_usbSlaveFt232_init_t" basetype="STRUCT" baseattr="ptr,"/>
  </proto>
  <proto name="vos_create_thread" line="97" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basename="_vos_tcb_t" basetype="STRUCT" baseattr="ptr,">
   <var name="priority" line="97" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="CHAR" baseattr="unsigned,"/>
   <var name="stack" line="97" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="SHORT" baseattr="unsigned,"/>
   <var name="function" line="97" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
    type="FUNCTION" storage="AUTO VAR" attr="param,"
    basetype="VOID" baseattr=""/>
   <var name="arg_size" line="97" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="SHORT" baseattr="signed,"/>
  </proto>
  <proto name="vos_dma_configure" line="76" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\dma.h"
   basetype="CHAR" baseattr="unsigned,">
   <var name="h" line="76" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\dma.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="SHORT" baseattr="unsigned,"/>
   <var name="cb" line="76" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\dma.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basename="_vos_dma_config_t" basetype="STRUCT" baseattr="ptr,"/>
  </proto>
  <proto name="vos_init_cond_var" line="180" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basetype="VOID" baseattr="">
   <var name="cv" line="180" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basename="_vos_cond_var_t" basetype="STRUCT" baseattr="ptr,"/>
  </proto>
  <proto name="vos_wait_cond_var" line="181" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basetype="VOID" baseattr="">
   <var name="cv" line="181" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basename="_vos_cond_var_t" basetype="STRUCT" baseattr="ptr,"/>
   <var name="m" line="181" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basename="_vos_mutex_t" basetype="STRUCT" baseattr="ptr,"/>
  </proto>
  <proto name="vos_stop_profiler" line="190" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basetype="VOID" baseattr="">
  </proto>
  <proto name="vos_trylock_mutex" line="133" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basetype="CHAR" baseattr="unsigned,">
   <var name="m" line="133" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basename="_vos_mutex_t" basetype="STRUCT" baseattr="ptr,"/>
  </proto>
  <proto name="vos_free" line="25" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\memmgmt.h"
   basetype="VOID" baseattr="">
   <var name="ptrFree" line="25" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\memmgmt.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="VOID" baseattr="ptr,"/>
  </proto>
  <proto name="vos_init" line="52" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basetype="VOID" baseattr="">
   <var name="quantum" line="52" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="CHAR" baseattr="unsigned,"/>
   <var name="tick_cnt" line="52" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="SHORT" baseattr="unsigned,"/>
   <var name="num_devices" line="52" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="CHAR" baseattr="unsigned,"/>
  </proto>
  <proto name="vos_set_idle_thread_tcb_size" line="100" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basetype="VOID" baseattr="">
   <var name="tcb_size" line="100" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="SHORT" baseattr="unsigned,"/>
  </proto>
  <proto name="vos_init_semaphore" line="164" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basetype="VOID" baseattr="">
   <var name="sem" line="164" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basename="_vos_semaphore_t" basetype="STRUCT" baseattr="ptr,"/>
   <var name="count" line="164" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="SHORT" baseattr="signed,"/>
  </proto>
  <proto name="vos_wait_semaphore" line="165" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basetype="VOID" baseattr="">
   <var name="s" line="165" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basename="_vos_semaphore_t" basetype="STRUCT" baseattr="ptr,"/>
  </proto>
  <proto name="vos_start_profiler" line="189" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basetype="VOID" baseattr="">
  </proto>
  <proto name="gpio_init" line="93" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\GPIO.h"
   basetype="CHAR" baseattr="unsigned,">
   <var name="devNum" line="91" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\GPIO.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="CHAR" baseattr="unsigned,"/>
   <var name="context" line="92" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\GPIO.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="VOID" baseattr="ptr,"/>
  </proto>
  <proto name="uart_init" line="117" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\UART.h"
   basetype="CHAR" baseattr="unsigned,">
   <var name="devNum" line="115" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\UART.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basetype="CHAR" baseattr="unsigned,"/>
   <var name="context" line="116" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\drivers\include\UART.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basename="_uart_context_t" basetype="STRUCT" baseattr="ptr,"/>
  </proto>
  <proto name="vos_signal_cond_var" line="182" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
   basetype="VOID" baseattr="">
   <var name="cv" line="182" file="C:\Program Files\FTDI\Vinculum II Toolchain\Firmware\kernel\include\vos.h"
    type="AUTO" storage="AUTO VAR" attr="param,"
    basename="_vos_cond_var_t" basetype="STRUCT" baseattr="ptr,"/>
  </proto>
  <var name="mfg_string" line="28" file="USBSlaveFT232Emu.c"
   type="AUTO" storage="AUTO VAR" attr="global,"
   basetype="CHAR" baseattr="unsigned," basearray="18,"/>
  <var name="hUSBSLAVE_FT232" line="37" file="USBSlaveFT232Emu.h"
   type="AUTO" storage="AUTO VAR" attr="global,"
   basetype="SHORT" baseattr="unsigned,"/>
  <var name="desc_string" line="43" file="USBSlaveFT232Emu.c"
   type="AUTO" storage="AUTO VAR" attr="global,"
   basetype="CHAR" baseattr="unsigned," basearray="28,"/>
  <var name="semConfigured" line="25" file="USBSlaveFT232Emu.c"
   type="AUTO" storage="AUTO VAR" attr="global,"
   basename="_vos_semaphore_t" basetype="STRUCT" baseattr=""/>
  <var name="sernum_string" line="63" file="USBSlaveFT232Emu.c"
   type="AUTO" storage="AUTO VAR" attr="global,"
   basetype="CHAR" baseattr="unsigned," basearray="18,"/>
  <var name="hUART" line="35" file="USBSlaveFT232Emu.h"
   type="AUTO" storage="AUTO VAR" attr="global,"
   basetype="SHORT" baseattr="unsigned,"/>
  <var name="descriptors_cb" line="79" file="USBSlaveFT232Emu.c"
   type="AUTO" storage="AUTO VAR" attr="global,"
   basename="_usbslaveft232_ioctl_cb_descriptors_t" basetype="STRUCT" baseattr=""/>
  <var name="readbuf" line="290" file="USBSlaveFT232Emu.c"
   type="AUTO" storage="AUTO VAR" attr="global,"
   basetype="CHAR" baseattr="unsigned," basearray="128,"/>
  <var name="tcbUARTRX" line="23" file="USBSlaveFT232Emu.c"
   type="AUTO" storage="AUTO VAR" attr="global,"
   basename="_vos_tcb_t" basetype="STRUCT" baseattr="ptr,"/>
  <var name="tcbUARTTX" line="22" file="USBSlaveFT232Emu.c"
   type="AUTO" storage="AUTO VAR" attr="global,"
   basename="_vos_tcb_t" basetype="STRUCT" baseattr="ptr,"/>
  <var name="hUSBSLAVE_1" line="34" file="USBSlaveFT232Emu.h"
   type="AUTO" storage="AUTO VAR" attr="global,"
   basetype="SHORT" baseattr="unsigned,"/>
  <var name="writebuf" line="291" file="USBSlaveFT232Emu.c"
   type="AUTO" storage="AUTO VAR" attr="global,"
   basetype="CHAR" baseattr="unsigned," basearray="128,"/>
  <var name="hGPIO_PORT_A" line="36" file="USBSlaveFT232Emu.h"
   type="AUTO" storage="AUTO VAR" attr="global,"
   basetype="SHORT" baseattr="unsigned,"/>
 <function name="main" line="89" file="USBSlaveFT232Emu.c" 
  basetype="VOID" baseattr="">
  <block line="90" file="USBSlaveFT232Emu.c">
    <var name="gpioContextA" line="97" file="USBSlaveFT232Emu.c"
     type="AUTO" storage="AUTO VAR" attr=""
     basename="_gpio_context_t" basetype="STRUCT" baseattr=""/>
    <var name="ft232Context" line="91" file="USBSlaveFT232Emu.c"
     type="AUTO" storage="AUTO VAR" attr=""
     basename="_usbSlaveFt232_init_t" basetype="STRUCT" baseattr=""/>
    <var name="uartContext" line="95" file="USBSlaveFT232Emu.c"
     type="AUTO" storage="AUTO VAR" attr=""
     basename="_uart_context_t" basetype="STRUCT" baseattr=""/>
    <var name="usbslaveFT232Context" line="99" file="USBSlaveFT232Emu.c"
     type="AUTO" storage="AUTO VAR" attr=""
     basename="_usbSlaveFt232_init_t" basetype="STRUCT" baseattr=""/>
  </block>
 </function>
 <function name="ft232_slave_attach" line="146" file="USBSlaveFT232Emu.c" 
  basetype="SHORT" baseattr="unsigned,">
  <var name="hUSB" line="146" file="USBSlaveFT232Emu.c"
   type="AUTO" storage="AUTO VAR" attr="param,"
   basetype="SHORT" baseattr="unsigned,"/>
  <var name="devSlaveFT232" line="146" file="USBSlaveFT232Emu.c"
   type="AUTO" storage="AUTO VAR" attr="param,"
   basetype="CHAR" baseattr="unsigned,"/>
  <block line="147" file="USBSlaveFT232Emu.c">
    <var name="hUSB" line="146" file="USBSlaveFT232Emu.c"
     type="AUTO" storage="AUTO VAR" attr="param,"
     basetype="SHORT" baseattr="unsigned,"/>
    <var name="hSlaveFT232" line="149" file="USBSlaveFT232Emu.c"
     type="AUTO" storage="AUTO VAR" attr=""
     basetype="SHORT" baseattr="unsigned,"/>
    <var name="devSlaveFT232" line="146" file="USBSlaveFT232Emu.c"
     type="AUTO" storage="AUTO VAR" attr="param,"
     basetype="CHAR" baseattr="unsigned,"/>
    <var name="ft232_iocb" line="148" file="USBSlaveFT232Emu.c"
     type="AUTO" storage="AUTO VAR" attr=""
     basename="_common_ioctl_cb_t" basetype="STRUCT" baseattr=""/>
   <block line="179" file="USBSlaveFT232Emu.c">
   </block>
   <block line="188" file="USBSlaveFT232Emu.c">
   </block>
  </block>
 </function>
 <function name="ft232_slave_detach" line="202" file="USBSlaveFT232Emu.c" 
  basetype="VOID" baseattr="">
  <var name="hSlaveFT232" line="202" file="USBSlaveFT232Emu.c"
   type="AUTO" storage="AUTO VAR" attr="param,"
   basetype="SHORT" baseattr="unsigned,"/>
  <block line="203" file="USBSlaveFT232Emu.c">
    <var name="hSlaveFT232" line="202" file="USBSlaveFT232Emu.c"
     type="AUTO" storage="AUTO VAR" attr="param,"
     basetype="SHORT" baseattr="unsigned,"/>
    <var name="ft232_iocb" line="204" file="USBSlaveFT232Emu.c"
     type="AUTO" storage="AUTO VAR" attr=""
     basename="_common_ioctl_cb_t" basetype="STRUCT" baseattr=""/>
   <block line="206" file="USBSlaveFT232Emu.c">
   </block>
  </block>
 </function>
 <function name="initialize_uart" line="215" file="USBSlaveFT232Emu.c" 
  basetype="VOID" baseattr="">
  <var name="hUart" line="215" file="USBSlaveFT232Emu.c"
   type="AUTO" storage="AUTO VAR" attr="param,"
   basetype="SHORT" baseattr="unsigned,"/>
  <block line="216" file="USBSlaveFT232Emu.c">
    <var name="hUart" line="215" file="USBSlaveFT232Emu.c"
     type="AUTO" storage="AUTO VAR" attr="param,"
     basetype="SHORT" baseattr="unsigned,"/>
    <var name="uart_iocb" line="217" file="USBSlaveFT232Emu.c"
     type="AUTO" storage="AUTO VAR" attr=""
     basename="_common_ioctl_cb_t" basetype="STRUCT" baseattr=""/>
  </block>
 </function>
 <function name="initialize_gpio" line="250" file="USBSlaveFT232Emu.c" 
  basetype="VOID" baseattr="">
  <var name="hGPIO" line="250" file="USBSlaveFT232Emu.c"
   type="AUTO" storage="AUTO VAR" attr="param,"
   basetype="SHORT" baseattr="unsigned,"/>
  <block line="251" file="USBSlaveFT232Emu.c">
    <var name="hGPIO" line="250" file="USBSlaveFT232Emu.c"
     type="AUTO" storage="AUTO VAR" attr="param,"
     basetype="SHORT" baseattr="unsigned,"/>
    <var name="gpio_iocb" line="252" file="USBSlaveFT232Emu.c"
     type="AUTO" storage="AUTO VAR" attr=""
     basename="_gpio_ioctl_cb_t" basetype="STRUCT" baseattr=""/>
  </block>
 </function>
 <function name="open_drivers" line="263" file="USBSlaveFT232Emu.c" 
  basetype="VOID" baseattr="">
  <block line="264" file="USBSlaveFT232Emu.c">
  </block>
 </function>
 <function name="attach_drivers" line="273" file="USBSlaveFT232Emu.c" 
  basetype="VOID" baseattr="">
  <block line="274" file="USBSlaveFT232Emu.c">
  </block>
 </function>
 <function name="close_drivers" line="280" file="USBSlaveFT232Emu.c" 
  basetype="VOID" baseattr="">
  <block line="281" file="USBSlaveFT232Emu.c">
  </block>
 </function>
 <function name="uartTx" line="293" file="USBSlaveFT232Emu.c" 
  basetype="VOID" baseattr="">
  <block line="294" file="USBSlaveFT232Emu.c">
    <var name="iocb" line="295" file="USBSlaveFT232Emu.c"
     type="AUTO" storage="AUTO VAR" attr=""
     basename="_common_ioctl_cb_t" basetype="STRUCT" baseattr=""/>
    <var name="b" line="296" file="USBSlaveFT232Emu.c"
     type="AUTO" storage="AUTO VAR" attr=""
     basetype="CHAR" baseattr="unsigned,"/>
    <var name="bytesTransferred" line="298" file="USBSlaveFT232Emu.c"
     type="AUTO" storage="AUTO VAR" attr=""
     basetype="SHORT" baseattr="unsigned,"/>
    <var name="led" line="297" file="USBSlaveFT232Emu.c"
     type="AUTO" storage="AUTO VAR" attr=""
     basetype="CHAR" baseattr="unsigned,"/>
   <block line="317" file="USBSlaveFT232Emu.c">
    <block line="322" file="USBSlaveFT232Emu.c">
    </block>
   </block>
  </block>
 </function>
 <function name="uartRx" line="342" file="USBSlaveFT232Emu.c" 
  basetype="VOID" baseattr="">
  <block line="343" file="USBSlaveFT232Emu.c">
    <var name="iocb" line="344" file="USBSlaveFT232Emu.c"
     type="AUTO" storage="AUTO VAR" attr=""
     basename="_common_ioctl_cb_t" basetype="STRUCT" baseattr=""/>
    <var name="b" line="345" file="USBSlaveFT232Emu.c"
     type="AUTO" storage="AUTO VAR" attr=""
     basetype="CHAR" baseattr="unsigned,"/>
    <var name="bytesTransferred" line="346" file="USBSlaveFT232Emu.c"
     type="AUTO" storage="AUTO VAR" attr=""
     basetype="SHORT" baseattr="unsigned,"/>
    <var name="led" line="347" file="USBSlaveFT232Emu.c"
     type="AUTO" storage="AUTO VAR" attr=""
     basetype="CHAR" baseattr="unsigned,"/>
   <block line="353" file="USBSlaveFT232Emu.c">
    <block line="358" file="USBSlaveFT232Emu.c">
    </block>
   </block>
  </block>
 </function>
 </file>
</VinTag>
