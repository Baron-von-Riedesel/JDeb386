
# NMAKE makefile to create PLANG.EXE
# uses JWasm
# PLang.exe uses the HW Win32 emulation - hence one needs the HXDEV package to create the binary

!ifndef DEBUG
DEBUG=0
!endif

!if $(DEBUG)
OUTDIR=Build
!else
OUTDIR=Build
!endif

PGM=plang

LIBS=\hx\lib\libc32s.lib,\hx\lib\dkrnl32
INC32DIR=\hx\include
MODS=

ALL: $(OUTDIR) $(OUTDIR)\$(PGM).EXE

$(OUTDIR):
	@mkdir $(OUTDIR)

$(OUTDIR)\$(PGM).EXE: $*.obj $(PGM).mak
	@jwlink format win pe file { $(MODS) $*.obj} name $*.EXE lib $(LIBS) op q,map=$*.MAP,stub=dpmist32.bin,start=_mainCRTStartup, stack=0x8000, heap=0x2000

$(OUTDIR)\$(PGM).obj: src/$(PGM).asm $(PGM).mak
	jwasm -c -coff -nologo -Sg -Fl$* -Fo$* -I$(INC32DIR) src/$(PGM).asm

clean:
	@del $(OUTDIR)\*.exe
#	@del $(OUTDIR)\*.obj
	@del $(OUTDIR)\*.lst
#	@del $(OUTDIR)\*.map
