
# Default load offset - bootloader is at 0x00000000
LOADADDR = 0x00000180

# -EB big-endian (default); -EL little-endian
ENDIANFLAGS = -EL

# Includes
CFLAGS = -nostdinc -I../include

# MIPS-specific flags
CFLAGS += -march=mips3 ${ENDIANFLAGS}
CFLAGS += -mtune=mips32 -mno-branch-likely
CFLAGS += -mno-mips16 -mno-dsp -mno-mips3d -mno-mdmx -msoft-float
CFLAGS += -G 32768

# f32c-specific flags
CFLAGS += -msoft-mul -msoft-div

# Language flags
CFLAGS += -std=c99 -Wall -Werror
CFLAGS += -Wextra -Wsystem-headers -Wshadow -Wpadded -Winline
CFLAGS += -c
#CFLAGS += -s -n -nostdlib -fno-builtin
CFLAGS += -ffreestanding

# Debugging options
CFLAGS += -g

# Optimization options
CFLAGS += -Os
CFLAGS += -finline-limit=16 -fmerge-all-constants
CFLAGS += -falign-functions=4 -falign-labels=4
CFLAGS += -falign-jumps=4 -falign-loops=4
CFLAGS += -fweb -frename-registers
CFLAGS += -freorder-blocks
#CFLAGS += -funsafe-loop-optimizations -Wunsafe-loop-optimizations
#CFLAGS += --param max-delay-slot-insn-search=16
#CFLAGS += --param max-delay-slot-live-search=16

# No zero-filled BSS
#CFLAGS += -fno-zero-initialized-in-bss

# Other interesting options:
# CFLAGS += -fPIC -fpic
# -membedded-data
# -no-shared

LDFLAGS += -Ttext ${LOADADDR} -N ${ENDIANFLAGS}

AS = mips-rtems-gcc ${CFLAGS} ${ASFLAGS}
CC = mips-rtems-gcc ${CFLAGS}
LD = mips-rtems-ld ${LDFLAGS}

