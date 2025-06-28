
PROG = basic

LIBS = -lm -lulx3s

# Original pbasic files from the 1980's
CFILES = bas1.c bas2.c bas3.c bas4.c bas5.c \
	 bas6.c bas8.c bas9.c assist.c

# Local extras
CFILES += bas_fb.c bas_file.c bas_f32c.c bas_edit.c f32c_glue.c 

include ${POST_MK}

CFLAGS += -Df32c

# gcc-15 needs this
CFLAGS += -std=gnu17

ifneq ($(findstring ${WARNS}, "34"),)
CFLAGS += -Wno-unused-parameter
CFLAGS += -Wno-sign-compare
endif
