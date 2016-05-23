BASE	= m68k-elf
CC      = $(BASE)-gcc
LD      = $(BASE)-gcc
AS      = $(BASE)-as
CP      = $(BASE)-objcopy
DUMP    = $(BASE)-objdump
VASM	= vasmm68k_mot

ROMGENDIR = ../romgen
ROMGEN = $(ROMGENDIR)/romgen

MAIN_PRJ = CharROM
MAIN_SRC = CharROM.s
MAIN_OBJ = $(patsubst %.s,%.bin,$(MAIN_SRC))


all: $(MAIN_PRJ).bin $(MAIN_PRJ)_ROM.vhd

clean:
	rm -f *.bin


# Convert ELF binary to bin file.
%.bin: %.s
	$(VASM) -Fbin -o $@ $<

$(ROMGEN): $(ROMGENDIR)/romgen.c
	gcc -o $(ROMGENDIR)/romgen $(ROMGENDIR)/romgen.c

%_ROM.vhd: %.bin $(ROMGEN)
	sed 's/soc_firmware/$*_ROM/' >$*_ROM.vhd <$(ROMGENDIR)/byterom_prologue.vhd
	$(ROMGEN) $*.bin >>$*_ROM.vhd
	cat >>$*_ROM.vhd $(ROMGENDIR)/byterom_epilogue.vhd

