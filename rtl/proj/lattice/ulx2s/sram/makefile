all:
	ln -s ulx2s_sram.ldf project.ldf
	../../build.sh project

clean:
	rm -rf project.ldf project .recovery *~

program:
	ujprog project/project_project.jed

flash:
	ujprog -j flash project/project_project.jed
