
.include "../conf/f32c.mk"

CFILES = demo.c \
	../lib/sio.c ../lib/spi.c ../lib/div.c ../lib/mul.c \
	../lib/printf.c ../lib/pcmplay.c

ASFILES = ../lib/start.S

OBJS += ${ASFILES:T:.S=.o}
OBJS += ${CFILES:T:.c=.o}

img.elf: ${OBJS}
	$(LD) -o img.elf ${OBJS}

.for _src in ${CFILES}
${_src:T:.c=.o}: ${_src}
	$(CC) ${.IMPSRC}
.endfor

.for _src in ${ASFILES}
${_src:T:.S=.o}: ${_src}
	$(AS) ${.IMPSRC}
.endfor

clean:
	rm -f $(OBJS) img.elf
