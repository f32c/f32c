
CFLAGS += -DTIME
CFLAGS += -O3

dhry:	dhry_1.o dhry_2.o
	gcc ${CFLAGS} dhry_1.o dhry_2.o -o dhry

dhry_1.o:
	gcc -c ${CFLAGS} dhry_1.c

dhry_2.o:
	gcc -c ${CFLAGS} dhry_2.c

clean:
	rm *.o dhry
