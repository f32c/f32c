all:
	../build.sh project
	ddtcmd -oft -fullvme -if project_sram.xcf -nocompress -noheader -of project/project_project_sram.vme
	
clean:
	rm -rf project .recovery *~

program:
	ujprog project/project_project.jed

flash:
	ujprog -j flash project/project_project.jed
