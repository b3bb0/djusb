	.device atmega328p
	.include "m328pdef.inc"

; -------- Pin aliases --------
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

; Limit switches (active-low)
.equ PC_TOP_L = 0
.equ PC_BOT_L = 1
.equ PC_TOP_R = 2
.equ PC_BOT_R = 3

; ------- Tunables -------
.equ THRESH    = 6000      ; counts deadband for |diff|
.equ KP_SHIFT  = 11        ; PWM ~ |diff| >> KP_SHIFT
.equ PWM_MIN   = 60
.equ PWM_MAX   = 200

; Registers used:
; Left S1L -> r18:r17:r16
; Left S2L -> r21:r20:r19
; Left diff -> r24:r23:r22
; Right S1R -> r15:r14:r13
; Right S2R -> r12:r11:r10
; Right diff-> r9:r8:r7
; PWM L -> r25, PWM R -> r6

; ===== Reset =====
	.cseg
	.org 0
	rjmp RESET

RESET:
	; stack
	ldi  r16, high(RAMEND)
	out  SPH, r16
	ldi  r16, low(RAMEND)
	out  SPL, r16

	; ---- Directions ----
	; PORTB: SCK1L/SCK2L/SCK2R outputs, others inputs
	ldi  r16, (1<<PB_SCK1L)|(1<<PB_SCK2L)|(1<<PB_SCK2R)
	out  DDRB, r16
	; SCK low
	out  PORTB, __zero_reg__

	; PORTD: DIR/PWM + SCK1R output, DT1R input
	ldi  r16, (1<<PD_DIR_L)|(1<<PD_PWM_L)|(1<<PD_DIR_R)|(1<<PD_PWM_R)|(1<<PD_SCK1R)
	out  DDRD, r16
	cbi  PORTD, PD_DIR_L
	cbi  PORTD, PD_DIR_R
	cbi  PORTD, PD_SCK1R

	; PORTC: limit inputs w/ pullups
	ldi  r16, 0x00
	out  DDRC, r16
	ldi  r16, (1<<PC_TOP_L)|(1<<PC_BOT_L)|(1<<PC_TOP_R)|(1<<PC_BOT_R)
	out  PORTC, r16

	; ---- Timer0 for PWM_L (OC0B PD5) ----
	ldi  r16, (1<<WGM01)|(1<<WGM00)|(1<<COM0B1)
	out  TCCR0A, r16
	ldi  r16, (1<<CS01)|(1<<CS00)       ; clk/64
	out  TCCR0B, r16
	clr  r16
	out  OCR0B, r16

	; ---- Timer2 for PWM_R (OC2B PD3) ----
	ldi  r16, (1<<WGM21)|(1<<WGM20)|(1<<COM2B1)
	out  TCCR2A, r16
	ldi  r16, (1<<CS22)                 ; clk/64
	out  TCCR2B, r16
	clr  r16
	out  OCR2B, r16

; ===================== Main loop =====================
MAIN:
	; ----- LEFT corner -----
	rcall HX1L_READ24         ; r18:r17:r16
	rcall HX2L_READ24         ; r21:r20:r19

	; diffL = S1L - S2L (signed 24b) -> r24:r23:r22
	mov  r22, r16
	mov  r23, r17
	mov  r24, r18
	sub  r22, r19
	sbc  r23, r20
	sbc  r24, r21

	rcall DIFF_TO_PWM          ; |diff|→r25 (pwm), sign in r24 bit7
	; Deadband check uses THRESH inside DIFF_TO_PWM

	; Direction & limits left
	sbrc r24,7
	rjmp L_WANT_DOWN           ; sign=1: lift -> lower
	; want UP
	sbi  PORTD, PD_DIR_L
	sbic PINC, PC_TOP_L        ; if top not hit
	rjmp L_SET
	rjmp L_STOP
L_WANT_DOWN:
	cbi  PORTD, PD_DIR_L
	sbic PINC, PC_BOT_L
	rjmp L_SET
	rjmp L_STOP
L_SET:
	out  OCR0B, r25
	rjmp LEFT_DONE
L_STOP:
	clr  r25
	out  OCR0B, r25
LEFT_DONE:

	; ----- RIGHT corner -----
	rcall HX1R_READ24         ; r15:r14:r13
	rcall HX2R_READ24         ; r12:r11:r10

	; diffR = S1R - S2R -> r9:r8:r7
	mov  r7, r13
	mov  r8, r14
	mov  r9, r15
	sub  r7, r10
	sbc  r8, r11
	sbc  r9, r12

	; Make PWM for right (returns in r6), sign in r9 bit7
	rcall DIFF_TO_PWM_R

	; Direction & limits right
	sbrc r9,7
	rjmp R_WANT_DOWN
	; want UP
	sbi  PORTD, PD_DIR_R
	sbic PINC, PC_TOP_R
	rjmp R_SET
	rjmp R_STOP
R_WANT_DOWN:
	cbi  PORTD, PD_DIR_R
	sbic PINC, PC_BOT_R
	rjmp R_SET
	rjmp R_STOP
R_SET:
	out  OCR2B, r6
	rjmp RIGHT_DONE
R_STOP:
	clr  r6
	out  OCR2B, r6
RIGHT_DONE:
	rjmp MAIN

; -------- Convert diff -> PWM (LEFT) -----------
; in  r24:r23:r22 (signed 24)
; out r25 = pwm (0..255), preserves sign in r24 bit7
DIFF_TO_PWM:
	; |diff|
	; two's abs
	sbrs r24,7
	rjmp DTP_ABS_OK
	com  r22
	com  r23
	com  r24
	adiw r22,1
	adc  r24, __zero_reg__
DTP_ABS_OK:
	; compare to THRESH (before scaling)
	ldi  r26, high(THRESH)
	cpi  r23, r26
	brlo DTP_ZERO
	brne DTP_SCALE
	ldi  r26, low(THRESH)
	cpi  r22, r26
	brlo DTP_ZERO
DTP_SCALE:
	; >> KP_SHIFT
	ldi  r26, KP_SHIFT
DTP_S1:
	lsr  r24
	ror  r23
	ror  r22
	dec  r26
	brne DTP_S1
	; take high byte as pwm candidate
	mov  r25, r22
	; clamp
	cpi  r25, PWM_MIN
	brcc DTP_GTMIN
	ldi  r25, PWM_MIN
DTP_GTMIN:
	cpi  r25, PWM_MAX
	brcs DTP_DONE
	ldi  r25, PWM_MAX
DTP_DONE:
	ret
DTP_ZERO:
	clr  r25
	ret

; -------- Convert diff -> PWM (RIGHT) ----------
; in  r9:r8:r7  (signed 24), out r6 = pwm, sign left in r9 bit7
DIFF_TO_PWM_R:
	; |diff|
	sbrs r9,7
	rjmp DTPR_ABS_OK
	com  r7
	com  r8
	com  r9
	adiw r7,1
	adc  r9, __zero_reg__
DTPR_ABS_OK:
	; compare to THRESH
	ldi  r26, high(THRESH)
	cpi  r8, r26
	brlo DTPR_ZERO
	brne DTPR_SCALE
	ldi  r26, low(THRESH)
	cpi  r7, r26
	brlo DTPR_ZERO
DTPR_SCALE:
	; >> KP_SHIFT
	ldi  r26, KP_SHIFT
DTPR_S1:
	lsr  r9
	ror  r8
	ror  r7
	dec  r26
	brne DTPR_S1
	mov  r6, r7
	; clamp
	cpi  r6, PWM_MIN
	brcc DTPR_GTMIN
	ldi  r6, PWM_MIN
DTPR_GTMIN:
	cpi  r6, PWM_MAX
	brcs DTPR_DONE
	ldi  r6, PWM_MAX
DTPR_DONE:
	ret
DTPR_ZERO:
	clr  r6
	ret

; ===== HX711 READERS =====
; Left S1L -> r18:r17:r16
HX1L_READ24:
	; wait DT low (PB0)
H1L_W: sbis PINB, PB_DT1L
	rjmp H1L_GO
	rjmp H1L_W
H1L_GO:
	clr  r18
	clr  r17
	clr  r16
	ldi  r26, 24
H1L_B:
	sbi  PORTB, PB_SCK1L
	clc
	sbic PINB, PB_DT1L
	sec
	rol  r16
	rol  r17
	rol  r18
	cbi  PORTB, PB_SCK1L
	dec  r26
	brne H1L_B
	sbi  PORTB, PB_SCK1L     ; gain=128
	cbi  PORTB, PB_SCK1L
	ret

; Left S2L -> r21:r20:r19
HX2L_READ24:
H2L_W: sbis PINB, PB_DT2L
	rjmp H2L_GO
	rjmp H2L_W
H2L_GO:
	clr  r21
	clr  r20
	clr  r19
	ldi  r26, 24
H2L_B:
	sbi  PORTB, PB_SCK2L
	clc
	sbic PINB, PB_DT2L
	sec
	rol  r19
	rol  r20
	rol  r21
	cbi  PORTB, PB_SCK2L
	dec  r26
	brne H2L_B
	sbi  PORTB, PB_SCK2L
	cbi  PORTB, PB_SCK2L
	ret

; Right S1R -> r15:r14:r13  (PD2/PD7)
HX1R_READ24:
H1R_W: sbis PIND, PD_DT1R
	rjmp H1R_GO
	rjmp H1R_W
H1R_GO:
	clr  r15
	clr  r14
	clr  r13
	ldi  r26, 24
H1R_B:
	sbi  PORTD, PD_SCK1R
	clc
	sbic PIND, PD_DT1R
	sec
	rol  r13
	rol  r14
	rol  r15
	cbi  PORTD, PD_SCK1R
	dec  r26
	brne H1R_B
	sbi  PORTD, PD_SCK1R
	cbi  PORTD, PD_SCK1R
	ret

; Right S2R -> r12:r11:r10  (PB4/PB5)
HX2R_READ24:
H2R_W: sbis PINB, PB_DT2R
	rjmp H2R_GO
	rjmp H2R_W
H2R_GO:
	clr  r12
	clr  r11
	clr  r10
	ldi  r26, 24
H2R_B:
	sbi  PORTB, PB_SCK2R
	clc
	sbic PINB, PB_DT2R
	sec
	rol  r10
	rol  r11
	rol  r12
	cbi  PORTB, PB_SCK2R
	dec  r26
	brne H2R_B
	sbi  PORTB, PB_SCK2R
	cbi  PORTB, PB_SCK2R
	ret
