; ==============================================================================
;  INCLUDE TITLE   : Manchester Decoder for Carrera Digital 124/132
;  INCLUDE TYPE    : X DECLARATIONS    - CODE
; ==============================================================================
;  FILE            : decoder.inc
;  MAIN TITLE      : Startampel "Bären(n)keller"
;  MAIN FILE       : main.asm + main.inc
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
;  TIMER0 SETTINGS
;
;  Setup TIMER0 to trigger every 10us (100kHz).
; ------------------------------------------------------------------------------

; For 8 MHz system clock set no prescaling (system clock/1).
; 8MHz system clock (125ns) --> timer clock 31.25 kHz (32us) @ TCNT=0 (to 255).
.EQU    cfgTIMER0_CS00     =   1
.EQU    cfgTIMER0_CS01     =   0
.EQU    cfgTIMER0_CS02     =   0

; Value for preloading counter to reach 100kHz (10us) timer clock.
.EQU    cfgTIMER0_TCNT0    =   195

; ------------------------------------------------------------------------------
;  CONSTANTS
; ------------------------------------------------------------------------------
; SRAM dataspace.
.EQU    cfgSRAM_DwSize      =   44              ; Reserve SRAM memory for
                                                ; decoded datapackets (11x4Byte).

; SRAM pointer offsets.
.EQU    pStartProgCU        =    0              ; Start prog-data/CU-datapacket
.EQU    pStartPGC           =    4              ; Start pace/ghostcar datapacket
.EQU    pStartAckn          =    8              ; Start acknowledge-datapacket
.EQU    pStartCtrl0         =   12              ; Start controller 0 / slotcar 0
.EQU    pStartCtrl4         =   16              ; Start controller 4 / slotcar 4
.EQU    pStartCtrl1         =   20              ; Start controller 1 / slotcar 1
.EQU    pStartCtrl5         =   24              ; Start controller 5 / slotcar 5
.EQU    pStartCtrl2         =   28              ; Start controller 2 / slotcar 2
.EQU    pStartActive        =   32              ; Start active datapacket
.EQU    pStartCtrl3         =   36              ; Start controller 3 / slotcar 3
.EQU    pStartDebug         =   40              ; Start debugging only

.EQU    pOffsetDpPos        =    0              ; +0: Offset position/no.
.EQU    pOffsetDpCnt        =    1              ; +1: Offset length
.EQU    pOffsetDpLow        =    2              ; +2: Offset low byte
.EQU    pOffsetDpHigh       =    3              ; +3: Offset high byte

; Carrera datapacket length.
.EQU    flProgDpLength      =   12              ; Programming datapacket (12Bit)
.EQU    flPgcDpLength       =    9              ; Pace/ghostcar datapacket (9Bit)
.EQU    flActDpLength       =    7              ; Active datapacket (7Bit)
.EQU    flCtrlDpLength      =    9              ; Controller datapacket (9Bit)
.EQU    flAckDpLength       =    8              ; Acknowledge datapacket (8Bit)

; Decoder status flags.
.EQU    flTransmComplete    =   0               ; Transmission completed
.EQU    flDataEvaluated     =   1               ; Data evaluated

; Decoder check results.
.EQU    mskProgValues       =   0b00000111      ; Position of values
.EQU    flProgFinished      =   3               ; Contains startlights
.EQU    flProgStartLights   =   4               ; Contains startlights
.EQU    flProgEarlyStart    =   5               ; Early start detected
.EQU    flProgPaceCar       =   6               ; Pacecar detected
.EQU    flProgReset         =   7               ; Reset detected

; ------------------------------------------------------------------------------
;  CHECK REQUIREMENTS
; ------------------------------------------------------------------------------

; The following registers must be defined in the main program:
; ------------------------------------------------------------------------------
; .DEF    rReceivedByteL      =   (R2)      ; Received Manchester bits
; .DEF    rReceivedByteH      =   (R3)      ; Received Manchester bits
; .DEF    rReceivedBitCnt     =   (R4)      ; Counter for received bits
; .DEF    rReceivedPacketCnt  =   (R5)      ; Counter for received datapackets
; .DEF    rDecoderState       =   (R19)     ; Decoder status flag register
; .DEF    rTimeElapsedCnt     =   (R20)     ; Counter register to count elapsed time
;                                           ; between edge chances in 10us steps.
;                                           ; Used by Timer0 interrupt from decoder


.IF F_CPU != 8000000
  .Warning "DECODER.INC: MCU clock other than 8MHz. Please remember to adjust the timer configuration!"
.ENDIF

.IFNDEF rAccu
    .ERROR "DECODER.INC: rAccu not defined in main module!"
.ENDIF

.IFNDEF rScratch
    .ERROR "DECODER.INC: rScratch not defined in main module"
.ENDIF

.IFNDEF rTransfer
    .ERROR "DECODER.INC: rTransfer not defined in main module"
.ENDIF

.IFNDEF rDecoderState
    .ERROR "DECODER.INC: rDecoderState not defined in main module"
.ENDIF

.IFNDEF rTimeElapsedCnt
    .ERROR "DECODER.INC: rTimeElapsedCnt not defined in main module"
.ENDIF

.IFNDEF rReceivedByteL
    .ERROR "DECODER.INC: rReceivedByteL not defined in main module"
.ENDIF

.IFNDEF rReceivedByteH
    .ERROR "DECODER.INC: rReceivedByteH not defined in main module"
.ENDIF

.IFNDEF rReceivedBitCnt
    .ERROR "DECODER.INC: rReceivedBitCnt not defined in main module"
.ENDIF

.IFNDEF rReceivedPacketCnt
    .ERROR "DECODER.INC: rReceivedPacketCnt not defined in main module"
.ENDIF

.IFNDEF ioCMCpin
    .ERROR "DECODER.INC: ioCMCpin not defined in main module"
.ENDIF

.IFNDEF ioCMCsignal
    .ERROR "DECODER.INC: ioCMCsignal not defined in main module"
.ENDIF

; ==============================================================================
;  MACROS
; ==============================================================================

; ------------------------------------------------------------------------------
;  RANDOM ACCESS MEMORY / SRAM
; ------------------------------------------------------------------------------
.MACRO mac_DECODER_SRAMclear
    ; --------------------------------------------------------------------------
    ;  CLEAR SRAM
    ; --------------------------------------------------------------------------

    ; Load counter with SRAM size.
    ldi     rScratch, cfgSRAM_DwSize

    ; Load pointer with SRAM address.
    ldi     ZL, LOW (SRAM_DataPackets)
    ldi     ZH, HIGH (SRAM_DataPackets)

    ; Clear SRAM byte and increment pointer.
    clr     rAccu

DECODER_ClearSRAM:
    st      Z+, rAccu

    ; Decrement counter and loop until counter=0.
    dec     rScratch
    tst     rScratch
    brne    DECODER_ClearSRAM
.ENDMACRO

; ------------------------------------------------------------------------------
;  TIMER0
;
;  The interrupt is triggered every 10us and increases a counter by 1.
;  Within the ISR INT0, the elapsed time between the edge changes of the
;  carrera manchester code can be measured by evaluating the counter value.
; ------------------------------------------------------------------------------
.MACRO mac_DECODER_TIMER0init
    ; --------------------------------------------------------------------------
    ; Initialize TIMER0 for manchester clock check.
    ; --------------------------------------------------------------------------

    ; Configure prescaler.
    ldi     rAccu,  (cfgTIMER0_CS02 << CS02) | (cfgTIMER0_CS01 << CS01) | (cfgTIMER0_CS00 << CS00)
    out     TCCR0,  rAccu

    ; Preload counter.
    ldi     rAccu, cfgTIMER0_TCNT0
    out     TCNT0, rAccu

.ENDMACRO

.MACRO mac_DECODER_TIMER0start
    ; --------------------------------------------------------------------------
    ; Start / Enable TIMER0
    ; --------------------------------------------------------------------------

    ; Clear time elapsed counter
    clr     rTimeElapsedCnt

    ; Start Timer
    in      rAccu, TIMSK        ; Read current state
    sbr     rAccu, (1<<TOIE0)   ; Enable TIMER0-interrupt
    out     TIMSK, rAccu        ; Write new state

    ; * * * * * D E B U G * * * * *
    ; Outputs: Frame-start to debug led.
    ; sbi     ioDEBUGport, ioDEBUGyellow
    ; * * * * * D E B U G * * * * *

.ENDMACRO

.MACRO mac_DECODER_TIMER0stop
    ; --------------------------------------------------------------------------
    ; Stop / disable TIMER0
    ; --------------------------------------------------------------------------
    in      rAccu, TIMSK        ; Read current state
    cbr     rAccu, (1<<TOIE0)   ; Disable TIMER0-interrupt
    out     TIMSK, rAccu        ; Write new state

    ; * * * * * D E B U G * * * * *
    ; Outputs: Frame-end to debug led.
    ; cbi     ioDEBUGport, ioDEBUGyellow
    ; * * * * * D E B U G * * * * *

.ENDMACRO

; ------------------------------------------------------------------------------
;  EXTERNAL INTERRUPT INT0
;
;  The interrupt is triggered every edge change of the carrera manchester code.
;  Together with the counter from TIMER0, the carrera manchester code
;  will be decoded and the received bits are stored in the receive registers
;  (2 Byte).
; ------------------------------------------------------------------------------
.MACRO mac_DECODER_INT0init
    ; --------------------------------------------------------------------------
    ; Initialize external interrupt INT0 (PD2)
    ; --------------------------------------------------------------------------

    ; Clear depending registers and counter.
    clr     rReceivedByteL
    clr     rReceivedByteH
    clr     rReceivedBitCnt
    clr     rReceivedPacketCnt

    ; Any logical change on PD2(INT0) generates an interrupt request.
    in      rAccu, MCUCR        ; Read current state
    cbr     rAccu, (1<<ISC01)   ; ISC01 = 0
    sbr     rAccu, (1<<ISC00)   ; ISC00 = 1
    out     MCUCR, rAccu        ; Write new state
.ENDMACRO

.MACRO mac_DECODER_INT0start
    ; --------------------------------------------------------------------------
    ; Start / enable external interrupt INT0
    ; --------------------------------------------------------------------------
    in      rAccu, GIMSK        ; Read current state
    sbr     rAccu, (1<<INT0)    ; Enable INT0
    out     GIMSK, rAccu        ; Write new state
.ENDMACRO

.MACRO mac_DECODER_INT0stop
    ; --------------------------------------------------------------------------
    ; Stop / disable external interrupt INT0
    ; --------------------------------------------------------------------------
    in      rAccu, GIMSK        ; Read current state
    cbr     rAccu, (1<<INT0)    ; Disable INT0
    out     GIMSK, rAccu        ; Write new state
.ENDMACRO
