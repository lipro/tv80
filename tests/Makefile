# Makefile for Z80 C/Assembly files
# Assumes that SDCC is installed parallel to TV80 root

SDCC_ROOT=../../sdcc
CC=$(SDCC_ROOT)/bin/sdcc -mz80
AS=$(SDCC_ROOT)/bin/as-z80
LD=$(SDCC_ROOT)/bin/link-z80
IHEX2MEM=../scripts/ihex2mem.py
LINK_OPTIONS=-- -m -j -x -b_CODE=0x0200 -b_DATA=0x8000 -k$(SDCC_ROOT)/share/sdcc/lib/z80 -k$(SDCC_ROOT)/lib/z80 -lz80
AS_LINK_OPTIONS=-bBOOT_VEC=0x0000 -bINT_VEC=0x0038
C_LINK_OPTIONS=$(SDCC_ROOT)/share/sdcc/lib/z80/crt0.o

%.vmem : %.ihx
	$(IHEX2MEM) $^ $@

%.ihx : %.c
	$(CC) $^

%.o   : %.asm
	$(AS) -o $*.o $^

%.ihx : %.o
	$(LD) $(LINK_OPTIONS) $(AS_LINK_OPTIONS) -i $* $^ -e

clean :
	rm -f *.map
	rm -f *.mem
	rm -f *.rel
	rm -f *.rst
	rm -f *.sym
	rm -f *.o
	rm -f *.lnk
	rm -f *.ihx
	rm -f *.lst
	rm -f *.vmem

