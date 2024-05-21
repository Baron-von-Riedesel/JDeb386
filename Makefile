
# create JDeb386.exe
# tools used: 
# - jwasm
# - jwlink
# - nmake compatible make
# - DebugR/DebugRV variants from Debug/X project ( see DEBUGRDIR below ).
# - Jemm include files from Jemm project ( see JEMMDIR below ).

# video and keyboard i/O may be selected by:
# run "nmake vio=1"        for a variant that uses low-level vio output.
# run "nmake kbd=1"        for a variant that uses low-level kbd access.

# kbd=1 needs a language ( US and GR are supplied ):
# run "nmake kbd=1 klang=gr" ; for low-level kbd access, German translation.

# to select DebugR (non v86-mode variant) instead of DebugRV:
# run "nmake v86=0"

# jwasm's option -pe cannot be used, since the DDB cannot be exported then;
# so jwlink is necessary ( it may create slightly larger binaries ).

!ifndef DEBUG
DEBUG=0
!endif

!ifndef V86
V86=1
!endif

!if $(V86)
DEBUGR=DebugRV.bin
!else
DEBUGR=DebugR.bin
!endif

NAME=JDeb386

DEBUGRDIR=..\debug\build
JEMMDIR=..\jemm

!ifndef AUX
AUX=1
!endif
!ifndef VIO
VIO=1
!endif
!ifndef KBD
KBD=1
!endif
!ifndef KLANG
KLANG=US
!endif

!if $(AUX)
AOPT=-DAUXIO=1
srcdep=$(srcdep) src/auxio.inc
!else
AOPT=-DAUXIO=0
!endif

!if $(VIO)
AOPT=-DVIOOUT=1
srcdep=$(srcdep) src/vioout.inc
!endif
!if $(KBD)
AOPT=$(AOPT) -DKBDIN=1 -DKEYS=KBD_$(KLANG)
srcdep=$(srcdep) src/kbdinp.inc
!endif

!if $(DEBUG)
AOPTD=-D_DEBUG
srcdep=$(srcdep) src/dprintf.inc
!else
AOPTD=
!endif

OUTD=Build


ALL: $(OUTD) $(OUTD)\$(NAME).exe $(OUTD)\SReqHlp.exe $(OUTD)\KbdLay.bin

$(OUTD):
	@if not exist $(OUTD)\NUL @mkdir $(OUTD)

$(OUTD)\$(NAME).exe: $(OUTD)\$(NAME).obj $(OUTD)\jlstub.bin
	@jwlink.exe format win pe hx dll ru native @<<
f Build\$(NAME).OBJ n Build\$(NAME).EXE
op q,m=Build\$(NAME).MAP,stub=Build\jlstub.bin export _ddb.1 
<<

$(OUTD)\$(NAME).obj: src/$(NAME).asm $(OUTD)\$(DEBUGR) $(srcdep)
	@jwasm.exe -coff -nologo -DV86=$(V86) $(AOPT) $(AOPTD) -Fl$(OUTD)\ -Fo$(OUTD)\ -Sg -I$(JEMMDIR)\Include src/$(NAME).asm 

$(OUTD)\jlstub.bin: $(JEMMDIR)\JLM\JLSTUB\Build\JLSTUB.BIN
	@copy $(JEMMDIR)\JLM\JLSTUB\Build\JLSTUB.BIN $(OUTD)\

$(OUTD)\$(DEBUGR): $(DEBUGRDIR)\$(DEBUGR)
	@copy $(DEBUGRDIR)\$(DEBUGR) $(OUTD)\

$(OUTD)\SReqHlp.exe: src/SReqHlp.asm
	@jwasm -nologo -mz -Fo$* src/SReqHlp.asm

$(OUTD)\KbdLay.bin: src/KbdLay.asm
	@jwasm -nologo -bin -Fo$* src/KbdLay.asm

clean:
	@del $(OUTD)\*.exe
	@del $(OUTD)\*.bin
	@del $(OUTD)\*.lst
	@del $(OUTD)\*.map
	@del $(OUTD)\*.obj
