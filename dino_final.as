;=================================================================
; CONSTANTS
;-----------------------------------------------------------------
; text window
TERM_READ       EQU     FFFFh
TERM_WRITE      EQU     FFFEh
TERM_STATUS     EQU     FFFDh
TERM_CURSOR     EQU     FFFCh
TERM_COLOR      EQU     FFFBh
; 7 segment display
DISP7_D0        EQU     FFF0h
DISP7_D1        EQU     FFF1h
DISP7_D2        EQU     FFF2h
DISP7_D3        EQU     FFF3h
DISP7_D4        EQU     FFEEh
DISP7_D5        EQU     FFEFh
; stack
SP_INIT         EQU     6000h
; timer
TIMER_CONTROL   EQU     FFF7h
TIMER_COUNTER   EQU     FFF6h
TIMER_SETSTART  EQU     1
TIMER_SETSTOP   EQU     0
TIMERCOUNT_INIT EQU     1
; Switches
SWITCHES        EQU     FFF9h
; interruptions
INT_MASK        EQU     FFFAh
INT_MASK_VAL    EQU     8009h ; 1000 0000 0000 1001 b
; terreno
LINHA_TERRENO   EQU     2100h
N_CHARS_TERRENO EQU     960 ; 12 linhas de 80 caracteres = 960
TERRENO_CHAR    EQU     DBh
; cato
CATO_CHAR       EQU     D7h
; tabela e dimensões
DIM             EQU     80
ALTURA_MAX      EQU     8d
POS_CAT_TAB     EQU     7 ; posição na tabela da altura do cato na primeira
                          ; coluna onde está o dino
; dino
DINO_CURSOR_BASE        EQU 2007h
; salto
SALTO_MAX       EQU     12d
SALTO_SUBIR     EQU     1
SALTO_DESCER    EQU     2
SALTO_VEL       EQU     200h ; múltiplo de SALT_MAX(0A00h) e de 100h
END_GAME_WAIT_TIME      EQU 30 ; tempo de espera no final do jogo para
                               ; recomeçar o próximo
DINO_COLOR      EQU     0073h 
CATO_COLOR      EQU     000Ch
TERRENO_COLOR   EQU     00F5h 
;=================================================================
; Program global variables
;-----------------------------------------------------------------
                ORIG    0
; vars do temporizador
TIMER_COUNTVAL  WORD    TIMERCOUNT_INIT ; states the current counting period
TIMER_TICK      WORD    0               ; indicates the number of unattended
                                        ; timer interruptions
TIME            WORD    0               ; time elapsed
; seed
X               WORD    5
; vars do dino
DINO_CURSOR_ATUAL   WORD DINO_CURSOR_BASE
; dino char
DINO_CHAR_SLEEP STR     C0h, FBh, FBh, D9h, 0, ' ', 16h, 16h, 0, ' ', 5Fh, 5Fh, 'z', 0, '    z', 1
DINO_CHAR1      STR     C0h, C0h, 0, FBh, ' ', FBh, 0, 09h, 09h, 0, A9h, AAh, 1
DINO_CHAR2      STR     DAh, ' ', C0h, 0, FBh, ' ', FBh, 0, 09h, 09h, 0, A9h, AAh, 1
DINO_CHAR3      STR     C0h, C0h, 0, ' ', FBh, 0, 09h, 09h, 0, A9h, AAh, 1
DINO_CHAR4      STR     DAh, ' ', C0h, 0, ' ', FBh, 0, 09h, 09h, 0, A9h, AAh, 1
DINO_CHAR_SALTO STR     DAh, DAh, 0, ' ', FBh, FBh, 0, 09h, 09h, 0, A9h, AAh, 0, ' ', 13h, 1
; 0 indica o final de cada linha de caracteres e 1 indica o fim dos caracteres
; da personagem
DINO_CHAR_STAT  WORD    0
DINO_CHAR       TAB     20
; START vars
START_BUTTON    WORD    0
IS_GAME_OVER    WORD    1
SCORE           WORD    0
START_STR       STR     'PRESS 0 TO START', 0
GAME_OVER_STR   STR     'G A M E  O V E R', 0
THREE_DOTS      STR     ' . . .', 0
; score vars
DISP7_ADDR      STR     DISP7_D0,DISP7_D1,DISP7_D2,DISP7_D3,DISP7_D4,DISP7_D5,0
; outras vars do programa
ATUALIZACOES    WORD    0 ; +1 cada 0.1s, -1 sempre que o ecrã for atualizado
SENTIDO_SALTO   WORD    1 ; 1 = subida, 2 = descida
SALTO_EVENTO    WORD    0
IS_COL_DINO     WORD    0

                ORIG    2000h
TERRENO         TAB     80             
                
;=================================================================
; MAIN: the starting point of the program
;-----------------------------------------------------------------
                ORIG    0
MAIN:           MVI     R6, SP_INIT
                ; CONFIGURE TIMER ROUNTINES
                ; interrupt mask
                MVI     R1, INT_MASK
                MVI     R2, INT_MASK_VAL
                STOR    M[R1], R2
                ; enable interruptions
                ENI
                
                MVI     R1, TERM_WRITE
                MVI     R2, TERM_CURSOR
                MVI     R3, 1520h
                MVI     R4, START_STR
.WRITE:         STOR    M[R2], R3
                LOAD    R5, M[R4]
                CMP     R5, R0
                BR.Z    .SLEEP
                STOR    M[R1], R5
                INC     R4
                INC     R3
                BR      .WRITE
                ; WRITE GROUND AND SLEEPING DINO
.SLEEP:         JAL     ESCREVER_TERRENO
                JAL     ATUALIZA_DINO_CHAR
                MVI     R1, DINO_CURSOR_ATUAL        
                LOAD    R1, M[R1]
                MVI     R2, DINO_CHAR
                JAL     ESCREVER_DINO
                ; CHANGE VAR IS_GAME_OVER TO FALSE(0)
                MVI     R1, IS_GAME_OVER
                STOR    M[R1], R0
                ; WAIT FOR 0 TO BE PRESSED
.WAIT:          MVI     R1, START_BUTTON
                LOAD    R1, M[R1]
                CMP     R1, R0
                BR.Z    .WAIT
.START:         ; CLEAR SCREEN
                MVI     R2, TERM_CURSOR
                MVI     R3, FFFFh
                STOR    M[R2], R3
                JAL     ESCREVER_TERRENO
                ; START TIMER
                MVI     R2, TIMERCOUNT_INIT
                MVI     R1, TIMER_COUNTER
                STOR    M[R1], R2          ; set timer
                MVI     R1, TIMER_TICK
                STOR    M[R1], R0          ; clear all timer ticks
                MVI     R1, TIMER_CONTROL
                MVI     R2, TIMER_SETSTART
                STOR    M[R1], R2          ; start timer
                
                ; WAIT FOR EVENT (TIMER/KEY)
                MVI     R4, TERM_STATUS
                MVI     R5, TIMER_TICK
.LOOP:          ; SAVE RETURN ADDRESS
                DEC     R6
                STOR    M[R6], R7
                ; KEY:
                LOAD    R1, M[R4]
                CMP     R1, R0
                JAL.NZ  PROCESS_KEY
                ; TIMER:
                LOAD    R1, M[R5]
                CMP     R1, R0
                JAL.NZ  PROCESS_TIMER_EVENT
                ; LOAD RETURN ADDRESS
                LOAD    R7, M[R6]
                INC     R6
                ; CHECK IF GAME IS OVER
                MVI     R2, IS_GAME_OVER
                LOAD    R1, M[R2]
                CMP     R1, R0
                BR.Z    .UPDATE
                ; IF GAME IS OVER, GO BACK TO 
                JMP     R7
.UPDATE:        ; VERIFY IF THERE WERE ANY UPDATES:
                MVI     R2, ATUALIZACOES
                LOAD    R1, M[R2]
                DEC     R6
                STOR    M[R6], R7
                CMP     R1, R0
                JAL.P   ATUALIZA
                LOAD    R7, M[R6]
                INC     R6
                
                BR      .LOOP
                
;===========================================================================
; ATUALIZA: atualiza o ecrã
; ARGUMENTOS: 
; R1 -> valor que indica se há atualizações a fazer
; R2 -> endereço da variável que indica se há atualizações pendentes
;---------------------------------------------------------------------------
ATUALIZA:       DEC     R6
                STOR    M[R6], R7
                ; SAVE CONTEXT
                DEC     R6
                STOR    M[R6], R4
                DEC     R6
                STOR    M[R6], R5
                ; Decrementar 1 à variável de controlo das atualizações
                DEC     R1
                STOR    M[R2], R1
                ; CALL FUNCTIONS
                ; set arguments to call ATUALIZAJOGO
                MVI     R1, TERRENO
                MVI     R2, DIM
                JAL     ATUALIZAJOGO
                ; set arguments to call ESCREVER_CATOS
                MVI     R1, TERRENO
                MVI     R2, LINHA_TERRENO
                MVI     R3, 100h
                SUB     R2, R2, R3
                JAL     ESCREVER_CATOS
                ; call ATUALIZA_DINO_CHAR
                JAL     ATUALIZA_DINO_CHAR
                ; set arguments to call ESCREVE_DINO
                MVI     R1, DINO_CURSOR_ATUAL        
                LOAD    R1, M[R1]
                MVI     R2, DINO_CHAR
                JAL     ESCREVER_DINO
                ; call SALTAR_MOV
                JAL     SALTAR_MOV
                ; set arguments to call CHECK
                MVI     R1, DINO_CURSOR_ATUAL
                LOAD    R1, M[R1]
                MVI     R2, TERRENO
                MVI     R3, POS_CAT_TAB
                ADD     R2, R2, R3
                ; CHECK colunas do dino -> ocupa 3 colunas logo 3 CHECKS  
                ; CHANGE VAR IS_COL_DINO TO TRUE(1)
                MVI     R3, IS_COL_DINO
                MVI     R4, 1
                STOR    M[R3], R4
                JAL     CHECK
                INC     R2
                JAL     CHECK
                INC     R2
                JAL     CHECK
                ; CHECK coluna depois do dino 
                ; CHANGE VAR IS_COL_DINO TO FALSE(0)
                MVI     R3, IS_COL_DINO
                STOR    M[R3], R0
                INC     R2
                JAL     CHECK
                ; UPDATE SCORE / ADD POINTS
                MVI     R2, SCORE
                LOAD    R1, M[R2]
                INC     R1
                STOR    M[R2], R1
                ; WRITE SCORE ON THE DISPLAY
                JAL     WRITE_SCORE
                ; RESTORE CONTEXT
                LOAD    R5, M[R6]
                INC     R6
                LOAD    R4, M[R6]
                INC     R6
                LOAD    R7, M[R6]
                INC     R6
                JMP     R7

;===========================================================================
; ESCREVER_TERRENO: escreve 12 linhas de 80 caracteres, o solo, sem catos. 
; O caracter escolhido por nós foi um bloco que está definido nas variáveis 
; em TERRENO_CHAR e a posicao da linha superior do solo
;---------------------------------------------------------------------------
ESCREVER_TERRENO:
                ; CHANGE COLOR TO BROWN
                MVI     R1, TERM_COLOR
                MVI     R2, TERRENO_COLOR
                STOR    M[R1], R2
                ; POSICIONAR CURSOR
                MVI     R1, TERM_WRITE
                MVI     R2, TERM_CURSOR
                MVI 	R3, LINHA_TERRENO
                STOR 	M[R2], R3
                
                MVI     R2, N_CHARS_TERRENO
                MVI 	R3, TERRENO_CHAR
.ESCREVER_CHAR:
                STOR 	M[R1], R3
                ; VERIFICAR SE TODOS OS CARACTERES FORAM ESCRITOS
                DEC     R2
                CMP     R2, R0
                BR.NZ   .ESCREVER_CHAR
                
                JMP     R7

;==========================================================================
; ATUALIZA_DINO_CHAR: altera o string que representa o dino
;--------------------------------------------------------------------------
ATUALIZA_DINO_CHAR:
                MVI     R1, DINO_CHAR
                ; IF GAME IS OVER OR HASN'T STARTED 
                ; 0 -> false / 1 -> true
                MVI     R2, IS_GAME_OVER
                LOAD    R2, M[R2]
                CMP     R2, R0 
                BR.NZ   .SLEEP
                ; IF MID JUMP
                MVI     R2, SALTO_EVENTO
                LOAD    R2, M[R2]
                CMP     R2, R0
                BR.NZ   .SALTO
                ; THE FOLLOWING INTERCHANGE IN A CICLE TO ALLOW THE ANIMATION EFFECT
                MVI     R4, DINO_CHAR_STAT
                LOAD    R5, M[R4]
                CMP     R5, R0
                BR.Z    .CHAR1
                MVI     R2, 1
                CMP     R5, R2
                BR.Z    .CHAR2
                INC     R2
                CMP     R5, R2
                BR.Z    .CHAR3
                STOR    M[R4], R0
                MVI     R2, DINO_CHAR4
                BR      .LOOP
.CHAR1:         INC     R5
                STOR    M[R4], R5
                MVI     R2, DINO_CHAR1
                BR      .LOOP
.CHAR2:         INC     R5
                STOR    M[R4], R5
                MVI     R2, DINO_CHAR2
                BR      .LOOP
.CHAR3:         INC     R5
                STOR    M[R4], R5
                MVI     R2, DINO_CHAR3
                BR      .LOOP
.SLEEP:         MVI     R2, DINO_CHAR_SLEEP
                BR      .LOOP
.SALTO:         MVI     R2, DINO_CHAR_SALTO
.LOOP:          ; REPLACING PREVIOUS DINO_CHAR CHARACTERS WITH THE NEW ONES
                LOAD    R4, M[R2]
                STOR    M[R1], R4
                INC     R1
                INC     R2
                MVI     R5, 1
                CMP     R4, R5
                BR.NZ   .LOOP
                JMP     R7

;==========================================================================
; ESCREVER_DINO
; ARGUMENTOS: R1 -> posição do dino no ecrã
;             R2 -> o string de caracteres do dino
;--------------------------------------------------------------------------                
ESCREVER_DINO:  ; SAVE CONTEXT
                DEC     R6 
                STOR    M[R6], R4 
                DEC     R6 
                STOR    M[R6], R5
                ; CHANGE COLOR TO DINO_COLOR
                MVI     R5, TERM_COLOR
                MVI     R4, DINO_COLOR
                STOR    M[R5], R4
                ; WRITE DINO
.MAIN_LOOP:     MVI     R4, TERM_CURSOR
                STOR    M[R4], R1 
.LOOP:          LOAD    R5, M[R2]
                MVI     R3, 1
                CMP     R5, R3
                BR.Z    .RETURN
                CMP     R5, R0
                BR.NZ   .CONT
                ; CHANGE LINE
                MVI     R3, 100h
                SUB     R1, R1, R3
                INC     R2
                BR      .MAIN_LOOP
.CONT:          MVI     R3, TERM_WRITE
                STOR    M[R3], R5
                INC     R2
                BR      .LOOP
                ; RESTORE CONTEXT
.RETURN:        LOAD    R5, M[R6]
                INC     R6
                LOAD    R4, M[R6]
                INC     R6 
                JMP     R7

;====================================================================
; ATUALIZAJOGO: atualizar a tabela de alturas
; ARGUMENTOS: R1 -> TERRENO
;             R2 -> DIM
;--------------------------------------------------------------------                
ATUALIZAJOGO:   ; OBTER ENDEREÇO FINAL DA TABELA
                DEC     R2
                ADD     R2, R1, R2
                
.LOOP:          INC     R1
                LOAD    R4, M[R1]
                DEC     R1
                STOR    M[R1], R4
                INC     R1
                CMP     R1, R2
                BR.NZ   .LOOP
                
.RETURN:        DEC     R6 ; PUSH return address
                STOR    M[R6], R7 ; PUSH cont'd
                
                DEC     R6 ; PUSH function parameter
                STOR    M[R6], R1 ; PUSH cont'd
                MVI     R1, ALTURA_MAX ; R1 = altura maxima 
                JAL     GERACACTO
                LOAD    R1, M[R6] ; POP function parameter
                INC     R6 ; POP cont'd
                
                LOAD    R7, M[R6] ; POP return address
                INC     R6 ; POP cont'd
                
                STOR    M[R1], R3
                
                JMP     R7
                
;====================================================================                
; GERACACTO: gera um valor pseudo aleatório
; ARGUMENTO: R1 -> ALTURA_MAX
; RETORNO: R3 -> altura entre 0 e ALTURA_MAX
;--------------------------------------------------------------------                
GERACACTO:      ; SAVE CONTEXT
                DEC     R6 
                STOR    M[R6], R4 
                DEC     R6 
                STOR    M[R6], R5 
                
                MVI     R4, X
                LOAD    R4, M[R4]
                MVI     R5, 1
                
                AND     R5, R4, R5 ; R5 = bit
                SHR     R4 ; Shift para a direita
                
                DEC     R6 ; PUSH aux var
                STOR    M[R6], R5 ; PUSH cont'd
                MVI     R5, X
                STOR    M[R5], R4 ; atualizar a variavel x
                LOAD    R5, M[R6] ; POP aux var
                INC     R6 ; POP cont'd
                
                CMP     R5, R0
                BR.Z    .NOT_XOR ; if bit == 0
                ; FAZER XOR:
                MVI     R5, b400h
                XOR     R5, R4, R5
                
                MVI     R4, X
                STOR    M[R4], R5 ; atualizar a variavel x
                LOAD    R4, M[R4]
.NOT_XOR:       MVI     R5, 62258d
                CMP     R5, R4
                BR.NC   .RETURN_ZERO ; if x < 62258
                
                DEC     R1 ; altura - 1
                AND     R3, R4, R1 ; x AND (altura - 1)
                INC     R3 ; (x AND (altura - 1)) + 1
                ; RESTORE CONTEXT
                LOAD    R5, M[R6] 
                INC     R6 
                LOAD    R4, M[R6] 
                INC     R6 
               
                JMP     R7
                
.RETURN_ZERO:   MOV     R3, R0
                ; RESTORE CONTEXT
                LOAD    R5, M[R6] 
                INC     R6 
                LOAD    R4, M[R6]
                INC     R6 
                
                JMP     R7

;=====================================================================
; ESCREVER_CATOS: Escreve os 80 catos (ou nao catos) em loop,
; pixel a pixel utilizando a função auxiliar ESCREVER_CATO
; ARGUMENTOS: R1 -> TERRENO
;             R2 -> cursor
;---------------------------------------------------------------------
ESCREVER_CATOS: ; SAVE CONTEXT
                DEC     R6
                STOR    M[R6], R4
                DEC     R6
                STOR    M[R6], R5
                ; CHANGE COLOR TO CATO_COLOR
                MVI     R5, TERM_COLOR
                MVI     R4, CATO_COLOR
                STOR    M[R5], R4
                
                MVI     R4, DIM ; serve como contador
.LOOP:          ; SAVE TAB & CURSOR POSITION
                DEC     R6
                STOR    M[R6], R1
                DEC     R6
                STOR    M[R6], R2
                ; CALL FUNCTION
                LOAD    R1, M[R1]
                DEC     R6
                STOR    M[R6], R7
                JAL     ESCREVER_CATO
                LOAD    R7, M[R6]
                INC     R6
                ; LOAD TAB & CURSOR POSITION
                LOAD    R2, M[R6]
                INC     R6
                LOAD    R1, M[R6]
                INC     R6
                ; PRÓXIMO CATO
                INC     R1 ; passar à próxima posição da tabela
                INC     R2 ; mover o cursor
                DEC     R4 ; contador = contador - 1
                CMP     R4, R0
                BR.NZ   .LOOP
                ; CHANGE COLOR BACK TO WHITE
                MVI     R5, TERM_COLOR
                MVI     R4, 00FFh
                STOR    M[R5], R4
                ; LOAD CONTEXT
                LOAD    R5, M[R6]
                INC     R6
                LOAD    R4, M[R6]
                INC     R6
                JMP     R7

;=====================================================================
; ESCREVER_CATO: função que apaga a coluna até à altura máxima, para 
; no caso de haver um cato já no ecrã nessa coluna, e escreve um cato 
; com a altura passada por argumento
; ARGUMENTOS: R1 -> altura do cato
;             R2 -> cursor
;---------------------------------------------------------------------
ESCREVER_CATO:  ; SAVE CONTEXT
                DEC     R6
                STOR    M[R6], R5
                DEC     R6
                STOR    M[R6], R4
                ; SAVE FUNCTION ARGUMENTS
                DEC     R6
                STOR    M[R6], R1 ; altura do cato
                DEC     R6
                STOR    M[R6], R2 ; cursor cato
                ; APAGAR A COLUNA
                MVI     R1, ALTURA_MAX
                ; for i in range(altura_max)
.LOOP_APAGAR:   CMP     R1, R0 
                BR.Z    .ESCREVER_BARRA
                ; R2 <= Cursor Cato atual
                ; INSERT VALUE
                MVI     R4, TERM_CURSOR
                STOR    M[R4], R2
                MVI     R4, TERM_WRITE
                MVI     R5, ' '
                STOR    M[R4],R5
                ; MOVE CURSOR
                MVI     R4, 0100h
                SUB     R2, R2, R4
                DEC     R1
                BR      .LOOP_APAGAR
.ESCREVER_BARRA:; LOAD FUNCTION ARGUMENTS
                LOAD    R2, M[R6] ; cursor cato
                INC     R6
                LOAD    R1, M[R6] ; altura do cato
                INC     R6
.LOOP:          CMP     R1, R0 
                BR.Z    .RETURN
                ; ATUALIZAR CURSOR POSITION
                MVI     R4, TERM_CURSOR
                STOR    M[R4], R2
                ; INSERT VALUE
                MVI     R4, TERM_WRITE
                MVI     R5, CATO_CHAR
                STOR    M[R4], R5
                ; MOVE CURSOR
                MVI     R4, 0100h
                SUB     R2, R2, R4
                DEC     R1
                BR      .LOOP
.RETURN:        ; LOAD CONTEXT
                LOAD    R4, M[R6]
                INC     R6
                LOAD    R5, M[R6]
                INC     R6
                JMP     R7
;==========================================================================
; WRITE_SCORE: escreve o score no display em decimal
; ARGUMENTO: R1 -> SCORE
;--------------------------------------------------------------------------
WRITE_SCORE:    ; SAVE CONTEXT
                DEC     R6
                STOR    M[R6], R4
                MVI     R4, DISP7_ADDR
                ; SHOW TIME ON DISP7
.LOOP_WRITE_DISPS:
                ; SAVE RETURN ADDRESS
                DEC     R6
                STOR    M[R6], R7
                JAL     RESTO_DIV10
                ; LOAD RETURN ADDRESS
                LOAD    R7, M[R6]
                INC     R6
                LOAD    R2, M[R4]
                ; VERIFICAR SE JÁ SE ESCREVEU EM TODOS OS DISPLAYS
                CMP     R2, R0
                BR.Z    .RETURN
                ; ESCREVER O RESTO DA DIVISÃO POR 10
                STOR    M[R2], R3
                INC     R4
                ; PRÓXIMO DISP COM R1 = R1//10
                BR      .LOOP_WRITE_DISPS
.RETURN:        ; RESTORE CONTEXT
                LOAD    R4, M[R6]
                INC     R6
                JMP     R7
                
;=============================================================================
; RESTO_DIV10: recebe um valor em decimal, retorna o resto da sua divisão por
; 10 e transforma-o no resultado dessa divisão inteira
; ARGUMENTO: R1 -> um valor em decimal
; RETORNO: R3 -> o resto da divisão de R1 por 10
;-----------------------------------------------------------------------------
RESTO_DIV10:    ; SAVE CONTEXT
                DEC     R6
                STOR    M[R6], R4
                MVI     R2, 10d
                MOV     R3, R1  ; R3 = ARGUMENTO(R1) de modo ao retorno (o resto)
                                ; resultante de sucessivas subtrações por 10
                                ; estar em R3
                MOV     R1, R0  ; R1 -> contador que no final terá o valo de 
                                ; R1 = R1(argumento)//10
.LOOP:          MOV     R4, R3
                SUB     R4, R4, R2 ; R4 -> valor hipotético de que resultaria
                                   ; de subtrair 10 a R3
                CMP     R4, R0     ; se R4 < 0 não realizar a subtração R3=R3-10
                BR.N    .RETURN    ; e terminar o ciclo
                SUB     R3, R3, R2
                INC     R1
                BR      .LOOP
                ; LOAD CONTEXT
.RETURN:        LOAD    R4, M[R6]
                INC     R6
                JMP     R7

;===========================================================================
; APAGAR_DINO: função parecida ao ESCREVER_DINO mas apaga em vez de escrever
; ARGUMENTOS: R1 -> posição do dino no ecrã
;             R2 -> o string de caracteres do dino
;---------------------------------------------------------------------------             
APAGAR_DINO:    ; SAVE CONTEXT
                DEC     R6 
                STOR    M[R6], R4 
                DEC     R6 
                STOR    M[R6], R5
                ; SAVE PREVIOUS RETURN ADDRESS
                DEC     R6
                STOR    M[R6], R7
.MAIN_LOOP:     MVI     R4, TERM_CURSOR
                STOR    M[R4], R1 
.LOOP:          LOAD    R5, M[R2]
                MVI     R3, 1
                CMP     R5, R3
                BR.Z    .RETURN
                CMP     R5, R0
                BR.NZ   .CONT
                ; CHANGE LINE
                MVI     R3, 100h
                SUB     R1, R1, R3
                INC     R2
                BR      .MAIN_LOOP
.CONT:          MVI     R3, TERM_WRITE
                MVI     R5, ' '
                STOR    M[R3], R5
                INC     R2
                BR      .LOOP
.RETURN:        LOAD    R7, M[R6]
                INC     R6
                ; LOAD CONTEXT
                LOAD    R4, M[R6]
                INC     R6
                LOAD    R5, M[R6]
                INC     R6
                JMP     R7
                
;==============================================================================
; SALTAR_MOV: função que faz o dinossauro andar um número linhas definido
; por SALTO_VEL para cima ou para baixo, dependendo se está a subir ou a descer
;------------------------------------------------------------------------------
SALTAR_MOV:     ; SAVE RETURN ADDRESS
                DEC     R6
                STOR    M[R6], R7
                ; VERIFICAR SE FOI PREMIDA A SETA PARA CIMA
                MVI     R1, SALTO_EVENTO
                LOAD    R1, M[R1]
                CMP     R1, R0
                BR.Z    .RETURN
                ; APAGAR DINO DA POSIÇÃO ATUAL
                ; SAVE R1
                DEC     R6
                STOR    M[R6], R1
                MVI     R1, DINO_CURSOR_ATUAL        
                LOAD    R1, M[R1]
                MVI     R2, DINO_CHAR
                JAL     APAGAR_DINO
                ; LOAD R1
                LOAD    R7, M[R6]
                INC     R6
                ; ver se o salto está a subir ou a decrescer
                MVI     R2, SENTIDO_SALTO; = 1 (subida), = 2 (descida)
                LOAD    R1, M[R2]
                ; salto a subir?
                MVI     R2, SALTO_SUBIR
                CMP     R1, R2
                BR.Z    .SUBIR
                ; salto a descer?
                MVI     R2, SALTO_DESCER
                CMP     R1, R2
                BR.Z    .DESCER
                BR      .RETURN
.SUBIR:         ; increase ao cursor
                MVI     R4, DINO_CURSOR_ATUAL
                LOAD    R1, M[R4]
                MVI     R2, SALTO_VEL
                SUB     R1, R1, R2
                STOR    M[R4], R1
                ; escrever o dinosauro
                MVI     R1, DINO_CURSOR_ATUAL        
                LOAD    R1, M[R1]
                MVI     R2, DINO_CHAR
                JAL     ESCREVER_DINO
                ; verificar se estamos na altura maxima
                MVI     R1, SALTO_MAX
                ; shifts da altura máxima pois temos
                ; de subtrair R1 numero de linhas
                ; 000Ah -> 0A00h
                SHL     R1
                SHL     R1
                SHL     R1
                SHL     R1
                SHL     R1
                SHL     R1
                SHL     R1
                SHL     R1
                ; verificar se o cursor está na posicao max
                MVI     R2, DINO_CURSOR_BASE
                SUB     R2, R2, R1 ; posicao cursor da altura max
                MVI     R4, DINO_CURSOR_ATUAL
                LOAD    R4, M[R4]
                CMP     R4, R2
                BR.NZ   .RETURN
                ; se chegar à posição máxima, mudar o sentido
                MVI     R2, SENTIDO_SALTO
                MVI     R1, SALTO_DESCER
                STOR    M[R2], R1
                BR      .RETURN
.DESCER:        ; obter posicao dinossauro atual
                MVI     R4, DINO_CURSOR_ATUAL
                LOAD    R1, M[R4]
                ; posicao = posicao - 1 linha
                MVI     R2, SALTO_VEL
                ADD     R1, R1, R2
                STOR    M[R4], R1
                ; escrever dino
                MVI     R1, DINO_CURSOR_ATUAL        
                LOAD    R1, M[R1]
                MVI     R2, DINO_CHAR
                JAL     ESCREVER_DINO
                ; verificar se estamos na altura minima = cursor base do dino
                MVI     R1, DINO_CURSOR_BASE
                MVI     R4, DINO_CURSOR_ATUAL
                LOAD    R2, M[R4]
                CMP     R2, R1
                BR.NZ   .RETURN
                ; se chegar à posição minima, acabou o salto
                ; Pôr variável de controlo SALTO_EVENTO = 0
                MVI     R2, SALTO_EVENTO
                STOR    M[R2], R0
                ; Pôr var SENTIDO_SALTO = 1 (sentido crescente)
                MVI     R2, SENTIDO_SALTO
                MVI     R1, SALTO_SUBIR
                STOR    M[R2], R1               
.RETURN:        ; LOAD RETURN ADDRESS
                LOAD    R7, M[R6]
                INC     R6

                JMP     R7
                
;===========================================================================
; CHECK: verifica se há um cato nas posições adjacentes ao dino e se houver
; termina o jogo
; Por exemplo se o dino estiver diretamente por cima do cato
; ou ao lado do mesmo, sendo assim, a forma como esta avaliação é feita 
; depende de se o cato está numa coluna do dino ou não (IS_COL_DINO)
; De qualquer modo, de forma a ser possível fazer a comparação, nesta função
; vê-se os valores como se estivessem na mesmo coluna, comparando-se apenas
; as linhas a que pertencem
; ARGUMENTOS: R1 -> a posição do dino atual
;             R2 -> endereço onde ler altura do terreno/cato a avaliar
;---------------------------------------------------------------------------
CHECK:          LOAD    R3, M[R2] ; R3 -> altura do cato/terreno
                CMP     R3, R0
                BR.Z    .RETURN
                MVI     R4, DINO_CURSOR_BASE
                MVI     R5, 100h
                DEC     R3
                ; for i in range(altura-1):
.LOOP:          SUB     R4, R4, R5   
                DEC     R3
                CMP     R3, R0
                BR.NZ   .LOOP     ; R4 -> posição do topo do cato
                ; A COLUNA A SER AVALIADA É A DO DINO?
                MVI     R3, IS_COL_DINO
                LOAD    R3, M[R3]
                CMP     R3, R0
                BR.Z    .NOT_COL_DINO
                SUB     R4, R4, R5; R4 -> posição acima do topo do cato
.NOT_COL_DINO:  ; SAVE RETURN ADDRESS
                DEC     R6
                STOR    M[R6], R7
                CMP     R1, R4
                JAL.NN  GAME_OVER
                ; LOAD RETURN ADDRESS
                LOAD    R7, M[R6]
                INC     R6     
.RETURN:        JMP     R7

;=============================================================================
; GAME_OVER: escreve 'GAME OVER', faz reset a todas as variáveis necessárias,
; limpa a tabela de alturas, espera um intervalo de tempo e depois reinicia
; o jogo
;-----------------------------------------------------------------------------
GAME_OVER:      ; SET COLOR TO WHITE
                MVI     R2, TERM_COLOR
                MVI     R1, 00FFh
                STOR    M[R2], R1
                MVI     R1, TERM_WRITE
                MVI     R2, TERM_CURSOR
                MVI     R3, 151eh
                MVI     R4, GAME_OVER_STR
                ; WRITE GAME OVER
.WRITE:         STOR    M[R2], R3
                LOAD    R5, M[R4]
                CMP     R5, R0
                BR.Z    .WRITE_3_DOTS
                STOR    M[R1], R5
                INC     R4
                INC     R3
                BR      .WRITE
.WRITE_3_DOTS:  ; R1 <- TERM_WRITE & R2 <- TERM_CURSOR
                ; WRITE THREE DOTS
                MVI     R4, THREE_DOTS
.WRITE_3_DOTS_LOOP:  
                STOR    M[R2], R3
                LOAD    R5, M[R4]
                CMP     R5, R0
                BR.Z    .CONTINUE
                STOR    M[R1], R5
                INC     R4
                INC     R3
                BR      .WRITE_3_DOTS_LOOP
.CONTINUE:      ; CHANGE VAR IS_GAME_OVER TO TRUE(1)
                MVI     R2, IS_GAME_OVER
                MVI     R1, 1
                STOR    M[R2], R1
                ; AFTER WRITING, WAIT 3 SECONDS = 30 DEC DE SEC
                MVI     R2, TIME
                LOAD    R1, M[R2]
                MVI     R3, END_GAME_WAIT_TIME
                ADD     R1, R1, R3
                MVI     R5, TIMER_TICK
                MVI     R4, TERM_WRITE
.WAIT_LOOP:     MVI     R2, TIME
                LOAD    R2, M[R2] ; TEMPO ATUAL
                CMP     R1, R2
                BR.NP   .STOP_TIMER
                ; SAVE CONTEXT - R1 & R2
                DEC     R6
                STOR    M[R6],R1
                DEC     R6
                STOR    M[R6],R2
                JAL     MAIN.LOOP
                ; LOAD CONTEXT - R1 & R2
                LOAD    R2, M[R6]
                INC     R6
                LOAD    R1, M[R6]
                INC     R6
                ; PUSH R1
                DEC     R6
                STOR    M[R6], R1
                ; DECIMAS DE SEGUNDO LEFT
                SUB     R1, R1, R2
                JAL     RESTO_DIV10 ; R1 = R1 //10
                ; SET TERM CURSOR
                MVI     R4, TERM_CURSOR
                MVI     R2, 1535h
                STOR    M[R4], R2
                ; CONVERT R1 TO CHAR
                MVI     R3, '0'
                ADD     R3, R3, R1
                ; aumentar os segundos em 1, como fazemos  divisão inteira
                ; faz aparecer 3, 2, 1 em vez de 2, 1, 0
                INC     R3
                MVI     R4, TERM_WRITE
                STOR    M[R4], R3
                
                ; POP R1
                LOAD    R1, M[R6]
                INC     R6
                BR      .WAIT_LOOP
                ; STOP TIMER
.STOP_TIMER:    DSI
                MVI     R1, TIMER_CONTROL
                MVI     R2, TIMER_SETSTOP
                STOR    M[R1], R2
                ; CLEAR SCREEN
                MVI     R2, TERM_CURSOR
                MVI     R3, FFFFh
                STOR    M[R2], R3
                ; CLEAR TABLE
                MVI     R1, TERRENO
                MVI     R2, DIM
.CLEAR:         STOR    M[R1], R0
                INC     R1
                DEC     R2
                CMP     R2, R0
                BR.NZ   .CLEAR
                ; CHANGE START_BUTTON STATUS TO OFF(0)
                MVI     R1, START_BUTTON
                STOR    M[R1], R0
                ; CHANGE VAR SALTO_EVENTO TO FALSE(0)
                MVI     R1, SALTO_EVENTO
                STOR    M[R1], R0
                ; CHANGE SENTIDO_SALTO TO SALTO_SUBIR
                MVI     R1, SENTIDO_SALTO
                MVI     R2, SALTO_SUBIR
                STOR    M[R1], R2
                ; CHANGE VAR DINO_CURSOR_ATUAL TO DINO_CURSOR_BASE
                MVI     R1, DINO_CURSOR_ATUAL
                MVI     R2, DINO_CURSOR_BASE
                STOR    M[R1], R2
                ; CLEAR SCORE
                MVI     R1, SCORE
                STOR    M[R1], R0
                ; SET TIME TO 0
                MVI     R1, TIME
                STOR    M[R1], R0
                ; SET ATUALIZACOES TO 0
                MVI     R1, ATUALIZACOES
                STOR    M[R1], R0
                JAL     MAIN

;==========================================================================
; PROCESS_KEY: verifica se a tecla premida no teclado foi a seta para cima
;--------------------------------------------------------------------------
PROCESS_KEY:    MVI     R1, TERM_READ
                LOAD    R2, M[R1]
                ; tecla premida no teclado foi a seta para cima?
                MVI     R1, 18h
                CMP     R2, R1
                BR.NZ   .RETURN
                ; CHANGE VAR SALTO_EVENTO TO 1
                MVI     R2, SALTO_EVENTO
                MVI     R1, 1
                STOR    M[R2], R1

.RETURN:        JMP     R7

;=================================================================
; PROCESS_TIMER_EVENT: processes events from the timer
;-----------------------------------------------------------------
PROCESS_TIMER_EVENT:
                ; DEC TIMER_TICK
                MVI     R2, TIMER_TICK
                DSI    
                LOAD    R1, M[R2]
                DEC     R1
                STOR    M[R2], R1
                ENI
                ; UPDATE TIME
                MVI     R1, TIME
                LOAD    R2, M[R1]
                INC     R2
                STOR    M[R1], R2
                ; INC UPDATE CONTROL VAR
                MVI     R2, ATUALIZACOES
                LOAD    R1, M[R2]
                INC     R1
                STOR    M[R2], R1
                JMP     R7

;*****************************************************************
; AUXILIARY INTERRUPT SERVICE ROUTINES
;*****************************************************************
AUX_TIMER_ISR:  ; SAVE CONTEXT
                DEC     R6
                STOR    M[R6],R1
                DEC     R6
                STOR    M[R6],R2
                ; RESTART TIMER
                MVI     R1,TIMER_COUNTVAL
                LOAD    R2,M[R1]
                MVI     R1,TIMER_COUNTER
                STOR    M[R1],R2          ; set timer to count value
                MVI     R1,TIMER_CONTROL
                MVI     R2,TIMER_SETSTART
                STOR    M[R1],R2          ; start timer
                ; INC TIMER FLAG
                MVI     R2,TIMER_TICK
                LOAD    R1,M[R2]
                INC     R1
                STOR    M[R2],R1
                ; RESTORE CONTEXT
                LOAD    R2,M[R6]
                INC     R6
                LOAD    R1,M[R6]
                INC     R6
                JMP     R7

;*****************************************************************
; INTERRUPT SERVICE ROUTINES
;*****************************************************************
                ORIG    7FF0h
TIMER_ISR:      ; SAVE CONTEXT
                DEC     R6
                STOR    M[R6],R7
                ; CALL AUXILIARY FUNCTION
                JAL     AUX_TIMER_ISR
                ; RESTORE CONTEXT
                LOAD    R7,M[R6]
                INC     R6
                RTI
                
                ORIG    7F30h
KEYUP:          ; SAVE CONTEXT
                DEC     R6
                STOR    M[R6],R1
                DEC     R6
                STOR    M[R6],R2
                ; CHANGE VAR SALTO_EVENTO TO TRUE(1)
                MVI     R2, SALTO_EVENTO
                MVI     R1, 1
                STOR    M[R2], R1
                ; RESTORE CONTEXT
                LOAD    R2,M[R6]
                INC     R6
                LOAD    R1,M[R6]
                INC     R6
                RTI
                
                ORIG    7F00h
KEYZERO:        ; SAVE CONTEXT
                DEC     R6
                STOR    M[R6],R1
                DEC     R6
                STOR    M[R6],R2
                ; CHANGE VAR SALTO_BUTTON TO TRUE(1)
                MVI     R2, START_BUTTON
                MVI     R1, 1
                STOR    M[R2], R1
                ; RESTORE CONTEXT
                LOAD    R2,M[R6]
                INC     R6
                LOAD    R1,M[R6]
                INC     R6
                RTI