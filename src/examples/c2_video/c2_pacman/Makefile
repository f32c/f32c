
PROG = pacman

CXXFILES = Compositing/Compositing.cpp c2_pacman.cpp
CFILES = pacmaze.c

CFLAGS += -D__F32C__

# default is 8bpp if unspecified
#CFLAGS += -DSOC_VIDEO_BPP=8

# for 16bpp color video bitstream use this
CFLAGS += -DSOC_VIDEO_BPP=16

WITHOUT_FLOAT = true

include ${POST_MK}
