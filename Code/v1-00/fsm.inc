; ==============================================================================
;  INCLUDE TITLE   : Finite-State Machine (FSM)
;  INCLUDE TYPE    : X DECLARATIONS    - CODE
; ==============================================================================
;  FILE            : state.inc
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
;  CONSTANTS
; ------------------------------------------------------------------------------

; FSM State-Numbers.
.EQU    fsmState0Init = 0       ; Waiting for data
.EQU    fsmState1Red1 = 1       ; Countdown 1
.EQU    fsmState2Red2 = 2       ; Countdown 2
.EQU    fsmState3Red3 = 3       ; Countdown 3
.EQU    fsmState4Red4 = 4       ; Countdown 4
.EQU    fsmState5Red5 = 5       ; Countdown 5 - (re-)start - chaos
.EQU    fsmState6Grn  = 6       ; Race
.EQU    fsmState7Yel1 = 7       ; Pacecar
.EQU    fsmState8Yel2 = 8       ; Early start
.EQU    fsmState9RFin = 9       ; Race finished
.EQU    fsmState10Chaos = 10      ; CHAOS

; ------------------------------------------------------------------------------
;  CHECK REQUIREMENTS
; ------------------------------------------------------------------------------

; The following registers must be defined in the main program:
; ------------------------------------------------------------------------------
; .DEF    rFsmCurrentState    =   (R6)      ; Current state, used by state machine
; .DEF    rFsmNextState       =   (R7)      ; Next state, used by state machine
; .DEF    rBlinkMask          =   (R8)      ; Register to mask blinking LEDs
; .DEF    rFsmRacing          =   (R21)     ; marks the state of the race for 
                                            ; further decision on the chaos phase by 
                                            ; the state machine

.IFNDEF rAccu
    .ERROR "FSM.INC: rAccu not defined in main module!"
.ENDIF

.IFNDEF rScratch
    .ERROR "FSM.INC: rScratch not defined in main module"
.ENDIF

.IFNDEF rTransfer
    .ERROR "FSM.INC: rTransfer not defined in main module"
.ENDIF

.IFNDEF rBlinkMask
    .ERROR "FSM.INC: rBlinkMask not defined in main module"
.ENDIF

.IFNDEF rFsmCurrentState
    .ERROR "FSM.INC: rFsmCurrentState not defined in main module"
.ENDIF

.IFNDEF rFsmNextState
    .ERROR "FSM.INC: rFsmNextState not defined in main module"
.ENDIF

.IFNDEF rFsmRacing
    .ERROR "FSM.INC: rFsmRacing not defined in main module"
.ENDIF

.IFNDEF ioLEDport
    .ERROR "FSM.INC: ioLEDport not defined in main module"
.ENDIF

.IFNDEF ioLEDred1
    .ERROR "FSM.INC: ioLEDred1 not defined in main module"
.ENDIF

.IFNDEF ioLEDred2
    .ERROR "FSM.INC: ioLEDred2 not defined in main module"
.ENDIF

.IFNDEF ioLEDred3
    .ERROR "FSM.INC: ioLEDred3 not defined in main module"
.ENDIF

.IFNDEF ioLEDred4
    .ERROR "FSM.INC: ioLEDred4 not defined in main module"
.ENDIF

.IFNDEF ioLEDred5
    .ERROR "FSM.INC: ioLEDred5 not defined in main module"
.ENDIF

.IFNDEF ioLEDgreen
    .ERROR "FSM.INC: ioLEDgreen not defined in main module"
.ENDIF

.IFNDEF ioLEDyellow
    .ERROR "FSM.INC: ioLEDyellow not defined in main module"
.ENDIF

.IFNDEF ioEarlyStart1st
    .WARNING "FSM.INC: ioEarlyStart1st not defined in main module --> Set to ioLEDred1"
    .EQU ioEarlyStart1st = ioLEDred1
.ENDIF

.IFNDEF ioEarlyStartDir
    .WARNING "FSM.INC: ioEarlyStartDir not defined in main module --> Set to right (lsr)"
    .EQU ioEarlyStartDir = 0
.ENDIF

; ==============================================================================
;  MACROS
; ==============================================================================
