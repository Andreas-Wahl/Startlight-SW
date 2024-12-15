; ==============================================================================
;  TITLE           : Startampel "Bären(n)keller"
; ==============================================================================
;  HW-VERSION      : 1.xx
;  SW-VERSION      : 1.0
;  SW-DATE         : 2024-01-17 (jjjj-mm-dd)
;  SW-AUTHOR       : Andreas Wahl - 73642 Welzheim - Germany
;                  : https://www.andreas-wahl.de
;  LICENSE         : GNU AFFERO GENERAL PUBLIC LICENSE
;                  : Version 3, 2007-11-19
;                  : https://www.gnu.org/licenses/
; ==============================================================================
;  CONTROLLER      : Microchip / Atmel ATtiny 2313(A)
;                    https://www.microchip.com/en-us/product/ATtiny2313
;  CLOCK           : 8 MHZ, internal system clock, (INTRCOSC_8MHZ_14CK_65MS)
;  RESET           : internal power-on reset
;  BOD             : internal, 4.3V
;  INTERRUPT USAGE : EXT INT0 (PD2), 8-bit TIMER0 (Manchester time elapsed)
;                  : 16-bit TIMER1 (led blink frequency)
;  I/O USAGE IN    : PD2 = Input signal Carrera Manchester code
;  I/O USAGE OUT   : PB0 = LED yellow, PB1 = LED green /
;                  : PB2 = LED red 5, PB3 = LED red 4, PB4 = LED red 3
;                  : PB5 = LED red 2, PB6 = LED red 1
;                  : PD5 = Debug pin/LED red, PD6 = Debug pin/LED yellow
; ==============================================================================

; ------------------------------------------------------------------------------
;  INCLUDES / DECLARATIONS
; ------------------------------------------------------------------------------
.NOLIST
;    .INCLUDE "tn2313Adef.inc"    ; Already inserted by Microchip Studio project

.LIST
    .INCLUDE "main.inc"
    .INCLUDE "decoder.inc"
    .INCLUDE "fsm.inc"

; ==============================================================================
;  RANDOM ACCESS MEMORY / SRAM
; ==============================================================================
.DSEG
    SRAM_DataPackets:     .byte cfgSRAM_DwSize      ; Data space for datapackets
                                                    ; See "decoder.inc"

; ==============================================================================
;  PROGRAM MEMORY
; ==============================================================================
.CSEG                                   ; Select FLASH
.ORG        0x0000                      ; Start program memory at address 0x0000

; ------------------------------------------------------------------------------
;  STARTUP / RESET
; ------------------------------------------------------------------------------
MAIN_000STARTUP:
        rjmp    MAIN_010INIT            ; Skip interrupt vectors

; ------------------------------------------------------------------------------
;  INTERRUPT VECTORS
; ------------------------------------------------------------------------------
.ORG    INT0addr                        ; External interrupt request 0 (PD2)
        rjmp    sub_DECODER_INT0isr
.ORG    OVF0addr                        ; Timer0/Counter0 overflow
        rjmp    sub_DECODER_TIMER0isr
.ORG    OVF1addr                        ; Timer1/Counter1 overflow
        rjmp    sub_MAIN_TIMER1isr

.ORG INT_VECTORS_SIZE                   ; Leave space to interrupt vectors

; ==============================================================================
;  MAIN PROGRAM
; ==============================================================================
MAIN_010INIT:
    ; --------------------------------------------------------------------------
    ;  INITIALIZATION SEQUENCE
    ; --------------------------------------------------------------------------

    ; Initialize STACK pointer
    ldi     rAccu, LOW(RAMEND)
    out     SPL, rAccu
    ;ldi     rAccu, HIGH(RAMEND)      ; For controllers >256kb RAM
    ;out     SPH, rAccu               ; For controllers >256kb RAM

    ; Initialize inputs - Carrera Manchester code.
    in      rAccu, ioCMCddr
    andi    rAccu, (0 << ioCMCsignal)
    out     ioCMCddr, rAccu

    ; Initialize outputs - startlights.
    ser     rAccu
    out     ioLEDddr, rAccu
    clr     rAccu
    out     ioLEDport, rAccu

    ; Initialize outputs - debug pins.
    in      rAccu, ioDEBUGddr
    ori     rAccu, (1 << ioDEBUGred) | (1 << ioDEBUGyellow)
    out     DDRD, rAccu
    cbi     ioDEBUGport, ioDEBUGred
    cbi     ioDEBUGport, ioDEBUGyellow

    ; Clear reserved SRAM.
    mac_DECODER_SRAMclear

    ; Initialize and start TIMER1 to blink LEDs.
    mac_MAIN_TIMER1init
    mac_MAIN_TIMER1start

    ; Initialize and start TIMER0
    ; to count elapsed time between Carrera Manchester code edge changes.
    mac_DECODER_TIMER0init

    ; Initialize and start external interrupt INT0
    ; to receive Carrera Manchester code edge changes.
    mac_DECODER_INT0init
    mac_DECODER_INT0start

    ; Reset transfer register.
    clr     rTransfer

    ; Enable global interrupts.
    sei

MAIN_021WAIT4DATA:
    ; --------------------------------------------------------------------------
    ;  WAIT FOR DATA
    ; --------------------------------------------------------------------------

    ; Start Green-LED blinking
    ;ldi     rAccu, ((1<<ioLEDred1) | (1<<ioLEDred3) | (1<<ioLEDred5))
    ldi     rAccu, (1<<ioLEDred3)
    out     ioLEDport, rAccu
    ;ldi     rAccu, ((1<<ioLEDred1) | (1<<ioLEDred2) | (1<<ioLEDred3) | (1<<ioLEDred4)| (1<<ioLEDred5))
    mov     rBlinkMask, rAccu
    mac_MAIN_TIMER1start

MAIN_021WAIT4DATA_10GetData:
    ; Check if TIMER0 interrupt has detected the completion of transmission.
    sbrs    rDecoderState, flTransmComplete
    rjmp    MAIN_021WAIT4DATA_10GetData
    ; Loop until there is a programm datapacket (= first datapacket) received.
    ; Only the programming datapacket has a length of 12Bits.
    ldi     rAccu, flProgDpLength
    cp      rReceivedBitCnt, rAccu
    brne    MAIN_021WAIT4DATA_10GetData
MAIN_021WAIT4DATA_10GetData_Exit:
    ; Turn all LEDs off.
    clr     rAccu
    mov     rBlinkMask, rAccu
    out     ioLEDport, rAccu
    ; Initialize finite state machine.
    rcall   sub_FSM_00init
MAIN_021WAIT4DATA_EXIT:

MAIN_022LOOP:
    ; --------------------------------------------------------------------------
    ;  MAIN LOOP
    ; --------------------------------------------------------------------------

MAIN_022LOOP_10GetData:
    ; Check if TIMER0 interrupt has detected the completion of transmission.
    sbrs    rDecoderState, flTransmComplete
    rjmp    MAIN_022LOOP_10GetData_Exit
    cbr     rDecoderState, (1<<flTransmComplete)
    rcall   sub_DECODER_SaveData                   ; Save data
MAIN_022LOOP_10GetData_Exit:

MAIN_022LOOP_20ProcessData:
    ; If a new datapacket is saved, check it.
    sbrs    rDecoderState, flDataEvaluated
    rjmp    MAIN_022LOOP_20ProcessData_Exit
    cbr     rDecoderState, (1<<flDataEvaluated)
    rcall   sub_DECODER_CheckData                   ; Evaluate data
    ; If data validation results are available, run State Machine.
    tst     rTransfer
    breq    MAIN_022LOOP_20ProcessData_Exit
    rcall   sub_FSM_00Run                           ; Run finite state machine
MAIN_022LOOP_20ProcessData_Exit:

    ; Back to main loop
    rjmp    MAIN_022LOOP

; ==============================================================================
;  SUB PROGRAMS
; ==============================================================================

sub_MAIN_TIMER1isr:
    ; --------------------------------------------------------------------------
    ;  TIMER1
    ;
    ;  The interrupt is triggered every 500ms and toggles the port pins defined
    ;  in the blink register (rBlinkMask).
    ; --------------------------------------------------------------------------
    ; Save SREG and registers to STACK.
    push    rAccu
    in      rAccu, SREG
    push    rAccu

    ; Preload counter // timerclock 2Hz (500ms).
    ldi     rAccu, HIGH(cfgTIMER1_TCNT1)
    out     TCNT1H, rAccu
    ldi     rAccu, LOW(cfgTIMER1_TCNT1)
    out     TCNT1L, rAccu

    ; Toggle LED based on den blink mask
    in      rAccu, ioLEDport
    eor     rAccu, rBlinkMask
    out     ioLEDport, rAccu

        ; Turn off Debug LED
    cbi     ioDEBUGport, ioDEBUGred
    cbi     ioDEBUGport, ioDEBUGyellow

sub_MAIN_TIMER1isr_Exit:

    ; Restore SREG and registers from STACK.
    pop     rAccu
    out     SREG, rAccu
    pop     rAccu

    ; All done! --> Return from interrupt.
    reti

; ------------------------------------------------------------------------------
;  INCLUDES - CODE
; ------------------------------------------------------------------------------
.NOLIST

.LIST
    .INCLUDE "decoder.asm"
    .INCLUDE "fsm.asm"
