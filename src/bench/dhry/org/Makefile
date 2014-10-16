
CFLAGS += -DTIME
CFLAGS += -O3 -finline-limit=0

dhry:	Makefile dhry_1.o dhry_2.o
	gcc ${CFLAGS} dhry_1.o dhry_2.o -o dhry

dhry_1.o: Makefile dhry_1.c dhry_2.c dhry.h
	gcc -c ${CFLAGS} dhry_1.c

dhry_2.o: Makefile dhry_1.c dhry_2.c dhry.h
	gcc -c ${CFLAGS} dhry_2.c

clean:
	rm *.o dhry
