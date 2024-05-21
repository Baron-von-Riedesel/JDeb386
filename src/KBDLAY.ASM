
;--- keyboard layout data

_DATA segment word public 'DATA'

	org 0
	db "US"
normalk textequ <normalk_us>
shiftk  textequ <shiftk_us>
altgrk  textequ <altgrk_us>
ctrlk   textequ <ctrlk_us>
	include kbd_us.inc

	org 100h
	db "GR"
normalk textequ <normalk_gr>
shiftk  textequ <shiftk_gr>
altgrk  textequ <altgrk_gr>
ctrlk   textequ <ctrlk_gr>
	include kbd_gr.inc

	org 200h

_DATA ends

	END
