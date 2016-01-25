all:
	../build.sh project
	ddtcmd -oft -fullvme -if project_sram.xcf -nocompress -noheader -of project/project_project_sram.vme
	# flash vme file needs jedec *.jed file as input which is not automatically
	# generated from commandline.
	# GUI runs it with this
	# bitgen -f "project_project.t2b" -w "project_project.ncd" -jedec "project_project.prf"
	# after jedec file is generated, we can generate vme file for flash programming:
	# ddtcmd -oft -fullvme -if project_flash.xcf -nocompress -noheader -of project/project_project_flash.vme
	
clean:
	rm -rf project .recovery *~

program:
	FleaFPGA-JTAG project/project_project_sram.vme
	# after this, to gain access to serial port on linux
	# rmmod ftdi_sio; modprobe ftdi_sio

flash:
	FleaFPGA-JTAG project/project_project_flash.vme
	# after this, to gain access to serial port on linux
	# rmmod ftdi_sio; modprobe ftdi_sio
