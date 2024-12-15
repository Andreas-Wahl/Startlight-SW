; ==============================================================================
;  INCLUDE TITLE   : Startampel "Bären(n)keller"
;  INCLUDE TYPE    : X DECLARATIONS    - CODE
; ==============================================================================
;  FILE            : main.inc
;  SW-VERSION      : 1.0
;  SW-DATE         : 2024-01-17 (jjjj-mm-dd)
;  SW-AUTHOR       : Andreas Wahl - 73642 Welzheim - Germany
;                  : https://www.andreas-wahl.de
;  LICENSE         : GNU AFFERO GENERAL PUBLIC LICENSE
;                  : Version 3, 2007-11-19
;                  : https://www.gnu.org/licenses/
; ==============================================================================

; ==============================================================================
;  CONFIGURATION
; ==============================================================================

; ------------------------------------------------------------------------------
;  CLOCK CONFIGURATION
; ------------------------------------------------------------------------------
.EQU    F_CPU       =   8000000             ; Systemclock in Hz

; ------------------------------------------------------------------------------
;  TIMER1 SETTINGS
;
;  Setup TIMER1 to trigger every 500ms (2Hz).
; ------------------------------------------------------------------------------

; For 8 MHz system clock set prescaler to system clock/64.
; --> 8us (125kHz)
.EQU    cfgTIMER1_CS10     =   1
.EQU    cfgTIMER1_CS11     =   1
.EQU    cfgTIMER1_CS12     =   0

; Value for preloading counter to reach 2Hz (500ms) timer clock.
.EQU    cfgTIMER1_TCNT1    =   18661

; ------------------------------------------------------------------------------
;  REGISTER CONFIGURATION
; ------------------------------------------------------------------------------
; Register for short-term/temporary use. Immediate access is required.

; Comprehensive use.
.DEF    rAccu               =   R16     ; Working register
.DEF    rScratch            =   R17     ; Temporary register
.DEF    rTransfer           =   R18     ; Transfer register

; Used by decoder.
.DEF    rDecoderState       =   R19     ; Decoder status flag register
.DEF    rTimeElapsedCnt     =   R20     ; Counter register to count elapsed time
                                        ; between edge chances in 10us steps.
                                        ; Used by Timer0 interrupt from decoder
; Used by finite state machine..
.DEF    rFsmRacing          =   R21     ; marks the state of the race for 
                                        ; further decision on the chaos phase by 
                                        ; the state machine

; Register for long-term use. Immediate access is not required.
; For possible special use e.g. multiplications always skip R0 and R1.

; Used by decoder.
.DEF    rReceivedByteL      =   R2      ; Received Manchester bits
.DEF    rReceivedByteH      =   R3      ; Received Manchester bits
.DEF    rReceivedBitCnt     =   R4      ; Counter for received bits
.DEF    rReceivedPacketCnt    =   R5      ; Counter for received datapacket

; Used by finite state machine.
.DEF    rFsmCurrentState    =   R6      ; Current state, used by state machine
.DEF    rFsmNextState       =   R7      ; Next state, used by state machine

; Used by main and finite state machine.
.DEF    rBlinkMask          =   R8  ; Register to mask blinking LEDs

; ------------------------------------------------------------------------------
;  PORT and PIN CONFIGURATION
; ------------------------------------------------------------------------------
; Inputs: Carrera manchester code.
.EQU    ioCMCport          =   PORTD        ; Input port
.EQU    ioCMCpin           =   PIND         ; Input port/pin
.EQU    ioCMCddr           =   DDRD         ; DDR of input port
.EQU    ioCMCsignal        =   PIND2        ; Input pin/bit: Manchester signal

; Outputs: Startlights.
.EQU    ioLEDport          =   PORTB        ; LED output port
.EQU    ioLEDddr           =   DDRB         ; DDR of LED output port
.EQU    ioLEDred1          =   PINB6        ; Port-pin/bit: LED column red 1
.EQU    ioLEDred2          =   PINB5        ; Port-pin/bit: LED column red 2
.EQU    ioLEDred3          =   PINB4        ; Port-pin/bit: LED column red 3
.EQU    ioLEDred4          =   PINB3        ; Port-pin/bit: LED column red 4
.EQU    ioLEDred5          =   PINB2        ; Port-pin/bit: LED column red 5
.EQU    ioLEDgreen         =   PINB1        ; Port-pin/bit: LED row green
.EQU    ioLEDyellow        =   PINB0        ; Port-pin/bit: LED row yellow

; Outputs: Earlystart.
.EQU    ioEarlyStart1st    =   ioLEDred1    ; Start pin (bit) to display
                                            ; slotcar with earlystart
                                            ; (default = ioLEDred1)
.EQU    ioEarlyStartDir    =   0            ; slotcar number rotation
                                            ; (0=right [default], 1=left)

; * * * * * D E B U G * * * * *
; Outputs: Debug pins.
.EQU    ioDEBUGport         =   PORTD
.EQU    ioDEBUGpin          =   PIND
.EQU    ioDEBUGddr          =   DDRD
.EQU    ioDEBUGred          =   PIND5
.EQU    ioDEBUGyellow       =   PIND6
; * * * * * D E B U G * * * * *

; ==============================================================================
;  MACROS
; ==============================================================================

; ------------------------------------------------------------------------------
;  TIMER1
;
;  The interrupt is triggered every 500ms and toggles the port-pins defined
;  in the blink register (rBlinkMask).
; ------------------------------------------------------------------------------

.MACRO mac_MAIN_TIMER1init
    ; --------------------------------------------------------------------------
    ; Initialize TIMER1 to blink LEDs.
    ; --------------------------------------------------------------------------

    ; Configure prescaler.
    ldi     rAccu,  (cfgTIMER1_CS12 << CS12) | (cfgTIMER1_CS11 << CS11) | (cfgTIMER1_CS10 << CS10)
    out     TCCR1B,  rAccu

    ; Preload counter.
    ldi     rAccu, HIGH(cfgTIMER1_TCNT1)
    out     TCNT1H, rAccu
    ldi     rAccu, LOW(cfgTIMER1_TCNT1)
    out     TCNT1L, rAccu

    ; Clear blink register.
    clr rBlinkMask
.ENDMACRO

.MACRO mac_MAIN_TIMER1start
    ; --------------------------------------------------------------------------
    ; Start / Enable TIMER1.
    ; --------------------------------------------------------------------------
    in      rAccu, TIMSK        ; Read current state
    sbr     rAccu, 1<<TOIE1     ; Enable TIMER1
    out     TIMSK, rAccu        ; Write new state
.ENDMACRO

.MACRO mac_MAIN_TIMER1stop
    ; --------------------------------------------------------------------------
    ; Stop / Disable TIMER1.
    ; --------------------------------------------------------------------------
    in      rAccu, TIMSK        ; Read current state
    sbr     rAccu, 0<<TOIE1     ; Enable TIMER1
    out     TIMSK, rAccu        ; Write new state
.ENDMACRO

.MACRO mac_MAIN_TIMER1restart
    ; --------------------------------------------------------------------------
    ; Restart TIMER1.
    ; --------------------------------------------------------------------------

    ; Stop TIMER1.
    mac_MAIN_TIMER1stop

    ; Preload counter for 2Hz (500ms) timer clock.
    ldi     rAccu, HIGH(cfgTIMER1_TCNT1)
    out     TCNT1H, rAccu
    ldi     rAccu, LOW(cfgTIMER1_TCNT1)
    out     TCNT1L, rAccu

    ; Start TIMER1.
    mac_MAIN_TIMER1start
.ENDMACRO

