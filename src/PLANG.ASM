
;--- tool to patch keyboard data into a binary.

	.386
	.model flat, stdcall
	option proc:private

	include \hx\include\winnt.inc

extern syscall __argc:byte	; this is REQUIRED, or OW won't fill _argc, _argv!

?REBASE equ 0

fopen  proto c :ptr, :ptr
fclose proto c :dword
fread  proto c :ptr, :dword, :dword, :dword
fwrite proto c :ptr, :dword, :dword, :dword
fseek  proto c :ptr, :dword, :dword
printf proto c :ptr, :vararg

SEEK_SET equ 0

CStr macro text:VARARG
local sym
	.const
  ifidni <text>,<"">
sym db 0
  else
sym db text,0
  endif
	.code
	exitm <offset sym>
endm

?MAXSEC equ 24
        
	.data

bModified db 0
bPatchPE db 0
bPatchPX db 0
bVerbose db 0
bOptions db 0

	.data?

MZ_hdr	db 40h dup (?)        
PE_hdr	IMAGE_NT_HEADERS <>        
	dd 12 dup (?)
Sections IMAGE_SECTION_HEADER ?MAXSEC dup (<>)
PatchData db 37h*4 dup (?)

	.code

;*** patch a file

patch proc pszFN:ptr, pszLang:ptr

local	pFile:DWORD    	; file to patch
local	dwRead:dword
local	dwPEPos:DWORD

	invoke fopen, pszFN, CStr("rb+")
	.if eax == 0
		invoke printf, CStr("file '%s' not found",10), pszFN
		ret
	.endif
	mov pFile,eax
	invoke fread, addr MZ_hdr, 1, sizeof MZ_hdr, pFile
	.if eax != sizeof MZ_hdr
		invoke printf, CStr('dos read error',10)
		jmp exit
	.endif
	.if (word ptr MZ_Hdr+0 != "ZM")
		invoke printf, CStr('Not a MZ binary: %s',10), pszFN
		jmp exit
	.endif
if 0
	.if (word ptr MZ_Hdr+18h < 40h)		;relocation table offset < 40h?
		invoke printf, CStr('Not a PE/PX binary: %s',10), pszFN
		jmp exit
	.endif
endif
	mov eax, dword ptr MZ_hdr+3ch
	mov dwPEPos, eax
	invoke fseek, pFile, dwPEPos, SEEK_SET
	.if eax == -1
		invoke printf, CStr('cannot position to PE/PX header',10)
		jmp exit
	.endif
	mov dwRead, 4 + sizeof IMAGE_FILE_HEADER
	invoke fread, addr PE_hdr, 1, 4 + sizeof IMAGE_FILE_HEADER, pFile
	.if eax != 4 + sizeof IMAGE_FILE_HEADER
		invoke printf, CStr('cannot read PE/PX header',10)
		jmp exit
	.endif
	.if ( PE_Hdr.FileHeader.Machine != IMAGE_FILE_MACHINE_I386 )
		invoke printf, CStr('cannot handle machine %X',10), PE_Hdr.FileHeader.Machine
		jmp exit
	.endif
	.if ((PE_Hdr.Signature == "EP") || (PE_Hdr.Signature == "XP"))

if 0
		movzx ecx, PE_Hdr.FileHeader.NumberOfSections
		invoke printf, CStr('%u sections in PE binary',10), ecx
endif

		invoke fread, addr PE_Hdr.OptionalHeader, 1, PE_Hdr.FileHeader.SizeofOptionalHeader, pFile
		.if ax != PE_Hdr.FileHeader.SizeofOptionalHeader
			invoke printf, CStr('cannot read PE/PX optional header',10)
			jmp exit
		.endif
		add dwRead, eax
if 0
		invoke printf, CStr('position section table: %X',10), dwRead
endif

;--- read in section table

		movzx eax, PE_Hdr.FileHeader.NumberOfSections

		.if eax > ?MAXSEC
			invoke printf, CStr('cannot handle binaries with more that %u sections',10), ?MAXSEC
			jmp exit
		.endif

		mov ecx, sizeof IMAGE_SECTION_HEADER
		mul ecx
		push eax
		invoke fread, addr Sections, 1, eax, pFile
		pop edx
		.if eax != edx
			invoke printf, CStr('cannot read section table',10)
			jmp exit
		.endif
if 0
		movzx ecx, PE_Hdr.FileHeader.NumberOfSections
		mov edi, offset Sections
@@:
		push ecx
		invoke printf, CStr('pos: %X %s',10), [edi].IMAGE_SECTION_HEADER.PointerToRawData, addr [edi].IMAGE_SECTION_HEADER.Name_
		pop ecx
		add edi, sizeof IMAGE_SECTION_HEADER
		loop @B
endif
		mov eax, [Sections + 1 * sizeof IMAGE_SECTION_HEADER].PointerToRawData
		invoke fseek, pFile, eax, SEEK_SET
		.if eax == -1
			invoke printf, CStr('cannot position to Section 2 data',10)
			jmp exit
		.endif
		invoke printf, CStr('patch position: %X, data size=%X',10), [Sections + 1 * sizeof IMAGE_SECTION_HEADER].PointerToRawData, 37h*4

		invoke fwrite, addr PatchData, 1, sizeof PatchData, pFile
		.if eax != sizeof PatchData
			invoke printf, CStr('cannot write keyboard layout data "%s" to file %s',10), pszLang, pszFN
			jmp exit
		.endif
		invoke printf, CStr('file %s patched with keyboard layout data "%s"',10), pszFN, pszLang

	.else
		invoke printf, CStr('not a PE/PX binary: %s',10), pszFN
	.endif
exit:
	invoke fclose, pFile
	ret
patch endp

ScanPatchFile proc uses esi edi pszPatchFile:ptr, dwLanguage:dword

local pPatchFile:dword	; patch file descriptor
local buffer[256]:byte

;--- read in keyboard data from patchfile

	invoke fopen, pszPatchFIle, CStr("rb")
	.if eax == 0
		invoke printf, CStr("cannot open file '%s'",10), pszPatchFile
		jmp error
	.endif
	mov pPatchFile, eax
nextitem:
	invoke fread, addr buffer, 1, sizeof buffer, pPatchFile
	.if eax != sizeof buffer
		invoke printf, CStr('language data %s not found in %s',10), addr dwLanguage, pszPatchFile
		jmp error2
	.endif
	mov eax, dwLanguage
	or ax, 2020h
	mov cx, word ptr [buffer]
	or cx, 2020h
	cmp ax, cx
	jnz nextitem
	lea esi, [buffer+2]
	mov edi, offset PatchData
	mov ecx, sizeof PatchData
	rep movsb
	invoke fclose, pPatchFile
	clc
	ret
error2:
	invoke fclose, pPatchFile
error:
	stc
	ret
ScanPatchFile endp

;--- main

main proc c public argc:dword, argv:ptr

local dwIndex:dword

	.if argc < 2
		jmp usage
	.endif
	mov ebx, argv
	mov ebx, [ebx+4]
	movzx eax, word ptr [ebx]
	cmp byte ptr [ebx+2], 0
	jnz usage
	invoke ScanPatchFile, CStr("KbdLay.bin"), eax
	jc failure
	invoke patch, CStr("jdeb386.exe"), ebx
	xor eax,eax
	ret
failure:
	mov eax, 1
	ret
usage:
	.const
helptxt label byte
	db "PLang v1.0.",10
	db "usage:",10
	db "  PLang language",10
	db "where language is a 2-char code (US, GR, ...)",10
	db 0
	invoke printf, CStr("%s"), offset helptxt
	mov eax, 1
	ret
main endp

	END
