.device atmega328p
.include "m328pdef.inc"

; ---------- Pins (as constants) ----------
; Left HX711s
.equ PB_DT1L = 0
.equ PB_SCK1L= 1
.equ PB_DT2L = 2
.equ PB_SCK2L= 3
; Right HX711s
.equ PD_DT1R = 2
.equ PD_SCK1R= 7
.equ PB_DT2R = 4
.equ PB_SCK2R= 5
; Motors
.equ PD_DIR_L = 6
.equ PD_PWM_L = 5      ; OC0B
.equ PD_DIR_R = 4
.equ PD_PWM_R = 3      ; OC2B
; Limits (active-low)
.equ PC_TOP_L = 0
.equ PC_BOT_L = 1
.equ PC_TOP_R = 2
.equ PC_BOT_R = 3

; ---------- Tunables ----------
.equ THRESH    = 6000
.equ KP_SHIFT  = 11
.equ PWM_MIN   = 60
.equ PWM_MAX   = 200
.equ AVG_NLOG2 = 2      ; 4-sample average per read

; Registers used by “API”:
; HX returns signed 24-bit in r2:r1:r0 (LSB=r0). Caller saves what it needs.

; ---------- Reset ----------
	.cseg
	.org 0
	rjmp RESET

RESET:
	; stack
	ldi  r16, high(RAMEND)
	out  SPH, r16
	ldi  r16, low(RAMEND)
	out  SPL, r16

	; GPIO
	ldi  r16, (1<<PB_SCK1L)|(1<<PB_SCK2L)|(1<<PB_SCK2R)  ; SCK outs
	out  DDRB, r16
	out  PORTB, __zero_reg__

	ldi  r16, (1<<PD_DIR_L)|(1<<PD_PWM_L)|(1<<PD_DIR_R)|(1<<PD_PWM_R)|(1<<PD_SCK1R)
	out  DDRD, r16
	cbi  PORTD, PD_DIR_L
	cbi  PORTD, PD_DIR_R
	cbi  PORTD, PD_SCK1R

	; Limit pullups
	ldi  r16, 0x00
	out  DDRC, r16
	ldi  r16, (1<<PC_TOP_L)|(1<<PC_BOT_L)|(1<<PC_TOP_R)|(1<<PC_BOT_R)
	out  PORTC, r16

	; Timer0 -> PWM_L
	ldi  r16, (1<<WGM01)|(1<<WGM00)|(1<<COM0B1)
	out  TCCR0A, r16
	ldi  r16, (1<<CS01)|(1<<CS00)       ; clk/64
	out  TCCR0B, r16
	clr  r16
	out  OCR0B, r16

	; Timer2 -> PWM_R
	ldi  r16, (1<<WGM21)|(1<<WGM20)|(1<<COM2B1)
	out  TCCR2A, r16
	ldi  r16, (1<<CS22)                 ; clk/64
	out  TCCR2B, r16
	clr  r16
	out  OCR2B, r16

; ================== MAIN LOOP ==================
MAIN:
	; ---- LEFT corner (C) ----
	rcall HX_L_S1_AVG     ; -> r2:r1:r0 = S1L
	push r2      ; save S1L (MSB..LSB)
	push r1
	push r0
	rcall HX_L_S2_AVG     ; -> r2:r1:r0 = S2L
	pop  r20      ; restore S1L LSB -> r20:r21:r22 (repack)
	pop  r21
	pop  r22
	; diffL = S1L - S2L  (24b signed) -> r5:r4:r3
	mov  r3, r20
	mov  r4, r21
	mov  r5, r22
	sub  r3, r0
	sbc  r4, r1
	sbc  r5, r2
	; Convert diff -> pwm in r16, keep sign in r5 bit7
	mov  r16, r5   ; sign mirrored for helper
	rcall DIFF_TO_PWM_24 ; r3..r5 in, r16=pwm, r5 sign remains
	; Direction & limits
	sbrc r5,7
	rjmp L_DOWN
	; want UP
	sbi  PORTD, PD_DIR_L
	sbic PINC, PC_TOP_L
	rjmp L_SET
	rjmp L_STOP
L_DOWN:
	cbi  PORTD, PD_DIR_L
	sbic PINC, PC_BOT_L
	rjmp L_SET
	rjmp L_STOP
L_SET:
	out  OCR0B, r16
	rjmp L_DONE
L_STOP:
	clr  r16
	out  OCR0B, r16
L_DONE:

	; ---- RIGHT corner (D) ----
	rcall HX_R_S1_AVG     ; -> r2:r1:r0 = S1R
	push r2
	push r1
	push r0
	rcall HX_R_S2_AVG     ; -> r2:r1:r0 = S2R
	pop  r20
	pop  r21
	pop  r22
	; diffR = S1R - S2R -> r5:r4:r3
	mov  r3, r20
	mov  r4, r21
	mov  r5, r22
	sub  r3, r0
	sbc  r4, r1
	sbc  r5, r2
	; pwm in r16, sign r5
	rcall DIFF_TO_PWM_24
	sbrc r5,7
	rjmp R_DOWN
	; want UP
	sbi  PORTD, PD_DIR_R
	sbic PINC, PC_TOP_R
	rjmp R_SET
	rjmp R_STOP
R_DOWN:
	cbi  PORTD, PD_DIR_R
	sbic PINC, PC_BOT_R
	rjmp R_SET
	rjmp R_STOP
R_SET:
	out  OCR2B, r16
	rjmp R_DONE
R_STOP:
	clr  r16
	out  OCR2B, r16
R_DONE:
	rjmp MAIN

; =====================================================
; =============== FUNCTIONS / SUBROUTINES =============
; =====================================================

; ---- DIFF_TO_PWM_24 ---------------------------------
; IN:  r5:r4:r3 = signed 24-bit diff (MSB=r5)
; OUT: r16 = pwm (0..255). Keeps sign in r5 bit7.
; uses r17,r18,r19 as temps
DIFF_TO_PWM_24:
	; |diff| into r19:r18:r17
	mov  r17, r3
	mov  r18, r4
	mov  r19, r5
	sbrs r5,7
	rjmp DTP_ABS_OK
	com  r17
	com  r18
	com  r19
	adiw r17,1
	adc  r19, __zero_reg__
DTP_ABS_OK:
	; deadband: compare |diff| with THRESH
	ldi  r16, high(THRESH)
	cpi  r18, r16
	brlo DTP_ZERO
	brne DTP_SCALE
	ldi  r16, low(THRESH)
	cpi  r17, r16
	brlo DTP_ZERO
DTP_SCALE:
	; >> KP_SHIFT
	ldi  r16, KP_SHIFT
DTP_S1:
	lsr  r19
	ror  r18
	ror  r17
	dec  r16
	brne DTP_S1
	; take high byte as pwm candidate
	mov  r16, r17
	; clamp
	cpi  r16, PWM_MIN
	brcc DTP_GTMIN
	ldi  r16, PWM_MIN
DTP_GTMIN:
	cpi  r16, PWM_MAX
	brcs DTP_DONE
	ldi  r16, PWM_MAX
DTP_DONE:
	ret
DTP_ZERO:
	clr  r16
	ret

; ---- HX711 AVG READERS (4-sample avg by default) ----
; API: returns signed 24-bit in r2:r1:r0

; Left S1L (PB0 DT, PB1 SCK)
HX_L_S1_AVG:
	ldi  r20, (1<<PB_DT1L)            ; r20 = DT mask
	ldi  r21, (1<<PB_SCK1L)           ; r21 = SCK mask
	rjmp HX_AVG_GENERIC_PB

; Left S2L (PB2 DT, PB3 SCK)
HX_L_S2_AVG:
	ldi  r20, (1<<PB_DT2L)
	ldi  r21, (1<<PB_SCK2L)
	rjmp HX_AVG_GENERIC_PB

; Right S2R (PB4 DT, PB5 SCK) -> also on PORTB
HX_R_S2_AVG:
	ldi  r20, (1<<PB_DT2R)
	ldi  r21, (1<<PB_SCK2R)
	rjmp HX_AVG_GENERIC_PB

; Right S1R (PD2 DT, PD7 SCK) -> PORTD/PORTD
HX_R_S1_AVG:
	ldi  r20, (1<<PD_DT1R)    ; DT mask on PIND
	ldi  r21, (1<<PD_SCK1R)   ; SCK mask on PORTD
	rjmp HX_AVG_GENERIC_PD

; ---- Generic AVG on PORTB ----
; uses r22..r25 accumulators (32-bit)
HX_AVG_GENERIC_PB:
	clr  r22
	clr  r23
	clr  r24
	clr  r25
	ldi  r16, (1<<AVG_NLOG2)      ; 2 -> 4 samples
HXAGPB_LOOP:
	rcall HX_READ24_PB            ; -> r2:r1:r0
	add  r22, r0
	adc  r23, r1
	adc  r24, r2
	adc  r25, __zero_reg__
	dec  r16
	brne HXAGPB_LOOP
	; divide by 2^AVG_NLOG2 (shift right total)
	ldi  r16, AVG_NLOG2
HXAGPB_SH:
	lsr  r25
	ror  r24
	ror  r23
	ror  r22
	dec  r16
	brne HXAGPB_SH
	; return lower 24 in r2:r1:r0
	mov  r0, r22
	mov  r1, r23
	mov  r2, r24
	ret

; ---- Generic AVG on PORTD ----
HX_AVG_GENERIC_PD:
	clr  r22
	clr  r23
	clr  r24
	clr  r25
	ldi  r16, (1<<AVG_NLOG2)
HXAGPD_LOOP:
	rcall HX_READ24_PD            ; -> r2:r1:r0
	add  r22, r0
	adc  r23, r1
	adc  r24, r2
	adc  r25, __zero_reg__
	dec  r16
	brne HXAGPD_LOOP
	ldi  r16, AVG_NLOG2
HXAGPD_SH:
	lsr  r25
	ror  r24
	ror  r23
	ror  r22
	dec  r16
	brne HXAGPD_SH
	mov  r0, r22
	mov  r1, r23
	mov  r2, r24
	ret

; ---- Single 24-bit read (PORTB) ----
; Expects: r20=DT mask, r21=SCK mask
; Returns: r2:r1:r0 (MSB..LSB)
HX_READ24_PB:
	; wait DRDY low
HRPB_W: in   r17, PINB
	and  r17, r20
	brne HRPB_W
	; read 24
	clr  r2
	clr  r1
	clr  r0
	ldi  r16, 24
HRPB_BIT:
	in   r17, PORTB
	or   r17, r21
	out  PORTB, r17            ; SCK=1
	; sample DT in carry
	in   r18, PINB
	and  r18, r20
	clc
	brne HRPB_ONE
	sec
HRPB_ONE:
	rol  r0
	rol  r1
	rol  r2
	in   r17, PORTB
	and  r17, ~r21
	out  PORTB, r17            ; SCK=0
	dec  r16
	brne HRPB_BIT
	; extra pulse for gain=128
	in   r17, PORTB
	or   r17, r21
	out  PORTB, r17
	and  r17, ~r21
	out  PORTB, r17
	ret

; ---- Single 24-bit read (PORTD) ----
; Expects: r20=DT mask (on PIND), r21=SCK mask (on PORTD)
HX_READ24_PD:
	; wait DRDY low
HRPD_W: in   r17, PIND
	and  r17, r20
	brne HRPD_W
	; read 24
	clr  r2
	clr  r1
	clr  r0
	ldi  r16, 24
HRPD_BIT:
	in   r17, PORTD
	or   r17, r21
	out  PORTD, r17            ; SCK=1
	in   r18, PIND
	and  r18, r20
	clc
	brne HRPD_ONE
	sec
HRPD_ONE:
	rol  r0
	rol  r1
	rol  r2
	in   r17, PORTD
	and  r17, ~r21
	out  PORTD, r17            ; SCK=0
	dec  r16
	brne HRPD_BIT
	; extra pulse for gain=128
	in   r17, PORTD
	or   r17, r21
	out  PORTD, r17
	and  r17, ~r21
	out  PORTD, r17
	ret
