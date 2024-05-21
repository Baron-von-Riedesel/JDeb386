
# NMAKE makefile to create PLANG.EXE
# uses JWasm
# PLang.exe uses the Open Watcom CRT - hence one needs to download OW 2.0 to recreate it.
# Also, it uses a startup file (cstrtdhx.obj) specific for HX - so one also needs HXDEV.
# to run, HDPMI32 is required.

!ifndef DEBUG
DEBUG=0
!endif

!if $(DEBUG)
OUTDIR=Build
!else
OUTDIR=Build
!endif

OWDIR=\ow20

PGM=plang

LIBS=\hx\lib\libc32s.lib,\hx\lib\dkrnl32
INC32DIR=\hx\include
MODS=

ALL: $(OUTDIR) $(OUTDIR)\$(PGM).EXE

$(OUTDIR):
	@mkdir $(OUTDIR)

$(OUTDIR)\$(PGM).EXE: $*.obj $(PGM)OW.mak
	@jwlink format win pe hx @<<
file { $(MODS) $*.obj} name $*.EXE
libpath $(OWDIR)\lib386\dos;$(OWDIR)\lib386
libfile tools\cstrtdhx.obj
lib clib3s.lib
op q,map=$*.MAP, stub=loadpero.bin, stack=0x8000, heap=0x1000
<<

$(OUTDIR)\$(PGM).obj: src/$(PGM).asm $(PGM)OW.mak
	jwasm -c -zcw -nologo -Sg -Fl$* -Fo$* -I$(INC32DIR) src/$(PGM).asm

clean:
	@del $(OUTDIR)\*.exe
#	@del $(OUTDIR)\*.obj
	@del $(OUTDIR)\*.lst
#	@del $(OUTDIR)\*.map
