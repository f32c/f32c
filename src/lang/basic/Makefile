
PROG = basic

# Original pbasic files
CFILES = bas1.c bas2.c bas3.c bas4.c bas5.c \
	 bas6.c bas8.c bas9.c assist.c

# Local extras
CFILES += bas_fb.c bas_file.c bas_f32c.c bas_edit.c \
	f32c_glue.c ${BASE_DIR}lib/atoi.c ${BASE_DIR}lib/random.c

F32C_LIBS = setjmp math sprintf printf sio_baud sprite lcd isr

include ${POST_MK}

CFLAGS += -Df32c

CFLAGS += -Wno-missing-braces
ifneq ($(findstring ${WARNS}, "34"),)
CFLAGS += -Wno-unused-parameter
CFLAGS += -Wno-sign-compare
endif
