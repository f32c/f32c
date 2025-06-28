
PROG = dhry

WARNS = 1

# gcc-14 and above need this
CFLAGS += -Wno-error=implicit-function-declaration
CFLAGS += -Wno-error=implicit-int
CFLAGS += -std=gnu17

# use clock(3) for time measurement
CFLAGS += -DMSC_CLOCK

# Override -Os, and turn on extra optimization efforts
# 1.39 DMIPS/MHz 84.375 MHz 16I$/16D$ SDRAM gcc-14.1
CFLAGS += -O3 -funroll-all-loops -fselective-scheduling2

# Inlining functions is not permitted per Dhrystone rules!
CFLAGS += -fno-inline

CFILES = dhry_1.c dhry_2.c

include ${POST_MK}
