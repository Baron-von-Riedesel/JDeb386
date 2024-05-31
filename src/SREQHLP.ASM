
;--- in case the BIOS/keyboard driver doesn't fully support SysReq.
;--- to create the binary: jwasm -mz SReqHlp.asm

	.286
	.model tiny
	.stack 1024
	.386

	.code

int15 proc
	pushf
	cmp ax,4F54h
	jz sysreqon
	cmp ax,4FD4h
	jz sysreqoff
prev:
	popf
	db 0eah
oldint15 dd 0
sysreqon:
	push ds
	push 40h
	pop ds
	or byte ptr ds:[18h],4
	pop ds
	jmp prev
sysreqoff:
	push ds
	push 40h
	pop ds
	and byte ptr ds:[18h],not 4
	pop ds
	jmp prev
int15 endp

endres equ $

help db "installed",13,10,'$'

start:
	push cs
	pop ds     ; ds=DGROUP

	push es

;--- free environment
	xor ax, ax
	xchg ax, es:[02Ch]
	mov es, ax
	mov ah, 49h
	int 21h

;--- hook int 15h
	mov ax,3515h
	int 21h
	mov word ptr [oldint15+0], bx
	mov word ptr [oldint15+2], es

	pop es
	mov di, 60h
	mov si, offset int15
	mov cx, offset endres
	rep movsb

	mov ax, es
	mov ds, ax
	mov dx, 60h
	mov ax, 2515h
	int 21h
	push cs
	pop ds

;--- display "installed"
	mov dx,offset help
	mov ah,9
	int 21h

;--- close all files
	xor bx, bx
@@:
	mov ah, 3Eh
	int 21h
	inc bx
	cmp bx, 5
	jb @B

;--- go resident
	mov dx, offset endres
	add dx, 60h+15
	shr dx, 4
	mov ah,31h
	int 21h

	END start
