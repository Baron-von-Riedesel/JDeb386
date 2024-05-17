
;--- load the 16-bit DebugR blob resource
;--- and call its initialization routine.
;--- JWasm used ( Masm won't work )

	.386
	.MODEL FLAT, stdcall
	option casemap:none
	option proc:private

ifndef AUXIO
AUXIO equ 1
endif
ifndef VIOOUT
VIOOUT equ 0
endif
ifndef KBDIN
KBDIN equ 0
endif

MEMADD    equ 500h
DEVICE_ID equ 0
INT41     equ 1

VERSION textequ <"v1.2">

CStr macro text:vararg
local sym
	.const
sym db text,0
	.code
	exitm <offset sym>
endm

	include jlm.inc

	.data

;--- the DDB must be make public. The link step will "export" this
;--- symbol. This is the simplest method to make JLoad know the
;--- device id.

	public ddb
ddb VxD_Desc_Block < 0, 0, DEVICE_ID, 1, 0, 0, "JDeb386", 0, 0, 0 >

hModuleStat dd 0	;???
dwFlat dd 0
dwDS16 dd 0
dfDebugger label fword
	dd 0	; the offset of debugger init is 00000000
dwCS16 dd 0
dfGetR0Stk label fword
	dd 3	; the offset is 00000003
	dd 0
dwEAX dd 0
dwEDX dd 0
dwScratch dd 0
if INT41
dwOldInt41 dd 0
endif
dwOldEsp dd 0
dwOldSs  dd 0
ifdef _DEBUG
dwReenterI10 dd 0
dwReenterI16 dd 0
endif

_DATA16 segment para FLAT public 'DATA'

start16 label byte
if V86
	incbin <Build\DebugRV.bin>
else
	incbin <Build\DebugR.bin>
endif
SIZEBIN16 equ $ - offset start16
	db MEMADD dup (?)

_DATA16 ends

	.CODE

	include printf.inc
ifdef _DEBUG
	include dprintf.inc
else
@dprintf equ <;>
endif

if AUXIO
	include auxio.inc
endif

if VIOOUT
	include vioout.inc
elseifdef _DEBUG
	include vioout.inc
endif
if KBDIN
	include kbdinp.inc
elseifdef _DEBUG
	include kbdinp.inc
endif

MEMADD equ 500h

PUSHADS struct
_edi dd ?
_esi dd ?
_ebp dd ?
     dd ?
_ebx dd ?
_edx dd ?
_ecx dd ?
_eax dd ?
PUSHADS ends

;--- debugger callback
;--- write char to output device

callint10 proc far
	push ds
	push es
	mov ds, cs:[dwFlat]
	mov es, [dwFlat]

if AUXIO
	cmp [wComNo], -1
	jz not_aux
	cmp ah, 3
	jz @F
	call AuxPutChar
	jmp exit
@@:
	call AuxGetCsrPos
	jmp exit
not_aux:
endif

if VIOOUT
	cmp ah, 3
	jz @F
	call VioPutChar
	jmp done
@@:
	call VioGetCsrPos
done:

else

 ifdef _DEBUG
	cmp [dwReenterI10], 1
	jb is_ok
	cmp ah, 3
	jz @F
	call VioPutChar
	jmp exit
@@:
	call VioGetCsrPos
	jmp exit
is_ok:
	inc [dwReenterI10]
 endif
;--- switch to Jemm's stack

	mov [dwOldEsp], esp
	mov [dwOldSs], ss
	mov [dwEAX], eax
	mov [dwEDX], edx
	call [dfGetR0Stk]
	mov ss, edx
	lea esp, [eax-40h]	; due to bug in Jemm!
	mov eax, [dwEAX]
	mov edx, [dwEDX]
	push [dwOldSs]
	push [dwOldEsp]
	pushad
	@VMMCall Get_Cur_VM_Handle
	mov ebp, [ebx].cb_s.CB_Client_Pointer
	mov ebx, [esp].PUSHADS._ebx

	push [ebp].Client_Reg_Struc.Client_EAX
	push [ebp].Client_Reg_Struc.Client_EBX
	push [ebp].Client_Reg_Struc.Client_ECX
	push [ebp].Client_Reg_Struc.Client_EDX
	mov word ptr [ebp].Client_Reg_Struc.Client_EAX, ax
	mov word ptr [ebp].Client_Reg_Struc.Client_EBX, bx

	@VMMCall Begin_Nest_Exec
	mov eax, 10h
	@VMMCall Exec_Int
	@VMMCall End_Nest_Exec

;--- return cursor pos for int 10h, ah=3
	cmp byte ptr [ebp].Client_Reg_Struc.Client_EAX+1, 3
	jnz @F
	mov ax, word ptr [ebp].Client_Reg_Struc.Client_EDX
	mov word ptr [esp+4*4].PUSHADS._edx, ax
@@:
	pop [ebp].Client_Reg_Struc.Client_EDX
	pop [ebp].Client_Reg_Struc.Client_ECX
	pop [ebp].Client_Reg_Struc.Client_EBX
	pop [ebp].Client_Reg_Struc.Client_EAX
 if 0;def _DEBUG
	mov ebp, esp
	@dprintf "callint10: old ss:esp=%X:%X %X:%X", [ebp+sizeof PUSHADS+4], [ebp+sizeof PUSHADS+0], [dwOldSs], [dwOldEsp]
 endif
	popad
	lss esp, [esp]	;and switch back to Debug's stack
 ifdef _DEBUG
	dec [dwReenterI10]
 endif
endif
exit:
	pop es
	pop ds
	ret

callint10 endp

;--- debugger callback
;--- get a char from input device

callint16 proc far

	push ds
	push es
	mov ds, cs:[dwFlat]
	mov es, [dwFlat]
if AUXIO
	cmp [wComNo], -1
	jz not_aux
	call AuxGetChar
	jmp exit
not_aux:
endif

if KBDIN
	call KbdGetChar
else

 ifdef _DEBUG
	cmp [dwReenterI16], 1
	jb is_ok
	call KbdGetChar
	jmp exit
is_ok:
	inc [dwReenterI16]
 endif

	mov [dwOldEsp], esp
	mov [dwOldSs], ss
	mov [dwEAX], eax
	mov [dwEDX], edx
	call [dfGetR0Stk]
	mov ss, edx
	lea esp, [eax-40h]	; due to bug in Jemm!
	mov eax, [dwEAX]
	mov edx, [dwEDX]
	push [dwOldSs]
	push [dwOldEsp]
	pushad
	@VMMCall Get_Cur_VM_Handle
	mov ebp, [ebx].cb_s.CB_Client_Pointer

	push [ebp].Client_Reg_Struc.Client_EAX
	mov word ptr [ebp].Client_Reg_Struc.Client_EAX, ax

	@VMMCall Begin_Nest_Exec
	mov eax, 16h
	@VMMCall Exec_Int
	@VMMCall End_Nest_Exec

	mov ax, word ptr [ebp].Client_Reg_Struc.Client_EAX
	pop [ebp].Client_Reg_Struc.Client_EAX
	mov word ptr [esp].PUSHADS._eax, ax
 if 0;def _DEBUG
	mov ebp, esp
	@dprintf "callint16: old ss:esp=%X:%X", [ebp+sizeof PUSHADS+4], [ebp+sizeof PUSHADS+0]
 endif
	popad
	lss esp, [esp]	;and switch back to Debug's stack
 ifdef _DEBUG
	dec [dwReenterI16]
 endif
endif
exit:
	pop es
	pop ds
	ret
callint16 endp

if INT41

myint41 proc
	cmp ax, 4Fh
	jz @F
	iretd
@@:
	mov ax, 0F386h
	iretd
myint41 endp

endif

;--- option stackbase:esp is used so register EBP
;--- ( holding the "client_reg_struct" pointer ) isn't modified.
;--- however, this option is rather problematic for 32-bit code,
;--- since any push will change the offset of stack variables
;--- ( there's NO automatic adjustment ).

	option stackbase:esp

;--- install. esi=JLCOMM

install proc c

	mov [dwFlat], ds
	mov esi, [esi].JLCOMM.lpCmdLine
	@dprintf "install: cmdl=%s", esi

;--- scan the cmdline

nextchar:
	lodsb
	and al, al
	jz done_cmdl
	cmp al, '/'
	jz is_opt
	cmp al, '-'
	jnz nextchar
is_opt:
	lodsb
	and al, al
	jz disp_help
	or al,20h
	cmp al,'c'
	jz is_copt
	jmp disp_help
is_copt:
	lodsb
	and al, al
	jz disp_help
	cmp al,'1'
	jb disp_help
	cmp al,'4'
	ja disp_help
	sub al,'1'
	movzx ebx, al
	cmp word ptr ds:[ebx*2+400h], 0
	jz comport_invalid
	mov wComNo, bx
	jmp nextchar
disp_help:
	.data
helptxt label byte
	db "JDeb386 ",VERSION,13,10
	db "To load JDeb386: JDeb386 [options]",13,10
	db "  options are:",13,10
	db "   -cN: COM port to use; N may be 1|2|3|4.",13,10
	db "    if no COM port is set, low-level video/kbd access will be used.",13,10
	db "To unload JDeb386: jload -u jdeb386.exe",13,10
	db 0
	.code
	invoke printf, CStr("%s"), offset helptxt
	mov eax, 80000000h	; no msg "failed to load"
	ret
comport_invalid:
	inc ebx
	invoke printf, CStr("COM%u doesn't exist",13,10), ebx
	jmp failed
done_cmdl:

if INT41
;--- check if a kernel debugger is visible.
	mov ax, 004Fh
	int 41h
	cmp ax, 0F386h	; kernel debugger already installed?
	jz kdinstalled
endif

;--- get GDT descriptor for 16-bit code

	mov ebx, offset start16
	mov edx, cs
	lar ecx, edx
	and ecx, 0000ff00h
	shrd eax, ebx, 16	; get lower 16 bits of base
	mov ax, SIZEBIN16 + MEMADD
	and al, 0F0h
	dec ax
	shld edx, ebx, 16	; get upper 16 bits of base
	mov cl, dl
	shr edx, 8
	shl ecx, 8
	shrd ecx, edx, 8

	push ecx
	push eax

	push ecx     ; hi32 descriptor
	push eax     ; lo32 descriptor
	push 0       ; flags
	@VMMCall _Allocate_GDT_Selector
	add esp, 3*4

	pop edx
	pop ecx
	and eax, eax
	jz errorcs
	mov dwCS16, eax
	mov dword ptr dfGetR0Stk+4, eax

;--- get GDT descriptor for 16-bit data

	xor ch, 8

	push ecx     ; hi32 descriptor
	push edx     ; lo32 descriptor
	push 0       ; flags
	@VMMCall _Allocate_GDT_Selector
	add esp, 3*4

	and eax, eax
	jz errords
	mov [dwDS16], eax

;--- get GDT descriptor as scratchselector for debugger

	mov cx, 9300h	; ensure attributes aren't 0
	push ecx
	push 0
	push 0
	@VMMCall _Allocate_GDT_Selector
	add esp, 3*4
	and eax, eax
	jz errorsc
	mov [dwScratch], eax

	invoke printf, CStr("GDT selectors for code/data/scratch: %X/%X/%X",13,10), dwCS16, dwDS16, dwScratch

	mov eax, [dwScratch]
	shl eax, 16
	mov ax, word ptr [dwDS16]
	push ebp
	lsl bp, ax
	inc bp
	mov ebx, offset callint10	; int 10h vector
	mov edx, offset callint16	; int 16h vector
	mov ecx, ds

	sub esp, 6
	sidt [esp]
	pop di
	pop edi

;--- registers setup:
;--- ax=debugger's data segment, hiword ax: scratchsel
;--- cx=flat data selector
;--- bp=max. size debugger segment
;--- ebx=linear address vio out
;--- edx=linear address kbd in
;--- esi=linear address cmdline
;--- es:edi=address IDT

	call [dfDebugger]
	pop ebp

if INT41

;--- hook INT 41h. to make kernel debugger visible.

	sub esp,8
	sidt [esp]
	mov ebx, [esp+2]
	add esp,8
	add ebx, 41h*8
	mov dx, [ebx+6]
	shl edx, 16
	mov dx, [ebx+0]
	mov [dwOldInt41], edx
	mov eax, offset myint41
	mov [ebx+0], ax
	shr eax, 16
	mov [ebx+6], ax
endif

	invoke printf, CStr("JDeb386 loaded and initialized",13,10)
	mov eax, 80000001h	; bit 31=1: suppress JLoad msg
	ret
kdinstalled:
	invoke printf, CStr("ring 0 debugger already installed",13,10)
	jmp failed
errorcs:
	invoke printf, CStr("Allocate_GDT_selector() [code] failed",13,10)
	jmp failed
errords:
	invoke printf, CStr("Allocate_GDT_selector() [data] failed",13,10)
	jmp failed
errorsc:
	invoke printf, CStr("Allocate_GDT_selector() [scratch] failed",13,10)
failed:
	mov eax, 80000000h
	ret
install endp

uninstall proc

if INT41
	mov eax, [dwOldInt41]
	sub esp,8
	sidt [esp]
	mov ebx, [esp+2]
	add esp,8
	add ebx, 41h*8
	mov [ebx+0], ax
	shr eax, 16
	mov [ebx+6], ax
endif

	mov byte ptr [dfDebugger], 6
	pushad
	call [dfDebugger]
	popad

	push [dwCS16]
	@VMMCall _Free_GDT_Selector
	push [dwDS16]
	@VMMCall _Free_GDT_Selector
	push [dwScratch]
	@VMMCall _Free_GDT_Selector
	add esp, 4*3
	mov eax, 1
	ret
notfound:
	invoke printf, CStr("No installed instance of %s found",13,10), offset ddb.DDB_Name
	mov eax, 80000000h
	ret
uninstall endp

DLL_PROCESS_DETACH equ 0
DLL_PROCESS_ATTACH equ 1

DllMain proc stdcall uses esi edi hModule:dword, dwReason:dword, dwRes:dword

	mov eax, dwReason
	cmp eax, DLL_PROCESS_ATTACH
	jnz @F
	mov eax, hModule
	mov hModuleStat, eax

	mov esi, dwRes
ifdef _DEBUG
	invoke printf, CStr("Cmdline: %s",13,10), [esi].JLCOMM.lpCmdLine
endif
	call install
	jmp done
@@:
	cmp eax, DLL_PROCESS_DETACH
	jnz @F
	call uninstall
	jmp done
@@:
	xor eax, eax
done:
	ret

DllMain endp

	END DllMain
