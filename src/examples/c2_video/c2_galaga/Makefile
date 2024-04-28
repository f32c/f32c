
PROG = c2_galaga

LIBS = -lm

CXXFILES = Compositing/Compositing.cpp c2_galaga.cpp

CFLAGS += -D__F32C__

# default is 8bpp if unspecified
#CFLAGS += -DSOC_VIDEO_BPP=8

# for 16bpp color video bitstream use this
CFLAGS += -DSOC_VIDEO_BPP=16

include ${POST_MK}
