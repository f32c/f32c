all:
	../build.sh project

clean:
	rm -rf project .recovery *~

program:
	ujprog project/project_project.jed

flash:
	ujprog -j flash project/project_project.jed
