; ==============================================================================
;  INCLUDE TITLE   : Manchester Decoder for Carrera Digital 124/132
;  INCLUDE TYPE    : - DEKLARATIONS    X CODE
; ==============================================================================
;  FILE            : decoder.asm
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
;  - decoder.inc
;
;  Register:
;  - rAccu (>=R16)
;  - rScratch (>=R16)
;  - rTransfer (No new data=cleared, new data available=set)
;  - rTimeElapsedCnt(>=R16)
;  - rReceivedByteH:rReceivedByteL (>=R3+1:>=R3)
;  - rReceivedBitCnt (>=R3)
;  - rReceivedPacketCnt (>=R3)
;
;  SRAM:
;  - SRAM_DataPackets (44 Bytes)
;
;  I/O:
;  - PIND2 for external interrupt INT0
;    - ioCMCpin=PIND
;    - ioCMCsignal=PIND2
;    + ioCMCsignal=PIND2 configured as input
;
; ==============================================================================
;  DESCRIPTION:
;
;  The control unit (CU) of the carrera digital 124/132 racetrack communicates
;  with the slotcars, sensors and actuators in the manchester code.
;  This is modulated to the driving voltage. During transmission the driving
;  voltage is pulled to ground according to the manchester coding.
;
;  The clock rate is 100us (=10kHz). A new CU datapacket is sent every 7.5ms.
;  The complete protocol sequence takes 75ms.
;
;  The CU sends a total of the following 10 datapackets of different length
;  in the same order. Each datapacket has a start bit but no stop bit.
;
;  Datapacket table:
; ----------------
;
;       Nr. |  Length |  Label (datapacket)
;      ------------------------------------------
;       1   |     12  |  Prog data / CU data
;       2   |      9  |  Pace-/Ghostcar
;       3   | 7 or 8  |  Active- or acknowledge (*)
;       4   |      9  |  Controller0 (*)
;       5   |      9  |  Controller4 (*)
;       6   |      9  |  Controller1 (*)
;       7   |      9  |  Controller5 (*)
;       8   |      9  |  Controller2 (*)
;       9   |      7  |  Active (*)
;      10   |      9  |  Controller3 (*)
;      ------------------------------------------
;
;  After the CU has sent the datapackets marked with (*), the slotcars and
;  sensors can send data to the CU. For this purpose, after 2.304ms
;  according to the datapacket the CU pulling the driving voltage for 50us
;  to ground and is starting to receiving data.
;  The exact communication between sensors and CU is not discussed here.
;  When decoding, however, it should be noted that this communication also
;  triggers the external interrupt.
;
;  In this case we are only interested in the program- and ghostcar-datapacket.
;
;  Structure of program datapacket (12 Bits):
;  ---------------------------------------------
;
;      Bits (3)  9 - 11:   Controller (0-5: slotcar / 7: controll unit)
;      Bits (5)  4 -  8:   Instruction
;      Bits (4)  0 -  3:   Value
;
;      !! ATTENTION !!
;      The CU is sending the least significant bit (LSB) of the controller datapacket
;      first. Due to the left shift (lsl) in the following decoder routine
;      of the received bits, the bits are in reverse order in memory.
;
;      However, this is a big advantage because it results in a separation of the
;      <instruction> in the low byte and the <value> in the high byte.
;      If the MSB were sent first, the <instruction> would be separated in 2 bytes.
;
;  Instruction table:
;  ------------------
;
;      Ctrl. | Instr. | Val.  | Description
;      ------------------------------------------------------------------------
;       0-5  |    0   |  0-15 | Prog. velocity value <Val.> to slotcar <ctrl.>
;       0-5  |    1   |  0-15 | Program brake value <Val.> to slotcar <ctrl.>
;       0-5  |    2   |  0-15 | Program fuel maximum <Val.> to slotcar <ctrl.>
;       0-5  |    4   |     0 | Race - NO pitlane - no fuel consumption (=0)
;       0-5  |    4   |  0- 7 | Race - WITH pitlane - fuel remaining = <Val.>
;       0-5  |    4   |     8 | Early start of slotcar <controller>
;            |        |       |   - NO pitlane - no fuel consumption (=8)
;       0-5  |    4   |  8-15 | Early Start of slotcar <controller>
;            |        |       |   - WITH pitlane - fuel remaining = <val.>-8
;       0-7  |    5   |     0 | Slotcar <ctrl.> leaves refueling mode
;       0-7  |    5   |     1 | Slotcar <ctrl.> goes to the refueling mode
;       0-7  |    6   |  1- 8 | Position slotcar <ctrl.> is <val.>
;         0  |    6   |     9 | Reset position and lap counter
;       0-7  |    7   |     1 | Slotcar <ctrl.> finish the race
;       0-7  |    8   |     1 | Slotcar <ctrl.> finish lap with best time
;       0-7  |    9   |     1 | Slotcar <ctrl.> finish lap without best time
;       0-5  |   10   |  0- 7 | Fuel level <val.> of slotcar <ctrl.>
;         0  |   10   |    15 | Switch off fuel gauge on the drivers display
;         4  |   10   |    15 | Reset (first prog. data packet)
;       0-5  |   11   |     1 | Early start of slotcar <controller>
;         7  |   16   |  0- 5 | LEDs (0-5) on (control unit and start lights)
;         7  |   17   |  0-15 | High nibble of the lap counter of the leader
;         7  |   18   |  0-15 | Low nibble of the lap counter of the leader
;         7  |   19   |     0 | Reset
;         7  |   20   |  1- 4 | Pitlane/checkline mode <val.>
;            |        |       |   1=off, 2=finish line,
;            |        |       |   3=meantime 1, 4=meantime 2
;         7  |   20   |    15 | Check if pitlane is installed
;         7  |   21   |  0- 1 | Performance meassurement mode (<val.>
;            |        |       |   1=on, 2=off).
;      ------------------------------------------------------------------------
;
;  Structure of pacecar-datapacket (8 bits):
;  ---------------------------------------
;      Bit   6 - 8:   Controller (always 7: control unit)
;      Bit       5:   Track closed (1=closed, 0=open)
;      Bit       4:   Toggle
;      Bit       3:   Track open (1=open, 1=closed)
;      Bit       2:   Recall pacecar
;      Bit       1:   Pacecar active (1=active, 0=inactive)
;      Bit       0:   Fuel consumption active
;
;      !! ATTENTION !!
;      The CU is sending the most significant bit (MSB) of the pacecar
;      datapacket at first. This is contrary to the program datapacket!
;
; ==============================================================================
;
;   Further information to decode carrera manchester code:
;   - http://slotbaer.de/
;   - http://slotbaer.de/Carrera-digital-124-132/9-cu-daten-protokoll.html
;
;   General information about manchester coding with AVR microcontrollers:
;   - Atmel APPLICATION NOTE - Manchester Coding Basics
;   - https://ww1.microchip.com/downloads/en/Appnotes/Atmel-9164-Manchester-Coding-Basics_Application-Note.pdf
;
; ==============================================================================

; ==============================================================================
;  SUB PROGRAMS
; ==============================================================================

sub_DECODER_TIMER0isr:
    ; --------------------------------------------------------------------------
    ;  TIMER0
    ;
    ;  The TIMER0 is triggered every 10us and increments a counter.
    ;  Within the ISR INT0, the elapsed time between the edge changes of the
    ;  carrera manchester code can be measured by reading the counter value.
    ; --------------------------------------------------------------------------

    ; Save SREG and registers to STACK.
    push    rAccu
    in      rAccu, SREG
    push    rAccu

    ; Stop external interrupt to avoid disturbing this interrupt.
    mac_DECODER_INT0stop

    ; Preload counter for new interval.
    ldi     rAccu, cfgTIMER0_TCNT0
    out     TCNT0, rAccu

    ; Increment time elapsed counter.
    ; Counts every 10us --> Value 10 equals 100us (10kHz).
    inc     rTimeElapsedCnt

    ; If time elapsed >130us (> 5/4T [125us]),
    ; then last bit of datapacket is received.
    ; If condition occurs due to an overflow but no data is received,
    ; it can be detected by observing the length of the received bits.
    cpi     rTimeElapsedCnt, 14
    brlo    DECODER_TIMER0isr_Exit

    sbr     rDecoderState, (1<<flTransmComplete)    ; Inform that transmission
                                                    ; is completed. New datapacket
                                                    ; is available to check.

    ; End of frame. Stop time elapsed timer
    mac_DECODER_TIMER0stop

DECODER_TIMER0isr_Exit:
    ; Restart stopped external interrupt.
    mac_DECODER_INT0start

    ; Restore SREG and registers from STACK.
    pop     rAccu
    out     SREG, rAccu
    pop     rAccu

    ; All done! --> Return from interrupt
    reti

sub_DECODER_INT0isr:
; ------------------------------------------------------------------------------
;  EXTERNAL INTERRUPT INT0
;
;  The interrupt is triggered every edge changes of the Carrera Manchester code.
;  Together with the counter from TIMER0, the Carrera Manchester code will be
;  decoded and the received bits are stored in two receive registers.
; ------------------------------------------------------------------------------
    ; Save SREG and registers to STACK.
    push    rScratch
    push    rAccu
    in      rAccu, SREG
    push    rAccu

    ; Prevent own call during processing.
    mac_DECODER_INT0stop


DECODER_INT0isr_10CheckTimer:
    ; If timer is running then check time elapsed between the previous edge change.
    ; Else there may start a new data frame.
    in      rAccu, TIMSK                    ; Read current state
    sbrc    rAccu, TOIE0                    ; If timer is running...
    rjmp    DECODER_INT0isr_11CheckNewBit   ; ... check for new bit.

    ; New data frame starts.
    ; Start timer to  measure the elapsed time between the edge changes.
    ;mac_DECODER_TIMER0init
    mac_DECODER_TIMER0start

    ; Clear memory to receive new datapacket.
    clr     rReceivedByteL
    clr     rReceivedByteH
    clr     rReceivedBitCnt

    ; Exit Interrupt
    rjmp DECODER_INT0isr_19CheckExit

DECODER_INT0isr_11CheckNewBit:
    ; Check if edge change is in the Carrera Manchester clock (10kHz).
    ; If time elapsed > 80us and < 120us then we are receiving a new bit.

DECODER_INT0isr_12Check80us:
    ; Time elapsed >80us (> 3/4T [75us])?
    ; -> true: check next.
    ; -> false: nothing to do -> exit ISR.
    cpi      rTimeElapsedCnt, 8
    brlo    DECODER_INT0isr_19CheckExit

DECODER_INT0isr_13Check120us:
    ; Time elapsed <120us (< 5/4T [125us])?
    ; -> true: get new bit.
    ; -> false: check next.
    cpi      rTimeElapsedCnt, 12
    brlo    DECODER_INT0isr_20GetNewBit

DECODER_INT0isr_19CheckExit:
    ; Nothing to do at this point --> exit ISR.
    rjmp    DECODER_INT0isr_99Exit

DECODER_INT0isr_20GetNewBit:
    ; Get new bit.

    ; Clear time elapsed counter to check next edge change.
    clr     rTimeElapsedCnt

    ; Add received bit.
    lsl     rReceivedByteL
    rol     rReceivedByteH
    ldi     rAccu, 0b00000001
    sbis    ioCMCpin, ioCMCsignal
    or      rReceivedByteL, rAccu

    ; Increment received bit counter.
    inc     rReceivedBitCnt

    ; * * * * * D E B U G * * * * *
    ; Send received Manchester clock * 2 (200us, 5kHz) to debug pin.
    ldi     rScratch, 1 << ioDEBUGyellow
    in      rAccu, ioDEBUGport
    eor     rAccu, rScratch
    out     ioDEBUGport, rAccu
    ; * * * * * D E B U G * * * * *

    ; * * * * * D E B U G * * * * *
    ; Send received data to debug pin.
    sbic    ioCMCpin, ioCMCsignal
    sbi     ioDEBUGport, ioDEBUGred
    sbis    ioCMCpin, ioCMCsignal
    cbi     ioDEBUGport, ioDEBUGred
    ; * * * * * D E B U G * * * * *

DECODER_INT0isr_99Exit:
    ; Restart stopped external interrupt INT0.
    mac_DECODER_INT0start

    ; Restore SREG and registers from STACK.
    pop     rAccu
    out     SREG, rAccu
    pop     rAccu
    pop     rScratch

    ; All done! --> Return from interrupt.
    reti

sub_DECODER_SaveData:
; ------------------------------------------------------------------------------
;  SAVE NEW DATAPACKET
;
;  Check received datapacket and save it to SRAM.
; ------------------------------------------------------------------------------
    ; Save SREG and registers to STACK.
    push    ZL
    push    ZH
    push    rScratch
    push    rAccu
    in      rAccu, SREG
    push    rAccu

    ; Clear data evaluated flag.
    cbr     rDecoderState, (1<<flDataEvaluated)

DECODER_SaveData_11Check1:
    ; Check if a valid datapacket (minimum 7bit) was received.
    mov     rAccu, rReceivedBitCnt
    subi    rAccu, 7
    brcs    DECODER_SaveData_19Exit

DECODER_SaveData_12Check2:
    ; Check if it is a programm datapacket (= first datapacket).
    ; Only the programming datapacket has a length of 12Bits.
    ldi     rAccu, flProgDpLength
    cp      rReceivedBitCnt, rAccu
    brne    DECODER_SaveData_13Save

    ; Reset datapacket counter to first datapacket (=0).
    clr     rReceivedPacketCnt

DECODER_SaveData_13Save:
    ; Save datapacket to SRAM.

    ; Set pointer to SRAM address.
    ldi     ZL, LOW (SRAM_DataPackets)
    ldi     ZH, HIGH (SRAM_DataPackets)

    ; Move pointer by datapacket counter.
    mov     rAccu, rReceivedPacketCnt         ; For 4-byte data array...
    lsl     rAccu                           ; ...multiply packet counter with 4
    lsl     rAccu                           ; ...by shifting two times left
    add     ZL, rAccu                       ; Add datapacket offset to pointer
    clr     rAccu                           ; ...set rAccu to zero and
    adc     ZH, rAccu                       ; ...consider carryflag

    ; Save datapacket to SRAM.
    st      Z+, rReceivedPacketCnt
    st      Z+, rReceivedBitCnt
    st      Z+, rReceivedByteL
    st      Z, rReceivedByteH

    ; Set data evaluated flag to inform the main loop
    ; that there is new data in SRAM.
    sbr     rDecoderState, (1<<flDataEvaluated)

    ; If the packet counter unexpectedly reaches the value 11,
    ; then do not further count up. 10 datapackets are normal.
    ; 11 datapackets for debugging allowed.
    ; Reset occurs when program datapackets is recognized. See above.
    ldi     rAccu, 11
    cp      rReceivedBitCnt, rAccu
    breq    DECODER_SaveData_19Exit

    ; Increment datapackets counter by 1.
    inc     rReceivedPacketCnt

DECODER_SaveData_19Exit:
    ; Clear received bit counter (=0).
    clr     rReceivedByteL
    clr     rReceivedByteH
    clr     rReceivedBitCnt

    ; Restore SREG and registers from STACK.
    pop     rAccu
    out     SREG, rAccu
    pop     rAccu
    pop     rScratch
    pop     ZH
    pop     ZL

    ; All done! --> Return from interrupt.
    reti

sub_DECODER_CheckData:
; ------------------------------------------------------------------------------
;  DATAPACKET CHECK ROUTINE
;
;  Check the received datapackets for relevant information, extract it and
;  return the results in the rTransfer register.
; ------------------------------------------------------------------------------
    ; Save SREG and registers from STACK.
    push    ZL
    push    ZH
    push    rScratch
    push    rAccu
    in      rAccu, SREG
    push    rAccu

    ; Set pointer to received datapacket.
    ldi     ZL, LOW (SRAM_DataPackets)
    ldi     ZH, HIGH (SRAM_DataPackets)

    ; Clear transfer register for new results.
    clr     rTransfer

    ; Check if saved program datapacket has the correct length.
    ldd     rAccu, Z + (pStartProgCU + pOffsetDpCnt)
    cpi     rAccu, flProgDpLength
    breq    DECODER_CheckData_10Reset
    rjmp    DECODER_CheckData_50PaceCar

DECODER_CheckData_10Reset:
    ; --------------------------------------------------------------------------
    ; Check for reset.
    ; Reset 1: Controller=7, instruction=19, value=0.
    ; --------------------------------------------------------------------------
DECODER_CheckData_11Reset1:
    ; Check if reset 1 - condition 1.
    ldd     rAccu, Z + (pStartProgCU + pOffsetDpLow)
    cpi     rAccu, 0b11001111            ; Instruction=19 and controller=7?
    brne    DECODER_CheckData_19Reset_Exit

    ; Check if reset 1 - condition 2.
    ldd     rAccu, Z + (pStartProgCU + pOffsetDpHigh)
    andi    rAccu, 0b00001111            ; Check value
    tst     rAccu                        ; value=0?
    brne    DECODER_CheckData_19Reset_Exit

    ; Set reset flag.
    sbr     rTransfer, (1<<flProgReset)

    ; Set Debug LED
    sbi     ioDEBUGport, ioDEBUGred

    ; Check with results -> exit CheckData.
    rjmp    DECODER_CheckData_99Exit

DECODER_CheckData_19Reset_Exit:

DECODER_CheckData_20StartLight:
    ; --------------------------------------------------------------------------
    ; Check for start lights
    ; Instruction = 16, value=<LED>, controller=7.
    ; --------------------------------------------------------------------------
    ; Load and check controller and instruction.
    ldd     rAccu, Z + (pStartProgCU + pOffsetDpLow)
    cpi     rAccu, 0b00001111               ; Controller=7, instruction=16
    brne    DECODER_CheckData_29StartLight_Exit

    ; Load values.
    ldd     rScratch, Z + (pStartProgCU + pOffsetDpHigh)
    andi    rScratch, 0x0F                  ; Filter start light value

    ; Rotate value bits. LSB -> MSB
    clr     rAccu
    ror     rScratch                        ; Bit 3
    rol     rAccu
    ror     rScratch                        ; Bit 2
    rol     rAccu
    ror     rScratch                        ; Bit 1
    rol     rAccu
    ror     rScratch                        ; Bit 0
    rol     rAccu

    ; Shrink value.
    andi    rAccu, mskProgValues

    ; Set start light flag.
    sbr     rAccu, (1<<flProgStartLights)

    ; Copy the results into the transfer register.
    mov     rTransfer, rAccu

    ; Check with results -> exit CheckData.
    rjmp    DECODER_CheckData_99Exit

DECODER_CheckData_29StartLight_Exit:

DECODER_CheckData_30RaceFinished:
    ; --------------------------------------------------------------------------
    ; Check if race has been finished.
    ; Instruction = 7, value=1, controller=<No. slotcar that wins the race>.
    ; --------------------------------------------------------------------------

    ; Load datapacket and check instruction.
    ldd     rAccu, Z + (pStartProgCU + pOffsetDpLow)
    mov     rScratch, rAccu                 ; Save for later use
    andi    rAccu, 0b11111000               ; Mask instruction bits
    cpi     rAccu, 0b11100000               ; Check if race finished
    brne    DECODER_CheckData_39RaceFinished_Exit

    ; Load prog. datapacket and check value as a second condition.
    ldd     rAccu, Z + (pStartProgCU + pOffsetDpHigh)
    andi    rAccu, 0b00001111               ; Mask value bits
    cpi     rAccu, 0b00001000               ; Check if value=1
    brne    DECODER_CheckData_39RaceFinished_Exit

    ; Rotate controller bits. LSB -> MSB
    clr     rAccu
    ror     rScratch                        ; Bit 2
    rol     rAccu
    ror     rScratch                        ; Bit 1
    rol     rAccu
    ror     rScratch                        ; Bit 0
    rol     rAccu

    ; Shrink value.
    andi    rAccu, mskProgValues

    ; Set early start flag.
    sbr     rAccu, (1<<flProgFinished)

    ; Copy the results into the transfer register.
    mov     rTransfer, rAccu

    ; Check with results -> exit CheckData.
    rjmp    DECODER_CheckData_99Exit

DECODER_CheckData_39RaceFinished_Exit:

DECODER_CheckData_40EarlyStart:
    ; --------------------------------------------------------------------------
    ; Check for early start.
    ; Instruction = 11, value=1, controller=<No. slotcar done a early start>.
    ; --------------------------------------------------------------------------

    ; Load datapacket and check instruction.
    ldd     rAccu, Z + (pStartProgCU + pOffsetDpLow)
    mov     rScratch, rAccu                 ; Save for later use
    andi    rAccu, 0b11111000               ; Mask instruction bits
    cpi     rAccu, 0b11010000               ; Check if its early start (11)
    brne    DECODER_CheckData_49EarlyStart_Exit

    ; Load prog. datapacket and check value as a second condition.
    ldd     rAccu, Z + (pStartProgCU + pOffsetDpHigh)
    andi    rAccu, 0b00001111               ; Mask value bits
    cpi     rAccu, 0b00001000               ; Check if value=1
    brne    DECODER_CheckData_49EarlyStart_Exit

    ; Rotate controller bits. LSB --> MSB.
    clr     rAccu
    ror     rScratch                        ; Bit 2
    rol     rAccu
    ror     rScratch                        ; Bit 1
    rol     rAccu
    ror     rScratch                        ; Bit 0
    rol     rAccu

    ; Shrink value.
    andi    rAccu, mskProgValues

    ; Set early start flag.
    sbr     rAccu, (1<<flProgEarlyStart)

    ; Copy the results into the transfer register.
    mov     rTransfer, rAccu

    ; Check with results -> exit CheckData.
    rjmp    DECODER_CheckData_99Exit

DECODER_CheckData_49EarlyStart_Exit:

DECODER_CheckData_50PaceCar:
    ; --------------------------------------------------------------------------
    ; Check pacecar.
    ; Following bits are set in PaceGhostCar-datapacket: 0b1|11xxxx1x.
    ; --------------------------------------------------------------------------
    ; Check if saved pacecar datapacket has the correct length.
    ldd     rAccu, Z + (pStartPGC + pOffsetDpCnt)
    cpi     rAccu, flPgcDpLength
    brne    DECODER_CheckData_59PaceCar_Exit

    ; Load pace car datapacket and check instruction.
    ldd     rAccu, Z + (pStartPGC + pOffsetDpLow)
    ldd     rScratch, Z + (pStartPGC + pOffsetDpHigh)

    ; Shift all bits one position to left (no attention to fuel indicator).
    lsr     rScratch
    ror     rAccu

    ; Check if pace/ghostcar instruction.
    mov     rScratch, rAccu                 ; Save datapacket for later use
    andi    rScratch, 0b11100000            ; Mask pacecar instruction
    cpi     rScratch, 0b11100000            ; Check instruction
    brne    DECODER_CheckData_59PaceCar_Exit

    ; Get pacecar values.
    andi    rAccu, 0b00000011               ; Mask pacecar value bits

    ; Set pacecar flag.
    sbr     rAccu, (1<<flProgPaceCar)

    ; Copy the results into the transfer register.
    mov     rTransfer, rAccu

    ; Check with results -> exit CheckData.
    rjmp    DECODER_CheckData_99Exit

DECODER_CheckData_59PaceCar_Exit:

DECODER_CheckData_99Exit:
    ; Restore SREG and registers from STACK.
    pop     rAccu
    out     SREG, rAccu
    pop     rAccu
    pop     rScratch
    pop     ZH
    pop     ZL

    ; All done! --> Return from interrupt.
    ret
