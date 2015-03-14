all:
	./build.sh project

clean:
	rm -rf project .recovery f32c_ulx2s1.sty *~

program:
	ujprog project/project_project.jed -t

flash:
	ujprog -j flash project/project_project.jed -t
