
;--- keyboard layout data
;--- define additional layouts in line below

layouts textequ <US,GR,FR>

@defklay macro code
oldorg = $
%	db "&code"
normalk textequ <normalk_&code>
shiftk  textequ <shiftk_&code>
altgrk  textequ <altgrk_&code>
ctrlk   textequ <ctrlk_&code>
%	include kbd_&code.inc
	.errnz ($ - offset normalk) - 4*37h
	org oldorg + 100h
endm

_DATA segment word public 'DATA'

%	for layout, <layouts>
	@defklay layout
	endm

_DATA ends

	END
