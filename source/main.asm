

ORG 0000H
    LJMP SETUP

; MEMORY MAP 
; 30H to 38H = Board State (0=Empty, 1=X, 2=O)
; 41H = Current Player (1=X, 2=O)
; 43H = Player 1 Score
; 44H = Player 2 Score
; 45H = Turn Counter (0-9)

SETUP:
    MOV P0, #0FFH       
    MOV P1, #0FFH 
    
    SETB P3.7           ; Pull-up for the AI Switch
    CLR P3.6            ; SAFETY: Ensure LCD Enable is LOW
          
    MOV 43H, #0         ; Init P1 Score
    MOV 44H, #0         ; Init P2 Score
    ACALL LCD_INIT
    LJMP ROUND_RESET

; MAIN GAME LOOP (THE DIRECTOR)
MAIN_LOOP:
    MOV A, 41H
    CJNE A, #2, HUMAN_TURN  ; If it's P1 (X), it's always human
    
    ; It's Player 2 (O)'s turn. Check the switch!
    JB P3.7, HUMAN_TURN     ; Switch OPEN = PvP Mode. Go to keypad.
    
    ; this switches to ai mode 
    ACALL AI_THINK
    SJMP MAIN_LOOP

HUMAN_TURN:
    ACALL SCAN_KEYPAD
    SJMP MAIN_LOOP

; stupid ai engine 
AI_THINK:
    ; 1. Show "Thinking" UI
    MOV A, #0D4H
    ACALL LCD_CMD
    MOV DPTR, #STR_AI_THINK
    ACALL RS_PRINT
    ACALL LONG_DELAY        ; Fake pause

    ; PRIORITY 1: CENTER
    MOV A, 34H
    JZ AI_TAKE_CEN

    ; PRIORITY 2: CORNERS
    MOV A, 30H
    JZ AI_TAKE_TL
    MOV A, 32H
    JZ AI_TAKE_TR
    MOV A, 36H
    JZ AI_TAKE_BL
    MOV A, 38H
    JZ AI_TAKE_BR

    ; PRIORITY 3: EDGES
    MOV A, 31H
    JZ AI_TAKE_TM
    MOV A, 33H
    JZ AI_TAKE_ML
    MOV A, 35H
    JZ AI_TAKE_MR
    MOV A, 37H
    JZ AI_TAKE_BM
    RET

; AI Execution Routing
AI_TAKE_CEN: 
    MOV R0, #34H
    SJMP AI_EXECUTE
AI_TAKE_TL:  
    MOV R0, #30H
    SJMP AI_EXECUTE
AI_TAKE_TR:  
    MOV R0, #32H
    SJMP AI_EXECUTE
AI_TAKE_BL:  
    MOV R0, #36H
    SJMP AI_EXECUTE
AI_TAKE_BR:  
    MOV R0, #38H
    SJMP AI_EXECUTE
AI_TAKE_TM:  
    MOV R0, #31H
    SJMP AI_EXECUTE
AI_TAKE_ML:  
    MOV R0, #33H
    SJMP AI_EXECUTE
AI_TAKE_MR:  
    MOV R0, #35H
    SJMP AI_EXECUTE
AI_TAKE_BM:  
    MOV R0, #37H
    SJMP AI_EXECUTE

AI_EXECUTE:
    MOV @R0, #2         ; Claim spot for Player 2
    INC 45H             ; Turn Count++
    ACALL RENDER_BOARD  ; Update LCD
    ACALL CHECK_WIN     ; Check if bot won
    MOV 41H, #1         ; Pass turn back to Player 1
    ACALL RENDER_STATUS
    RET

; BACKEND KEYPAD SCANNER
SCAN_KEYPAD:
    ; --- ROW 0 ---
    MOV P1, #11111110B
    JB P0.0, K_R0_C1
    MOV R0, #30H        
    LJMP PROCESS_PRESS
K_R0_C1:
    JB P0.1, K_R0_C2
    MOV R0, #31H
    LJMP PROCESS_PRESS
K_R0_C2:
    JB P0.2, K_R1_C0
    MOV R0, #32H
    LJMP PROCESS_PRESS

    ; --- ROW 1 ---
K_R1_C0:
    MOV P1, #11111101B
    JB P0.0, K_R1_C1
    MOV R0, #33H
    LJMP PROCESS_PRESS
K_R1_C1:
    JB P0.1, K_R1_C2
    MOV R0, #34H
    LJMP PROCESS_PRESS
K_R1_C2:
    JB P0.2, K_R2_C0
    MOV R0, #35H
    LJMP PROCESS_PRESS

    ; --- ROW 2 ---
K_R2_C0:
    MOV P1, #11111011B
    JB P0.0, K_R2_C1
    MOV R0, #36H
    LJMP PROCESS_PRESS
K_R2_C1:
    JB P0.1, K_R2_C2
    MOV R0, #37H
    LJMP PROCESS_PRESS
K_R2_C2:
    JB P0.2, SCAN_END
    MOV R0, #38H
    LJMP PROCESS_PRESS
SCAN_END:
    RET

; BACKEND: MOVE VALIDATION & STATE
PROCESS_PRESS:
    MOV A, @R0
    JZ DO_MOVE          ; If spot is 0, it's a valid move
    LJMP WRONG_MOVE     

DO_MOVE:
    MOV A, 41H          
    MOV @R0, A          ; Claim the spot
    INC 45H             ; Increase turn count
    
    ACALL RENDER_BOARD  ; Update screen immediately so they see the move
    ACALL CHECK_WIN     ; Did this move win the game?

    ; Swap Player
    MOV A, 41H
    XRL A, #03H         
    MOV 41H, A          
    ACALL RENDER_STATUS
    LJMP WAIT_RELEASE

WRONG_MOVE:
    MOV A, #0D4H        ; Jump to Row 4
    ACALL LCD_CMD
    MOV DPTR, #STR_TAKEN
    ACALL RS_PRINT
    ACALL LONG_DELAY    ; Pause 
    ACALL RENDER_STATUS ; Put the normal text back
    LJMP WAIT_RELEASE

WAIT_RELEASE:
    MOV A, P0
    CPL A
    ANL A, #00000111B
    JNZ WAIT_RELEASE    
    RET

; ALGORITHM: WIN DETECTION (BRUTE FORCE)
CHECK_WIN:
    ; Horizontal 1
    MOV A, 30H
    JZ CHK_H2
    CJNE A, 31H, CHK_H2
    CJNE A, 32H, CHK_H2
    LJMP DO_WIN
CHK_H2:
    MOV A, 33H
    JZ CHK_H3
    CJNE A, 34H, CHK_H3
    CJNE A, 35H, CHK_H3
    LJMP DO_WIN
CHK_H3:
    MOV A, 36H
    JZ CHK_V1
    CJNE A, 37H, CHK_V1
    CJNE A, 38H, CHK_V1
    LJMP DO_WIN
CHK_V1:
    MOV A, 30H
    JZ CHK_V2
    CJNE A, 33H, CHK_V2
    CJNE A, 36H, CHK_V2
    LJMP DO_WIN
CHK_V2:
    MOV A, 31H
    JZ CHK_V3
    CJNE A, 34H, CHK_V3
    CJNE A, 37H, CHK_V3
    LJMP DO_WIN
CHK_V3:
    MOV A, 32H
    JZ CHK_D1
    CJNE A, 35H, CHK_D1
    CJNE A, 38H, CHK_D1
    LJMP DO_WIN
CHK_D1:
    MOV A, 30H
    JZ CHK_D2
    CJNE A, 34H, CHK_D2
    CJNE A, 38H, CHK_D2
    LJMP DO_WIN
CHK_D2:
    MOV A, 32H
    JZ CHK_DRAW
    CJNE A, 34H, CHK_DRAW
    CJNE A, 36H, CHK_DRAW
    LJMP DO_WIN

CHK_DRAW:
    MOV A, 45H          ; Get Turn Count
    CJNE A, #09H, NO_WIN
    ; IT'S A DRAW!
    MOV A, #0D4H
    ACALL LCD_CMD
    MOV DPTR, #STR_DRAW
    ACALL RS_PRINT
    ACALL LONG_DELAY
    ACALL LONG_DELAY
    LJMP ROUND_RESET
NO_WIN:
    RET

DO_WIN:
    ; Whoever's turn it currently is (41H) is the winner!
    MOV A, 41H
    CJNE A, #1, P2_WINS
P1_WINS:
    INC 43H             ; P1 Score++
    MOV DPTR, #STR_WIN1
    SJMP SHOW_WIN
P2_WINS:
    INC 44H             ; P2 Score++
    JB P3.7, UI_WIN_P2  ;check switch 
    MOV DPTR, #STR_WIN_AI
    SJMP SHOW_WIN
UI_WIN_P2:
    MOV DPTR, #STR_WIN2
SHOW_WIN:
    MOV A, #0D4H        
    ACALL LCD_CMD
    ACALL RS_PRINT      ; Print Win Message
    ACALL UPDATE_SCORES ; Refresh the scoreboard!
    ACALL LONG_DELAY
    ACALL LONG_DELAY    ; 
    LJMP ROUND_RESET

; SYSTEM: ROUND RESET ENGINE
ROUND_RESET:
    MOV SP, #07H        ;flash everything
    MOV R0, #30H
    MOV R1, #09H
CLR_RAM:
    MOV @R0, #00H       ; Wipe board RAM
    INC R0
    DJNZ R1, CLR_RAM
    
    MOV 45H, #0         ; Reset turn count
    MOV 41H, #1         ; Player 1 always starts new round
    ACALL DRAW_BASE_UI  ; Redraw empty board
    ACALL RENDER_STATUS
    
    LJMP MAIN_LOOP      ; 

; FRONTEND: DYNAMIC RENDERING
RENDER_BOARD:
    MOV R1, #0          
    MOV R0, #30H        
RB_LOOP:
    MOV A, R1
    MOV DPTR, #LCD_ADDRS
    MOVC A, @A+DPTR     
    ACALL LCD_CMD       
    MOV A, @R0          
    CJNE A, #1, RB_CHK2
    MOV A, #'X'         
    SJMP RB_PRINT
RB_CHK2:
    CJNE A, #2, RB_EMPTY
    MOV A, #'O'         
    SJMP RB_PRINT
RB_EMPTY:
    MOV A, #'-'         
RB_PRINT:
    ACALL LCD_DATA      
    INC R0              
    INC R1              
    CJNE R1, #09H, RB_LOOP
    RET

RENDER_STATUS:
    MOV A, #0D4H        
    ACALL LCD_CMD
    MOV A, 41H
    CJNE A, #1, RS_P2
    MOV DPTR, #STR_P1   
    SJMP RS_PRINT
RS_P2:
    JB P3.7, RS_HUMAN_P2 ; If Switch is OPEN, print human P2
    MOV DPTR, #STR_AI    ; If Switch is CLOSED, print AI Bot
    SJMP RS_PRINT
RS_HUMAN_P2:
    MOV DPTR, #STR_P2   
RS_PRINT:
    CLR A
    MOVC A, @A+DPTR
    JZ RS_END
    ACALL LCD_DATA
    INC DPTR
    SJMP RS_PRINT
RS_END:
    RET

UPDATE_SCORES:
    MOV A, #83H         ; LCD Address for P1 Score
    ACALL LCD_CMD
    MOV A, 43H          
    ADD A, #'0'         ; Convert raw number to ASCII
    ACALL LCD_DATA

    MOV A, #93H         ; LCD Address for P2 Score
    ACALL LCD_CMD
    MOV A, 44H          
    ADD A, #'0'         
    ACALL LCD_DATA
    RET

DRAW_BASE_UI:
    MOV A, #80H
    ACALL LCD_CMD
    
    ;  Conditional Row 1 Rendering 
    JB P3.7, UI_PVP_R1
    MOV DPTR, #STR_R1_AI
    SJMP UI_PRINT_R1
UI_PVP_R1:
    MOV DPTR, #STR_R1
UI_PRINT_R1:
    ACALL RS_PRINT
    

    MOV A, #0C0H
    ACALL LCD_CMD
    MOV DPTR, #STR_R2
    ACALL RS_PRINT
    MOV A, #94H
    ACALL LCD_CMD
    MOV DPTR, #STR_R3
    ACALL RS_PRINT
    ACALL UPDATE_SCORES 
    RET

; LCD DRIVERS & DELAYS
LCD_INIT:
    MOV A, #38H         
    ACALL LCD_CMD
    MOV A, #0CH         
    ACALL LCD_CMD
    MOV A, #01H         
    ACALL LCD_CMD
    MOV A, #06H         
    ACALL LCD_CMD
    RET

LCD_CMD:
    MOV P2, A           
    CLR P3.5            
    SETB P3.6           
    ACALL DELAY         
    CLR P3.6            
    RET

LCD_DATA:
    MOV P2, A           
    SETB P3.5           
    SETB P3.6           
    ACALL DELAY
    CLR P3.6            
    RET

DELAY:
    MOV R6, #50
D1: MOV R7, #255
D2: DJNZ R7, D2
    DJNZ R6, D1
    RET

LONG_DELAY:
    MOV R5, #15         ; Multiplier for a ~1 second pause
LD0:MOV R6, #255
LD1:MOV R7, #255
LD2:DJNZ R7, LD2
    DJNZ R6, LD1
    DJNZ R5, LD0
    RET

; FRONTEND DATABASE (STRINGS)
STR_R1:       DB 'P1:0  - | - | - P2:0', 0
STR_R1_AI:    DB 'P1:0  - | - | - AI:0', 0  ; 
STR_R2:       DB '      - | - | -     ', 0
STR_R3:       DB '      - | - | -     ', 0
STR_P1:       DB '  PLAYER 1 (X) TURN ', 0
STR_P2:       DB '  PLAYER 2 (O) TURN ', 0
STR_AI:       DB '  AI BOT (O) TURN   ', 0
STR_WIN1:     DB ' *** P1 (X) WINS ***', 0
STR_WIN2:     DB ' *** P2 (O) WINS ***', 0
STR_WIN_AI:   DB '  AI WINS  ', 0  ; 
STR_DRAW:     DB '   *** DRAW! *** ', 0
STR_TAKEN:    DB ' !! SPOT TAKEN !!   ', 0
STR_AI_THINK: DB ' AI IS THINKING...  ', 0

LCD_ADDRS: DB 86H, 8AH, 8EH, 0C6H, 0CAH, 0CEH, 9AH, 9EH, 0A2H

END
