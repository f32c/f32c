
PROG = dhry

WARNS = 1

# gcc-14 needs this
CFLAGS += -Wno-error=implicit-function-declaration
CFLAGS += -Wno-error=implicit-int

# Override -Os, and turn on extra optimization efforts
# 1.55 DMIPS/MHz with gcc-13.2
CFLAGS += -Ofast -fselective-scheduling -funroll-all-loops

# Inlining functions is not permitted per Dhrystone rules!
CFLAGS += -fno-inline-functions -fno-inline-small-functions
CFLAGS += -finline-limit=0

# use clock(3) for time measurement
CFLAGS += -DMSC_CLOCK

CFILES = dhry_1.c dhry_2.c

include ${POST_MK}
