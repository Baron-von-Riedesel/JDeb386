
;--- German kbd layout

normalk label byte
	db 0,1Bh				;00-01 NULL, escape
	db "1234567890�'"		;02-0D
	db 8,9					;0E-0F backspace + tab
	db 'qwertzuiop�+'		;10-1B
	db 0Dh,0				;1C-1D return, ctrl-l 
	db "asdfghjkl��^"		;1E-29
	db 0					;2A    shift-l
	db '#'					;2B
	db "yxcvbnm,.-"			;2C-35
	db "<"        			;36 ( key 56h )

;--- SHIFT key modifier

shiftk label byte
	db 0,1Bh				;00-01
	db '!"$%&/()=?`'		;02-0D
	db 8,0Fh				;0E-0F backspace + tab
	db 'QWERTZUIOP�*'		;10-1B
	db 0Dh,0				;1C-1D return, ctrl-l 
	db "ASDFGHJKL���"		;1E-29
	db 0					;2A    shift-l
	db "'"					;2B
	db 'YXCVBNM;:_'			;2C-35
	db ">"        			;36 ( key 56h )

;--- R-ALT key modifier

altgrk label byte
	org altgrk + 03h
	db '��'
	org altgrk + 08h
	db '{[]}\'				;08-0C
	org altgrk + 10h
	db '@'					;10
	org altgrk + 1Bh
	db '~'					;1B
	org altgrk + 32h
	db '�'
	org altgrk + 36h
	db '|'					;36 ( key 56h )
        
;--- CTRL key modifier

ctrlk label byte
	db 0,1Bh											;00-01
	db 0Ch dup (0)										;02-0D
	db 7Fh,0											;0E-0F
	db 11h,17h,05h,12h,14h,1Ah,15h,09h,0Fh,10h,1Bh,1Dh	;10-1B
	db 0Ah,00											;1C-1D
	db 01h,13h,04h,06h,07h,08h,0Ah,0Bh,0Ch				;1E-26
	db 0,0,0,0,0										;27-2B
	db 19h,18h,03h,16h,02h,0Eh,0Dh						;2C-32
	db 0,0,0,0											;33-36
