; ==============================================================================
;  INCLUDE TITLE   : Finite State Machine (FSM)
;  INCLUDE TYPE    : - DEKLARATIONS    X CODE
;  FILE            : fsm.asm
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
;  REQUIREMENTS:
;
;  Include file:
;  - fsm.inc
;
;  Register:
;  - rAccu (>=R16)
;  - rScratch (>=R16)
;  - rTransfer (>=R16)
;  - rBlinkMask
;  - rFsmCurrentState
;  - rFsmNextState
;
;  I/O - Output configuration for startlights:
;  - ioLEDport
;  - ioLEDred1, ioLEDred2, ioLEDred3, ioLEDred4, ioLEDred5
;  - ioLEDgreen
;  - ioLEDyellow
;  - ioEarlyStart1st
;  - ioEarlyStart1st (Start pin/bit to display slotcar with early start)
;  - ioEarlyStartDir (Slotcar number rotation [0=right, 1=left])
;
; ==============================================================================
;  DESCRIPTION:
;
;  The state of the startlights follow defined steps.
;  Moving from one step to the next depends on fixed conditions.
;  Therefore, the code is designed in the form of a finite state machine (FSM).
;
;  The following state of the startlights are defined:
;
;      State  0 - Init-Training         --> Green LED row = on
;      State  1 - Countdown 1           --> 1. Red LED column = on
;      State  2 - Countdown 2           --> 1.-2. Red LED column = on
;      State  3 - Countdown 3           --> 1.-3. Red LED column = on
;      State  4 - Countdown 4           --> 1.-4. Red LED column = on
;      State  5 - Countdown 5           --> All red LED columns = on
;      State  6 - Race                  --> Green LED row = on
;      State  7 - PaceCar               --> Yellow LED row = blinking
;      State  8 - EarlyStart            --> Yellow LED = on,
;                                           Red LED column (slotcar) = blinking
;      State  9 - Finished              --> Green LED = blinking,
;                                           Red LED column (slotcar) = on
;      State 10 - Chaos                 --> All red LED = blinking,
;      --- Above not specified LEDs are off ---
;
;  State table:
;  ------------
;
;       Current State | Exit Event                    | Next State     |
;      ---------------+-------------------------------+----------------|
;       State0Init    | Race (CU all LED off)         | State6Grn      |
;                     | Countdown 5 (CU 5 LED on)     | State5Red5     |
;                     | Reset detected                | State0Init     |
;      ---------------+-------------------------------+----------------|
;       State1Red1    | Countdown 2 (CU 2 LED on)     | State2Red2     |
;                     | Countdown 5 (CU 5 LED on)     | State5Red5     |
;                     | Early start detected          | State8Yel2     |
;                     | Reset detected                | State0Init     |
;      ---------------+-------------------------------+----------------|
;       State2Red2    | Countdown 3 (CU 3 LED on)     | State3Red3     |
;                     | Countdown 5 (CU 5 LED on)     | State5Red5     |
;                     | Early start detected          | State8Yel2     |
;                     | Reset detected                | State0Init     |
;      ---------------+-------------------------------+----------------|
;       State3Red3    | Countdown 4 (CU 4 LED on)     | State4Red4     |
;                     | Countdown 5 (CU 5 LED on)     | State5Red5     |
;                     | Early start detected          | State8Yel2     |
;                     | Reset detected                | State0Init     |
;      ---------------+-------------------------------+----------------|
;       State4Red4    | Countdown 5 (CU 5 LED on)     | State5Red5     |
;                     | Early start detected          | State8Yel2     |
;                     | Reset detected                | State0Init     |
;      ---------------+-------------------------------+----------------|
;       State5Red5    | Race (CU all LED off)         | State0Race     |
;                     | Countdown 1 (CU 1 LED on)     | State1Red1     |
;                     | Early start detected          | State8Yel2     |
;                     | Reset detected                | State0Init     |
;      ---------------+-------------------------------+----------------|
;       State6Grn     | Countdown 5 (CU 5 LED on)     | State5Red5     |
;                     | Chaos (CU 5 LED on & RACE)    | State10Chaos   |
;                     | Early start detected          | State8Yel2     |
;                     | Pacecar active                | State8Yel1     |
;                     | Race finished                 | State9RFin     |
;                     | Reset detected                | State0Init     |
;      ---------------+-------------------------------+----------------|
;       State7Yel1    | Pacecar inactive              | State6Grn      |
;       (PaceCar)     | Reset detected                | State0Init     |
;      ---------------+-------------------------------+----------------|
;       State8Yel2    | Countdown (CU 5 LED on)       | State1Red5     |
;       (EarlyStart)  | Reset detected                | State0Init     |
;      ---------------+-------------------------------+----------------|
;       State9RFin    | Countdown (CU 5 LED on)       | State1Red5     |
;       (R. Finished) | Reset detected                | State0Init     |
;      ---------------+-------------------------------+----------------|
;       State10Chaos  | Race (CU all LED off)         | State0Race     |
;                     | Countdown 1 (CU 1 LED on)     | State1Red1     |
;                     | Reset detected                | State0Init     |
;      -----------------------------------------------------------------
; ==============================================================================

sub_FSM_00init:
    ; --------------------------------------------------------------------------
    ;  FINITE STATE MACHINE (FSM) - INIT
    ; --------------------------------------------------------------------------

    ; Save SREG and registers to STACK.
    push    ZL
    push    ZH
    push    rScratch
    push    rAccu
    in      rAccu, SREG
    push    rAccu

    ; Prepare registers.
    ldi     rAccu, fsmState0Init
    mov     rFsmNextState, rAccu            ; Set Init-State

    ; Change State
    rjmp    FSM_98ChangeState

sub_FSM_00run:
    ; --------------------------------------------------------------------------
    ;  FINITE STATE MACHINE (FSM) - RUN
    ; --------------------------------------------------------------------------

    ; Save SREG and registers to STACK.
    push    ZL
    push    ZH
    push    rScratch
    push    rAccu
    in      rAccu, SREG
    push    rAccu

    ; Prepare registers.
    mov     rFsmNextState, rFsmCurrentState ; Set next state to current state
    clr     rScratch                        ; Clear for use as pointer offset

    ; Jump to current state.
    ldi     ZH, HIGH (FSM_adrStateRun)      ; Load jumptable address...
    ldi     ZL, LOW (FSM_adrStateRun)       ; ...to pointer.
    add     ZL, rFsmCurrentState            ; Add state offset
    clr     rAccu
    adc     ZH, rAccu                       ; Consider carryflag

    ijmp                                    ; Jump to current state

    ; --------------------------------------------------------------------------
    ; State 0 - init-state - waiting for CU data.
    ; --------------------------------------------------------------------------
FSM_10State0Init_0Entry:
    ; Set new state.
    ldi     rAccu,  fsmState0Init
    mov     rFsmCurrentState, rAccu
    ; Clear Racing State
    clr     rFsmRacing
    ; Out startlights.
    ldi     rAccu, (1<<ioLEDgreen)
    out     ioLEDport, rAccu

FSM_10State0Init_1Run:
    ; Check exit conditions.
    mov     rScratch, rFsmCurrentState

FSM_10State0Init_1Run_1:
    ; Check if countdown 0 - race - track open.
    sbrs    rTransfer, flProgStartLights
    rjmp    FSM_10State0Init_1Run_3
    mov     rAccu, rTransfer
    andi    rAccu, mskProgValues            ; Mask values
    cpi     rAccu, 0x00                     ; All LED off
    brne    FSM_10State0Init_1Run_2
    ldi     rScratch, fsmState6Grn

FSM_10State0Init_1Run_2:
    ; Check if countdown 5 - prepare start / track closed / chaos.
    cpi     rAccu, 0x05                     ; 5 LED on
    brne    FSM_10State0Init_1Run_3
    ldi     rScratch, fsmState5Red5

FSM_10State0Init_1Run_3:
    ; Check if pacecar.
    sbrs    rTransfer, flProgPaceCar
    rjmp    FSM_10State0Init_1Run_4
    mov     rAccu, rTransfer
    andi    rAccu, 0x01                     ; Mask pacecar bit
    cpi     rAccu, 0x01                     ; Check pacecar
    brne    FSM_10State0Init_1Run_4
    ldi     rScratch, fsmState7Yel1

FSM_10State0Init_1Run_4:
    ; Check if reset.
    sbrc    rTransfer, flProgReset
    ldi     rScratch, fsmState0Init

FSM_10State0Init_1Run_9:
    ; If a new state is set, exit the current state.
    mov     rFsmNextState, rScratch
    cp      rFsmCurrentState, rFsmNextState
    brne    FSM_10State0Init_9Exit
    rjmp    FSM_99Exit

FSM_10State0Init_9Exit:
    ; Out startlights.
    ldi     rAccu, (1<<ioLEDgreen)
    com     rAccu
    and     rBlinkMask, rAccu
    cbi     ioLEDport, ioLEDgreen
    ; Jump to new state entry.
    rjmp    FSM_98ChangeState

    ; --------------------------------------------------------------------------
    ; State 1 - Countdown 1.
    ; --------------------------------------------------------------------------
FSM_11State1Red1_0Entry:
    ; Set new state.
    ldi     rAccu, fsmState1Red1
    mov     rFsmCurrentState, rAccu
    ; Out startlights.
    ldi     rAccu, (1<<ioLEDred1)
    out     ioLEDport, rAccu
    ; Set Racing State
    ldi     rFsmRacing, 0x01

FSM_11State1Red1_1Run:
    ; Check exit conditions.
    mov     rScratch, rFsmCurrentState

FSM_11State1Red1_1Run_1:
    ; Check if countdown 2.
    sbrs    rTransfer, flProgStartLights
    rjmp    FSM_11State1Red1_1Run_3
    mov     rAccu, rTransfer
    andi    rAccu, mskProgValues            ; Mask values
    cpi     rAccu, 0x02                     ; 2 LED on
    brne    FSM_11State1Red1_1Run_2
    ldi     rScratch, fsmState2Red2

FSM_11State1Red1_1Run_2:
    ; Check if countdown 5 - (re-)start.
    cpi     rAccu, 0x05                     ; 5 LED on
    brne    FSM_11State1Red1_1Run_3
    ldi     rScratch, fsmState5Red5

FSM_11State1Red1_1Run_3:
    ; Check if early start.
    sbrc    rTransfer, flProgEarlyStart
    ldi     rScratch, fsmState8Yel2

FSM_11State1Red1_1Run_4:
    ; Check if reset.
    sbrc    rTransfer, flProgReset
    ldi     rScratch, fsmState0Init

FSM_11State1Red1_1Run_9:
    ; If a new state is set, exit the current state.
    mov     rFsmNextState, rScratch
    cp      rFsmCurrentState, rFsmNextState
    brne    FSM_11State1Red1_9Exit
    rjmp    FSM_99Exit

FSM_11State1Red1_9Exit:
    ; Out startlights.
    clr     rAccu
    out     ioLEDport, rAccu
    ; Jump to new state entry.
    rjmp    FSM_98ChangeState

    ; --------------------------------------------------------------------------
    ; State 2 - Countdown 2.
    ; --------------------------------------------------------------------------
FSM_12State2Red2_0Entry:
    ; Set new state.
    ldi     rAccu, fsmState2Red2
    mov     rFsmCurrentState, rAccu
    ; Out startlights.
    ldi     rAccu, (1<<ioLEDred1) | (1<<ioLEDred2)
    out     ioLEDport, rAccu
    ; Update Racing State
    lsl     rFsmRacing

FSM_12State2Red2_1Run:
    ; Check exit conditions.
    mov     rScratch, rFsmCurrentState

FSM_12State2Red2_1Run_1:
    ; Check if countdown 3.
    sbrs    rTransfer, flProgStartLights
    rjmp    FSM_12State2Red2_1Run_3
    mov     rAccu, rTransfer
    andi    rAccu, mskProgValues            ; Mask values
    cpi     rAccu, 0x03                     ; 3 LED on
    brne    FSM_12State2Red2_1Run_2
    ldi     rScratch, fsmState3Red3

FSM_12State2Red2_1Run_2:
    ; Check if countdown 5 - (re-)start.
    cpi     rAccu, 0x05                     ; 5 LED on
    brne    FSM_12State2Red2_1Run_3
    ldi     rScratch, fsmState5Red5

FSM_12State2Red2_1Run_3:
    ; Check if early start.
    sbrc    rTransfer, flProgEarlyStart
    ldi     rScratch, fsmState8Yel2

FSM_12State2Red2_1Run_4:
    ; Check if reset.
    sbrc    rTransfer, flProgReset
    ldi     rScratch, fsmState0Init

FSM_12State2Red2_1Run_9:
    ; If a new state is set, exit the current state.
    mov     rFsmNextState, rScratch
    cp      rFsmCurrentState, rFsmNextState
    brne    FSM_12State2Red2_9Exit
    rjmp    FSM_99Exit

FSM_12State2Red2_9Exit:
    ; Out startlights.
    clr     rAccu
    out     ioLEDport, rAccu
    ; Jump to new state entry.
    rjmp    FSM_98ChangeState

    ; --------------------------------------------------------------------------
    ; State 3 - Countdown 3.
    ; --------------------------------------------------------------------------
FSM_13State3Red3_0Entry:
    ; Set new state.
    ldi     rAccu, fsmState3Red3
    mov     rFsmCurrentState, rAccu
    ; Out startlights.
    ldi     rAccu, (1<<ioLEDred1) | (1<<ioLEDred2) | (1<<ioLEDred3)
    out     ioLEDport, rAccu
    ; Update Racing State
    lsl     rFsmRacing

FSM_13State3Red3_1Run:
    ; Check exit conditions.
    mov     rScratch, rFsmCurrentState

FSM_13State3Red3_1Run_1:
    ; Check if countdown 4.
    sbrs    rTransfer, flProgStartLights
    rjmp    FSM_13State3Red3_1Run_3
    mov     rAccu, rTransfer
    andi    rAccu, mskProgValues            ; Mask values
    cpi     rAccu, 0x04                     ; 4 LED on
    brne    FSM_13State3Red3_1Run_2
    ldi     rScratch, fsmState4Red4

FSM_13State3Red3_1Run_2:
    ; Check if countdown 5 - (re-)start.
    cpi     rAccu, 0x05                     ; 5 LED on
    brne    FSM_13State3Red3_1Run_3
    ldi     rScratch, fsmState5Red5

FSM_13State3Red3_1Run_3:
    ; Check if early start.
    sbrc    rTransfer, flProgEarlyStart
    ldi     rScratch, fsmState8Yel2

FSM_13State3Red3_1Run_4:
    ; Check if reset.
    sbrc    rTransfer, flProgReset
    ldi     rScratch, fsmState0Init

FSM_13State3Red3_1Run_9:
    ; If a new state is set, exit the current state.
    mov     rFsmNextState, rScratch
    cp      rFsmCurrentState, rFsmNextState
    brne    FSM_13State3Red3_9Exit
    rjmp    FSM_99Exit

FSM_13State3Red3_9Exit:
    ; Out startlights.
    clr     rAccu
    out     ioLEDport, rAccu
    ; Jump to new state entry.
    rjmp    FSM_98ChangeState

    ; --------------------------------------------------------------------------
    ; State 4 - Countdown 4.
    ; --------------------------------------------------------------------------
FSM_14State4Red4_0Entry:
    ; Set new state.
    ldi     rAccu, fsmState4Red4
    mov     rFsmCurrentState, rAccu
    ; Out startlights.
    ldi     rAccu, (1<<ioLEDred1) | (1<<ioLEDred2) | (1<<ioLEDred3) | (1<<ioLEDred4)
    out     ioLEDport, rAccu
    ; Update Racing State
    lsl     rFsmRacing

FSM_14State4Red4_1Run:
    ; Check exit conditions.
    mov     rScratch, rFsmCurrentState

FSM_14State4Red4_1Run_1:
    ; Check if countdown 5.
    sbrs    rTransfer, flProgStartLights
    rjmp    FSM_14State4Red4_1Run_2
    mov     rAccu, rTransfer
    andi    rAccu, mskProgValues            ; Mask values
    cpi     rAccu, 0x05                     ; 5 LED on
    brne    FSM_14State4Red4_1Run_2
    ldi     rScratch, fsmState5Red5

FSM_14State4Red4_1Run_2:
    ; Check if early start.
    sbrc    rTransfer, flProgEarlyStart
    ldi     rScratch, fsmState8Yel2

FSM_14State4Red4_1Run_3:
    ; Check if reset.
    sbrc    rTransfer, flProgReset
    ldi     rScratch, fsmState0Init

FSM_14State4Red4_1Run_9:
    ; If a new state is set, exit the current state.
    mov     rFsmNextState, rScratch
    cp      rFsmCurrentState, rFsmNextState
    brne    FSM_14State4Red4_9Exit
    rjmp    FSM_99Exit

FSM_14State4Red4_9Exit:
    ; Out startlights.
    clr     rAccu
    out     ioLEDport, rAccu
    ; Jump to new state entry.
    rjmp    FSM_98ChangeState

    ; --------------------------------------------------------------------------
    ; State 5 - Countdown 5.
    ; --------------------------------------------------------------------------
FSM_15State5Red5_0Entry:
    ; Set new state.
    ldi     rAccu, fsmState5Red5
    mov     rFsmCurrentState, rAccu
    ; Out startlights.
    ldi     rAccu, (1<<ioLEDred1) | (1<<ioLEDred2) | (1<<ioLEDred3) | (1<<ioLEDred4) | (1<<ioLEDred5)
    out     ioLEDport, rAccu
    ; Update Racing State
    lsl     rFsmRacing

FSM_15State5Red5_1Run:
    ; Check exit conditions.
    mov     rScratch, rFsmCurrentState

FSM_15State5Red5_1Run_1:
    ; Check if countdown 0 - Race - Track open.
    sbrs    rTransfer, flProgStartLights
    rjmp    FSM_15State5Red5_1Run_3
    mov     rAccu, rTransfer
    andi    rAccu, mskProgValues            ; Mask values
    cpi     rAccu, 0x00                     ; All LED off
    brne    FSM_15State5Red5_1Run_2
    ldi     rScratch, fsmState6Grn
    rjmp    FSM_15State5Red5_1Run_3

FSM_15State5Red5_1Run_2:
    ; Check if countdown 1 - start countdown.
    cpi     rAccu, 0x01                     ; 1 LED on
    brne    FSM_15State5Red5_1Run_3
    ldi     rScratch, fsmState1Red1

FSM_15State5Red5_1Run_3:
    ; Check if early start.
    sbrc    rTransfer, flProgEarlyStart
    ldi     rScratch, fsmState8Yel2

FSM_15State5Red5_1Run_4:
    ; Check if reset.
    sbrc    rTransfer, flProgReset
    ldi     rScratch, fsmState0Init

FSM_15State5Red5_1Run_9:
    ; If a new state is set, exit the current state.
    mov     rFsmNextState, rScratch
    cp      rFsmCurrentState, rFsmNextState
    brne    FSM_15State5Red5_9Exit
    rjmp    FSM_99Exit

FSM_15State5Red5_9Exit:
    ; Out startlights.
    clr     rAccu
    out     ioLEDport, rAccu

    ; Jump to new state entry.
    rjmp    FSM_98ChangeState

    ; --------------------------------------------------------------------------
    ; State 6 - race - track open.
    ; --------------------------------------------------------------------------
FSM_16State6Grn_0Entry:
    ; Set new state.
    ldi     rAccu, fsmState6Grn
    mov     rFsmCurrentState, rAccu
    ; Out startlights.
    ldi     rAccu, (1<<ioLEDgreen)
    out     ioLEDport, rAccu

FSM_16State6Grn_1Run:
    ; Check exit conditions.
    mov     rScratch, rFsmCurrentState

FSM_16State6Grn_1Run_1:
    ; Check if countdown 5 - track closed - prepare for start.
    sbrs    rTransfer, flProgStartLights
    rjmp    FSM_16State6Grn_1Run_2
    mov     rAccu, rTransfer
    andi    rAccu, mskProgValues            ; Mask values
    cpi     rAccu, 0x05                     ; 5 LED on
    brne    FSM_16State6Grn_1Run_2
    ldi     rScratch, fsmState5Red5
    ; Check if chaos.
    sbrs    rFsmRacing, 4
    rjmp    FSM_16State6Grn_1Run_2
    ldi     rScratch, fsmState10Chaos

FSM_16State6Grn_1Run_2:
    ; Check if pacecar.
    sbrs    rTransfer, flProgPaceCar
    rjmp    FSM_16State6Grn_1Run_3
    mov     rAccu, rTransfer
    andi    rAccu, 0x01                     ; Mask pacecar bit
    cpi     rAccu, 0x01                     ; Check pacecar
    brne    FSM_16State6Grn_1Run_3
    ldi     rScratch, fsmState7Yel1

FSM_16State6Grn_1Run_3:
    ; Check if early start.
    sbrc    rTransfer, flProgEarlyStart
    ldi     rScratch, fsmState8Yel2

FSM_16State6Grn_1Run_4:
    ; Check if race finished.
    sbrc    rTransfer, flProgFinished
    ldi     rScratch, fsmState9RFin

FSM_16State6Grn_1Run_5:
    ; Check if reset.
    sbrc    rTransfer, flProgReset
    ldi     rScratch, fsmState0Init

FSM_16State6Grn_1Run_9:
    ; If a new state is set, exit the current state.
    mov     rFsmNextState, rScratch
    cp      rFsmCurrentState, rFsmNextState
    brne    FSM_16State6Grn_9Exit
    rjmp    FSM_99Exit

FSM_16State6Grn_9Exit:
    ; Out startlights.
    clr     rAccu
    out     ioLEDport, rAccu
    ; Jump to new state entry.
    rjmp    FSM_98ChangeState

    ; --------------------------------------------------------------------------
    ; State 7 - Pacecar.
    ; --------------------------------------------------------------------------
FSM_17State7Yel1_0Entry:
    ; Set new state.
    ldi     rAccu, fsmState7Yel1
    mov     rFsmCurrentState, rAccu
    ; Out startlights.
    ; Reload timer so that first blink period starts completely with lights on.
    mac_MAIN_TIMER1restart
    sbi     ioLEDport, ioLEDyellow
    ldi     rAccu, (1<<ioLEDyellow)
    or      rBlinkMask, rAccu

FSM_17State7Yel1_1Run:
    ; Check exit conditions.
    mov     rScratch, rFsmCurrentState

FSM_17State7Yel1_1Run_1:
    ; Check pacecar.
    sbrs    rTransfer, flProgPaceCar
    rjmp    FSM_17State7Yel1_1Run_2
    mov     rAccu, rTransfer
    andi    rAccu, 0x01                     ; Mask pacecar bit
    cpi     rAccu, 0x00                     ; Check pacecar
    brne    FSM_17State7Yel1_1Run_2
    ldi     rScratch, fsmState6Grn

FSM_17State7Yel1_1Run_2:
    ; Reset.
    sbrc    rTransfer, flProgReset
    ldi     rScratch, fsmState0Init

FSM_17State7Yel1_1Run_9:
    ; If a new state is set, exit the current state.
    mov     rFsmNextState, rScratch
    cp      rFsmCurrentState, rFsmNextState
    brne    FSM_17State7Yel1_9Exit
    rjmp    FSM_99Exit

FSM_17State7Yel1_9Exit:
    ; Out startlights.
    ldi     rAccu, (1<<ioLEDyellow)
    com     rAccu
    and     rBlinkMask, rAccu
    cbi     ioLEDport, ioLEDyellow
    ; Jump to new state entry.
    rjmp    FSM_98ChangeState

    ; --------------------------------------------------------------------------
    ; State 8 - Early start.
    ; --------------------------------------------------------------------------
FSM_18State8Yel2_0Entry:
    ; Set new state.
    ldi     rAccu, fsmState8Yel2
    mov     rFsmCurrentState, rAccu
    ; Out startlights.
    sbi     ioLEDport, ioLEDyellow
    ; Move bit for LED row to
    ; number of controller/slotcar with early start.
    mov     rAccu, rTransfer
    andi    rAccu, mskProgValues            ; Mask values
    ldi     rScratch, (1<<ioEarlyStart1st)
    ; If controller/slotcar 6 then select red led row (1+5=6)
    ; because there are only 5 led rows available.
    cpi     rAccu, 5
    brne    FSM_18State8Yel2_0Entry_1SlotcarLoop
    ldi     rScratch, (1<<ioLEDred1) | (1<<ioLEDred5)
    rjmp    FSM_18State8Yel2_0Entry_2SlotcarEnd

FSM_18State8Yel2_0Entry_1SlotcarLoop:
    tst     rAccu
    breq    FSM_18State8Yel2_0Entry_2SlotcarEnd
    dec     rAccu
    ; Rotate according to configuration (main.inc).
.if  ioEarlyStartDir == 1
    .message "Early start-rotation set to LSL"
    lsl     rScratch
.else
    .message "Early start-rotation set to LSR"
    lsr     rScratch
.endif
    rjmp    FSM_18State8Yel2_0Entry_1SlotcarLoop

FSM_18State8Yel2_0Entry_2SlotcarEnd:
    ; Out startlights.
    ; Reload timer so that first blink period starts completly with lights on.
    mac_MAIN_TIMER1restart              ; rAccu will be changed, rScratch not
    mov     rBlinkMask, rScratch
    in      rAccu, ioLEDport
    or      rAccu, rScratch
    out     ioLEDport, rAccu

FSM_18State8Yel2_1Run:
    ; Check exit conditions.
    mov     rScratch, rFsmCurrentState

FSM_18State8Yel2_1Run_1:
    ; Countdown 0 - race - track open.
    sbrs    rTransfer, flProgStartLights
    rjmp    FSM_11State1Red1_1Run_1
    mov     rAccu, rTransfer
    andi    rAccu, mskProgValues            ; Mask values
    cpi     rAccu, 0x00                     ; All LED off
    brne    FSM_18State8Yel2_1Run_2
    ldi     rScratch, fsmState6Grn

FSM_18State8Yel2_1Run_2:
   ; Check if countdown 5 - track closed - chaos - prepare start.
    sbrs    rTransfer, flProgStartLights
    rjmp    FSM_18State8Yel2_1Run_3
    mov     rAccu, rTransfer
    andi    rAccu, mskProgValues            ; Mask values
    cpi     rAccu, 0x05                     ; 5 LED on
    brne    FSM_18State8Yel2_1Run_3
    ldi     rScratch, fsmState5Red5

FSM_18State8Yel2_1Run_3:
    ; Check if reset.
    sbrc    rTransfer, flProgReset
    ldi     rScratch, fsmState0Init

FSM_18State8Yel2_1Run_9:
    ; If a new state is set, exit the current state.
    mov     rFsmNextState, rScratch
    cp      rFsmCurrentState, rFsmNextState
    brne    FSM_18State8Yel2_9Exit
    rjmp    FSM_99Exit

FSM_18State8Yel2_9Exit:
    ; Out startlights.
    clr     rAccu
    mov     rBlinkMask, rAccu
    out     ioLEDport, rAccu
    ; Jump to new state entry
    rjmp    FSM_98ChangeState

    ; --------------------------------------------------------------------------
    ; State 9 - Race finished.
    ; --------------------------------------------------------------------------
FSM_19State9RFin_0Entry:
    ; Set new state.
    ldi     rAccu, fsmState9RFin
    mov     rFsmCurrentState, rAccu
    ; Clear Racing State
    clr     rFsmRacing
    ; Out startlights.
    mac_MAIN_TIMER1restart
    sbi     ioLEDport, ioLEDgreen
    ldi     rAccu, (1<<ioLEDgreen)
    or      rBlinkMask, rAccu

    ; Move bit for LED row to
    ; number of controller/slotcar with early start.
    mov     rAccu, rTransfer
    andi    rAccu, mskProgValues            ; Mask values
    ldi     rScratch, (1<<ioEarlyStart1st)
    ; If controller/slotcar 6 then select red led row (1+5=6)
    ; because there are only 5 led rows available.
    cpi     rAccu, 5
    brne    FSM_19State9RFin_0Entry_1SlotcarLoop
    ldi     rScratch, (1<<ioLEDred1) | (1<<ioLEDred5)
    rjmp    FSM_19State9RFin_0Entry_2SlotcarEnd

FSM_19State9RFin_0Entry_1SlotcarLoop:
    tst     rAccu
    breq    FSM_19State9RFin_0Entry_2SlotcarEnd
    dec     rAccu
    ; Rotate according to configuration (main.inc).
.if  ioEarlyStartDir == 1
    .message "Winner-rotation set to LSL"
    lsl     rScratch
.else
    .message "Winner-rotation set to LSR"
    lsr     rScratch
.endif
    rjmp    FSM_19State9RFin_0Entry_1SlotcarLoop

FSM_19State9RFin_0Entry_2SlotcarEnd:
    ; Out startlights.
    in      rAccu, ioLEDport
    or      rAccu, rScratch
    out     ioLEDport, rAccu

FSM_19State9RFin_1Run:
    ; Check exit conditions.
    mov     rScratch, rFsmCurrentState

FSM_19State9RFin_1Run_1:
   ; Check if countdown 5 - track closed - chaos - prepare start.
    sbrs    rTransfer, flProgStartLights
    rjmp    FSM_19State9RFin_1Run_2
    mov     rAccu, rTransfer
    andi    rAccu, mskProgValues            ; Mask values
    cpi     rAccu, 0x05                     ; 5 LED on
    brne    FSM_19State9RFin_1Run_2
    ldi     rScratch, fsmState5Red5

FSM_19State9RFin_1Run_2:
    ; Check if reset.
    sbrc    rTransfer, flProgReset
    ldi     rScratch, fsmState0Init

FSM_19State9RFin_1Run_9:
    ; If a new state is set, exit the current state.
    mov     rFsmNextState, rScratch
    cp      rFsmCurrentState, rFsmNextState
    brne    FSM_19State9RFin_9Exit
    rjmp    FSM_99Exit

FSM_19State9RFin_9Exit:
    ; Out startlights.
    clr     rAccu
    mov     rBlinkMask, rAccu
    out     ioLEDport, rAccu
    ; Jump to new state entry.
    rjmp    FSM_98ChangeState

    ; --------------------------------------------------------------------------
    ; State 10 - CHAOS
    ; --------------------------------------------------------------------------
FSM_20State10Chaos_0Entry:
    ; Set new state.
    ldi     rAccu, fsmState10Chaos
    mov     rFsmCurrentState, rAccu
    ; Out startlights.
    ; Reload timer so that first blink period starts completely with lights on.
    mac_MAIN_TIMER1restart
    ldi     rAccu, (1<<ioLEDred1) | (1<<ioLEDred2) | (1<<ioLEDred3) | (1<<ioLEDred4) | (1<<ioLEDred5)
    out     ioLEDport, rAccu
    mov      rBlinkMask, rAccu

FSM_20State10Chaos_1Run:
    ; Check exit conditions.
    mov     rScratch, rFsmCurrentState

FSM_20State10Chaos_1Run_1:
    ; Check if countdown 0 - Race - Track open.
    sbrs    rTransfer, flProgStartLights
    rjmp    FSM_20State10Chaos_1Run_2
    mov     rAccu, rTransfer
    andi    rAccu, mskProgValues            ; Mask values
    cpi     rAccu, 0x00                     ; All LED off
    brne    FSM_20State10Chaos_1Run_2
    ldi     rScratch, fsmState6Grn

FSM_20State10Chaos_1Run_2:
    ; Check if countdown 1 - start countdown.
    cpi     rAccu, 0x01                     ; 1 LED on
    brne    FSM_20State10Chaos_1Run_3
    ldi     rScratch, fsmState1Red1

FSM_20State10Chaos_1Run_3:
    ; Check if reset.
    sbrc    rTransfer, flProgReset
    ldi     rScratch, fsmState0Init

FSM_20State10Chaos_1Run_9:
    ; If a new state is set, exit the current state.
    mov     rFsmNextState, rScratch
    cp      rFsmCurrentState, rFsmNextState
    brne    FSM_20State10Chaos_9Exit
    rjmp    FSM_99Exit

FSM_20State10Chaos_9Exit:
    ; Out startlights.
    ldi     rAccu, (1<<ioLEDred1) | (1<<ioLEDred2) | (1<<ioLEDred3) | (1<<ioLEDred4) | (1<<ioLEDred5)
    com     rAccu
    and     rBlinkMask, rAccu
    out     ioLEDport, rAccu
    ; Jump to new state entry.
    rjmp    FSM_98ChangeState

    ; ==========================================================================

    ; --------------------------------------------------------------------------
    ; FSM Change state / Next state.
    ; --------------------------------------------------------------------------
FSM_98ChangeState:
    ; Jump to next state.
    ldi     ZH, HIGH (FSM_adrStateEntry)    ; Load jumptable address...
    ldi     ZL, LOW (FSM_adrStateEntry)     ; ...to pointer.
    add     ZL, rFsmNextState               ; Add state offset
    clr     rAccu
    adc     ZH, rAccu                       ; Consider carryflag
    ijmp                                    ; Jump to new state entry

    ; --------------------------------------------------------------------------
    ; FSM Exit.
    ; --------------------------------------------------------------------------
FSM_99Exit:

    ; Restore SREG and registers from STACK.
    pop     rAccu
    out     SREG, rAccu
    pop     rAccu
    pop     rScratch
    pop     ZH
    pop     ZL

    ; All done! Return.
    ret

    ; --------------------------------------------------------------------------
    ; FSM jump table - entry state.
    ; --------------------------------------------------------------------------
FSM_adrStateEntry:
    rjmp    FSM_10State0Init_0Entry
    rjmp    FSM_11State1Red1_0Entry
    rjmp    FSM_12State2Red2_0Entry
    rjmp    FSM_13State3Red3_0Entry
    rjmp    FSM_14State4Red4_0Entry
    rjmp    FSM_15State5Red5_0Entry
    rjmp    FSM_16State6Grn_0Entry
    rjmp    FSM_17State7Yel1_0Entry
    rjmp    FSM_18State8Yel2_0Entry
    rjmp    FSM_19State9RFin_0Entry
    rjmp    FSM_20State10Chaos_0Entry

    ; --------------------------------------------------------------------------
    ; FSM jump table - running state.
    ; --------------------------------------------------------------------------
FSM_adrStateRun:
    rjmp    FSM_10State0Init_1Run
    rjmp    FSM_11State1Red1_1Run
    rjmp    FSM_12State2Red2_1Run
    rjmp    FSM_13State3Red3_1Run
    rjmp    FSM_14State4Red4_1Run
    rjmp    FSM_15State5Red5_1Run
    rjmp    FSM_16State6Grn_1Run
    rjmp    FSM_17State7Yel1_1Run
    rjmp    FSM_18State8Yel2_1Run
    rjmp    FSM_19State9RFin_1Run
    rjmp    FSM_20State10Chaos_1Run