;c)	Viết chương trình nhận ký tự từ UART sử dụng ngắt, xuất ký tự đó ra LCD ở vị trí đầu tiên bên trái, đồng thời đếm số ký tự nhận được và xuất ra 4 LED 7 đoạn. Khi nhận được hơn 1000 ký tự thì reset về 0.

;---------LCD-----------;
	.EQU RS = 0
	.EQU RW = 1
	.EQU EN = 2	
	.EQU LCD = PORTB
	.EQU LCD_DR = DDRB
	.EQU LCD_IN = PINB
	.DEF DATA_DISPLAY_LCD = R18
;---------LCD-----------;

;---------7SEG-----------;
	
	.EQU P_OUT_LED = PORTA
	.EQU DD_P_OUT_LED = DDRA
	.EQU LE_0 = 0
	.EQU LE_1 = 1
	.EQU P_CONTROL_E = PORTC
	.EQU DD_P_CONTROL_E = DDRC

	.DEF DATA_DISPLAY = R21
	.DEF DATA_DISPLAY_7SEG = R22
	.DEF LED_ACTIVE = R23
	.DEF DATA_DISPLAY_LED = R24
	
;---------7SEG-----------;

;---------MAIN---------;
	.DEF COUNT_L = R19
	.DEF COUNT_H = R20
	.DEF OPD3 = R2						;So du
	.DEF OPD1_H = R16					;HIGH(So bi chia)
	.DEF OPD1_L = R17					;LOW(So bi chia)
	.DEF OPD2 = R3						;So chia
	.DEF DONVI = R4
	.DEF CHUC = R5
	.DEF TRAM = R6
	.DEF NGHIN = R7

	.ORG 0
	RJMP MAIN
	
;----------Interrupt vecto table----------;
	
	.ORG $1A
	RJMP TIMER1_COMPA
	.ORG $28
	RJMP USART0_RX

;----------Interrupt vecto table----------;

	.ORG $40
MAIN:
	LDI R16, HIGH(RAMEND)
	OUT SPH, R16
	LDI R16, LOW(RAMEND)
	OUT SPL, R16

	CALL CONFIG_LCD
	CALL CONFIG_7SEG
	CALL CONFIG_USART
	CALL INIT_TIMER1_CTC

	CLR DATA_DISPLAY_LCD
	CLR DATA_DISPLAY
	CLR COUNT_L
	CLR COUNT_H
	LDI XL, $00
	LDI XH, $02
	
	SEI							;Enable interrupt globally
	
START:
	CALL DISPLAY_LCD
	RJMP START

;---Functions for UART---------;
	
CONFIG_USART:
	LDI R16, 0
	STS UBRR0H, R16
	LDI R16, 51
	STS UBRR0L, R16

	LDI R16, (1 << UCSZ00) | (1 << UCSZ01)		;8bit data 1 stop bit, no-parity
	STS UCSR0C, R16
	
	LDI R16, (1 << RXEN0) | (1 << RXCIE0)		;Enable receive and enable to interrupt receive
	STS UCSR0B, R16
	RET

USART0_RX:
	LDS DATA_DISPLAY_LCD, UDR0
	CALL CLEAR_LCD

	LDI R25, 1
	LDI R16, 0
	ADD COUNT_L, R25
	ADC COUNT_H, R16
	MOV OPD1_L, COUNT_L
	MOV OPD1_H, COUNT_H

	CALL DIV16_8
	MOV DONVI, OPD3
	STS $203, DONVI
	CALL DIV16_8
	MOV CHUC, OPD3
	STS $202, CHUC
	CALL DIV16_8
	MOV TRAM, OPD3
	STS $201, TRAM
	CALL DIV16_8
	MOV NGHIN, OPD3
	STS $200, NGHIN

;When count to 1000 --> reset counter
	CPI COUNT_L, $E8
	BREQ CONTI_SS
	RJMP DONE_RX
CONTI_SS:
	CPI COUNT_H, $03
	BREQ RESET_COUNTER
	RJMP DONE_RX

RESET_COUNTER:
	CLR COUNT_L
	CLR COUNT_H
DONE_RX:
	RETI

DIV16_8:
	PUSH R19
	LDI R19, 10
	MOV OPD2, R19
	LDI R19, 16
	CLR OPD3
SH_NXT:
	CLC
	LSL OPD1_L
	ROL OPD1_H
	ROL OPD3
	BRCS OV_C
	SUB OPD3, OPD2
	BRCC GT_TH
	ADD OPD3, OPD2
	RJMP NEXT
OV_C:
	SUB OPD3, OPD2
GT_TH:
	SBR OPD1_L, 1
NEXT:
	DEC R19
	BRNE SH_NXT
	POP R19
	RET

;---Functions for UART---------;



;---Functions for LCD-------;

CONFIG_LCD:
	SER R16					;Portc is output LCD
	OUT LCD_DR, R16
	
	CBI LCD, RS
	CBI LCD, RW
	CBI LCD, EN

	;Reset/ Activate LCD
	LDI		R16, 250	; delay 25ms
	RCALL	DELAY_US
	LDI		R16, 250	; delay 25ms
	RCALL	DELAY_US
	CBI		PORTC, RS	; RS = 0, write command mode
	LDI		R17, $30	; Command code = $30, first time
	RCALL	OUT_LCD		; output to LCD
	LDI		R16, 42		; delay 4.2ms
	RCALL	DELAY_US	
	CBI		PORTC, RS	; RS = 0, write command mode
	LDI		R17, $30	; Command code = $30, second time
	RCALL	OUT_LCD		; output to LCD
	LDI		R16, 2		; delay 200uS
	RCALL	DELAY_US	
	CBI		LCD, RS
	LDI		R17, $32	
	RCALL	OUT_LCD4_2	; output 1 byte
	LDI		R18, $28	; Function set: 4bit, 2line, font 5x8
	LDI		R19, $01	; Clear display
	LDI		R20, $0C	; Display on, cursor off
	LDI		R21, $06	; Entry mode set
	RCALL	INIT_LCD4	; module to activate 4-bit LCD

INIT_LCD4:
	CBI LCD, RS			;Write Instruction
	MOV R17, R18			;R18 is function set
	CALL OUT_LCD4_2

	MOV R17, R19			;R19 is clear display
	CALL OUT_LCD4_2			
	LDI R16, 20			;Wait 2ms after clearing
	CALL DELAY_US

	MOV R17, R20
	CALL OUT_LCD4_2
	MOV R17, R21
	CALL OUT_LCD4_2
	RET

DISPLAY_LCD:
	CBI LCD, RS
	LDI R17, $80
	CALL OUT_LCD4_2

	MOV R17, DATA_DISPLAY_LCD
	SBI LCD, RS
	CALL OUT_LCD4_2
	RET

CLEAR_LCD:
	PUSH R17
	PUSH R16
	CBI LCD,RS
	LDI R17, $01
	CALL OUT_LCD4_2
	LDI R16, 20
	CALL DELAY_US
	POP R16
	POP R17
	RET

OUT_LCD4:
	OUT LCD, R17
	SBI LCD, EN
	CBI LCD, EN
	RET

OUT_LCD4_2:
	LDI R16, 1				;Wait 100us
	CALL DELAY_US
	IN R16, LCD
	ANDI R16, (1<<RS)
	PUSH R16				;Push bit RS to stack
	PUSH R17				
	ANDI R17, $F0			;Get 4 high bit
	OR R17, R16
	CALL OUT_LCD4			
	LDI R16, 1				;Wait 100us
	CALL DELAY_US
	POP R17
	POP R16
	SWAP R17
	ANDI R17, $F0
	OR R17, R16
	CALL OUT_LCD4
	RET

DELAY_US:
	MOV R15, R16
	LDI R16, 200
L1:
	MOV R14, R16
L2:
	DEC R14
	NOP
	BRNE L2
	DEC R15
	BRNE L1
	RET
;---Functions for LCD-------;

;---Functions for 7SEG---------;

CONFIG_7SEG:
	LDI LED_ACTIVE, 0
	LDI DATA_DISPLAY, 0

	SER R17
	OUT DD_P_OUT_LED, R17		;PortA is output
	SBI DD_P_CONTROL_E, LE_0	;PB0 is LE0 that is output
	SBI DD_P_CONTROL_E, LE_1	;PB1 is LE1	that is output
	CBI P_CONTROL_E, LE_0		;Block latch
	CBI P_CONTROL_E, LE_1		;Block latch
	RET

DISPLAY_7SEG:
	LDI R25, $FF
	OUT P_OUT_LED, R25			;Turn off led
	SBI P_CONTROL_E, LE_1
	CBI P_CONTROL_E, LE_1
	LDI R25, 0

	LDI ZH, HIGH(TABLE_7SEG<<1)
	LDI ZL, LOW(TABLE_7SEG<<1)
	ADD ZL, DATA_DISPLAY
	ADC ZH, R25

	LPM DATA_DISPLAY_7SEG, Z
	OUT P_OUT_LED, DATA_DISPLAY_7SEG
	SBI P_CONTROL_E, LE_0
	CBI P_CONTROL_E, LE_0

	LDI ZH, HIGH(TABLE_CONTROL<<1)
	LDI ZL, LOW(TABLE_CONTROL<<1)
	ADD ZL, LED_ACTIVE
	ADC ZH, R25

	LPM DATA_DISPLAY_LED, Z
	OUT P_OUT_LED, DATA_DISPLAY_LED
	SBI P_CONTROL_E, LE_1
	CBI P_CONTROL_E, LE_1
	RET

TIMER1_COMPA:
	LD DATA_DISPLAY, X+
	CALL DISPLAY_7SEG

	INC LED_ACTIVE
	CPI LED_ACTIVE, 4
	BREQ RESET_LED
	RJMP DONE
RESET_LED:
	LDI LED_ACTIVE, 0
	LDI XL, $00
	LDI XH, $02
DONE:
	RETI

INIT_TIMER1_CTC:
	LDI R17, HIGH(39999)
	STS OCR1AH, R17
	LDI R17, LOW(39999)
	STS OCR1AL, R17

	LDI R17, $00
	STS TCCR1A, R17								;Mode CTC
	LDI R17, (1 << WGM12) | (1 << CS10) 		;Mode CTC, timer run with prescaler = 64
	STS TCCR1B, R17

	LDI R17, (1 << OCIE1A)		;Enable interrupt at A channel
	STS TIMSK1, R17
	RET

TABLE_7SEG: 
	.DB 0XC0, 0XF9,0XA4,0XB0,0X99,0X92,0X82,0XF8,0X80,0X90,0X88,0X8
	.DB 0XC6,0XA1,0X86,0X8E
TABLE_CONTROL:
	.DB 0b00000111, 0b00001011, 0b00001101, 0b00001110

;---Functions for 7SEG---------;
