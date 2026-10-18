TITLE CALCULADORA GRAFICA - JEAN OKABE REZENDE PITON (22013310) / MATHEUS ZANON CARITA (22014203)
;==============================================================================
; Calculadora com interface grafica em Assembly 8086 (DOS, VGA 320x200, mouse)
;
;   - Botoes clicaveis com o mouse (INT 33h) e atalhos no teclado (INT 16h)
;   - Inteiros de 32 bits com sinal: -2147483648 ate 2147483647
;   - Contas encadeadas: 12 + 30 x 2 = ...  (da esquerda para a direita)
;   - Divisao mostra o quociente e o resto
;   - Nenhuma instrucao MUL, IMUL, DIV ou IDIV no programa inteiro
;     (ate o calculo do endereco do pixel, y*320, e feito com deslocamentos)
;
; Teclado:
;   0-9  digitos          + - * / (ou x)  operacoes      ENTER ou =  resultado
;   BACKSPACE  apaga      C  limpa tudo      E ou DELETE  limpa o numero (CE)
;   N  troca o sinal      ESC  sai
;
; Montagem (precisa de aritmet.inc e fonte8x8.inc na mesma pasta):
;   MASM/LINK : masm CalcGUI.asm;  e  link CalcGUI.obj;
;   TASM      : tasm CalcGUI.asm   e  tlink CalcGUI.obj
;   JWasm     : jwasm -mz CalcGUI.asm
; Rode no DOSBox (ou DOS real) para ter mouse e graficos VGA.
;==============================================================================
.MODEL SMALL
.STACK 400h

TAM_MAX     EQU 11              ;'-' + 10 digitos
NUM_BOTOES  EQU 20
TAM_BOTAO   EQU 16              ;bytes por botao na tabela

;------------------------------ cores (paleta propria a partir da cor 32) ----
COR_FUNDO   EQU 32
COR_PAINEL  EQU 33
COR_NUM     EQU 34
COR_NUM_SOM EQU 35
COR_FUN     EQU 36
COR_FUN_SOM EQU 37
COR_OP      EQU 38
COR_OP_SOM  EQU 39
COR_IGUAL   EQU 40
COR_IG_SOM  EQU 41
COR_TEXTO   EQU 42
COR_APAGADO EQU 43
COR_APERTO  EQU 44
COR_ERRO    EQU 45
COR_TITULO  EQU 46
COR_TXT_ESC EQU 47
COR_BORDA   EQU 48
QTD_CORES   EQU 17

;------------------------------ um botao da tabela ---------------------------
; x, y, largura, altura, rotulo, acao, cor, cor da sombra, cor do texto, escala
BOTAO MACRO bx_,by_,bw_,bh_,rot,acao,cor,sombra,ctxt,esc
        DW bx_,by_,bw_,bh_
        DW OFFSET rot
        DB acao,cor,sombra,ctxt,esc,0
ENDM

; deslocamentos dentro de uma entrada da tabela
B_X     EQU 0
B_Y     EQU 2
B_L     EQU 4
B_A     EQU 6
B_ROT   EQU 8
B_ACAO  EQU 10
B_COR   EQU 11
B_SOM   EQU 12
B_CTXT  EQU 13
B_ESC   EQU 14

; colunas e linhas da grade de botoes
C1 EQU 9
C2 EQU 86
C3 EQU 163
C4 EQU 240
L1 EQU 70
L2 EQU 96
L3 EQU 122
L4 EQU 148
L5 EQU 174
BL_ EQU 71                      ;largura do botao
BA_ EQU 22                      ;altura do botao

.DATA
        INCLUDE fonte8x8.inc    ;bitmap dos caracteres (rotulo "fonte8x8")

;---------- paleta: R,G,B de 0 a 63 para as cores 32 a 48 ---------------------
paleta  DB  4, 5, 9             ;COR_FUNDO    azul bem escuro
        DB  1, 2, 4             ;COR_PAINEL   visor
        DB 11,13,19             ;COR_NUM      botoes de numero
        DB  6, 7,11             ;COR_NUM_SOM
        DB 18,20,28             ;COR_FUN      botoes de funcao
        DB 10,11,17             ;COR_FUN_SOM
        DB 62,38, 8             ;COR_OP       operadores (ambar)
        DB 40,22, 3             ;COR_OP_SOM
        DB 14,46,34             ;COR_IGUAL    botao de igual (verde)
        DB  6,28,20             ;COR_IG_SOM
        DB 60,61,63             ;COR_TEXTO    branco
        DB 28,31,38             ;COR_APAGADO  cinza
        DB 42,46,54             ;COR_APERTO   botao pressionado
        DB 63,22,22             ;COR_ERRO     vermelho
        DB 62,42,12             ;COR_TITULO
        DB 10, 7, 2             ;COR_TXT_ESC  texto escuro (sobre ambar)
        DB 14,17,24             ;COR_BORDA

;---------- textos --------------------------------------------------------------
titulo  DB 'CALCULADORA ASSEMBLY 8086$'
subtit  DB 'sem MUL/DIV$'
t_erro  DB 'ERRO$'
t_zero  DB '0$'
t_div0  DB 'nao da para dividir por zero$'
t_estou DB 'estouro: passa de 32 bits$'
t_resto DB 'resto: $'
t_tchau DB 'Calculadora encerrada. Ate mais!',13,10,'$'
t_semmo DB 'mouse nao encontrado: use o teclado$'

r_c     DB 'C$'
r_ce    DB 'CE$'
r_apaga DB 129,'$'              ;seta para a esquerda
r_div   DB 127,'$'              ;sinal de divisao
r_mult  DB 'x$'
r_menos DB '-$'
r_mais  DB '+$'
r_igual DB '=$'
r_sinal DB 128,'$'              ;mais-ou-menos
r_sair  DB 'SAIR$'
r_0     DB '0$'
r_1     DB '1$'
r_2     DB '2$'
r_3     DB '3$'
r_4     DB '4$'
r_5     DB '5$'
r_6     DB '6$'
r_7     DB '7$'
r_8     DB '8$'
r_9     DB '9$'

;---------- tabela de botoes ------------------------------------------------------
botoes  LABEL BYTE
        BOTAO C1,L1,BL_,BA_,r_c,    'C',COR_FUN,  COR_FUN_SOM,COR_TEXTO,  2
        BOTAO C2,L1,BL_,BA_,r_ce,   'E',COR_FUN,  COR_FUN_SOM,COR_TEXTO,  2
        BOTAO C3,L1,BL_,BA_,r_apaga,'B',COR_FUN,  COR_FUN_SOM,COR_TEXTO,  2
        BOTAO C4,L1,BL_,BA_,r_div,  '/',COR_OP,   COR_OP_SOM, COR_TXT_ESC,2
        BOTAO C1,L2,BL_,BA_,r_7,    '7',COR_NUM,  COR_NUM_SOM,COR_TEXTO,  2
        BOTAO C2,L2,BL_,BA_,r_8,    '8',COR_NUM,  COR_NUM_SOM,COR_TEXTO,  2
        BOTAO C3,L2,BL_,BA_,r_9,    '9',COR_NUM,  COR_NUM_SOM,COR_TEXTO,  2
        BOTAO C4,L2,BL_,BA_,r_mult, '*',COR_OP,   COR_OP_SOM, COR_TXT_ESC,2
        BOTAO C1,L3,BL_,BA_,r_4,    '4',COR_NUM,  COR_NUM_SOM,COR_TEXTO,  2
        BOTAO C2,L3,BL_,BA_,r_5,    '5',COR_NUM,  COR_NUM_SOM,COR_TEXTO,  2
        BOTAO C3,L3,BL_,BA_,r_6,    '6',COR_NUM,  COR_NUM_SOM,COR_TEXTO,  2
        BOTAO C4,L3,BL_,BA_,r_menos,'-',COR_OP,   COR_OP_SOM, COR_TXT_ESC,2
        BOTAO C1,L4,BL_,BA_,r_1,    '1',COR_NUM,  COR_NUM_SOM,COR_TEXTO,  2
        BOTAO C2,L4,BL_,BA_,r_2,    '2',COR_NUM,  COR_NUM_SOM,COR_TEXTO,  2
        BOTAO C3,L4,BL_,BA_,r_3,    '3',COR_NUM,  COR_NUM_SOM,COR_TEXTO,  2
        BOTAO C4,L4,BL_,BA_,r_mais, '+',COR_OP,   COR_OP_SOM, COR_TXT_ESC,2
        BOTAO C1,L5,BL_,BA_,r_sair, 'Q',COR_FUN,  COR_FUN_SOM,COR_TEXTO,  1
        BOTAO C2,L5,BL_,BA_,r_0,    '0',COR_NUM,  COR_NUM_SOM,COR_TEXTO,  2
        BOTAO C3,L5,BL_,BA_,r_sinal,'N',COR_FUN,  COR_FUN_SOM,COR_TEXTO,  2
        BOTAO C4,L5,BL_,BA_,r_igual,'=',COR_IGUAL,COR_IG_SOM, COR_TEXTO,  2

;---------- estado da calculadora ---------------------------------------------
acc      DD 0                   ;acumulador (resultado atual / primeiro numero)
num_b    DD 0                   ;segundo numero da operacao
resto    DD 0                   ;resto da ultima divisao
oper     DB 0                   ;operacao pendente: 0, '+', '-', '*' ou '/'
digitando DB 0                  ;1 = o usuario esta digitando um numero em buf
erro     DB 0                   ;1 = visor mostrando ERRO
sair     DB 0                   ;1 = encerrar o programa
mouse_ok DB 0                   ;1 = driver de mouse presente
buf      DB TAM_MAX+1 DUP(?)    ;numero sendo digitado (+1 para o '$')
buflen   DW 0
num_txt  DB 16 DUP(?)           ;numero convertido para texto

; linhas de texto do visor: [tamanho (DW)] [texto terminado em '$']
hist     DW 0                   ;linha de cima: "125 x 3 ="
         DB 48 DUP('$')
info     DW 0                   ;linha de baixo: resto / mensagem de erro
         DB 48 DUP('$')
info_cor DB COR_APAGADO

;---------- parametros das rotinas de desenho --------------------------------------
rx       DW ?                   ;retangulo
ry       DW ?
rw       DW ?
rh       DW ?
rcor     DB ?
tx       DW ?                   ;texto
ty       DW ?
tcor     DB ?
tesc     DB 1                   ;escala do texto: 1 = 8x8, 2 = 16x16
apertado DB 0
topo_b   DW ?                   ;y do corpo do botao

.CODE

main proc
        MOV ax,@DATA
        MOV ds,ax
        CLD

        MOV ax,0013h            ;modo grafico VGA 320x200 com 256 cores
        INT 10h
        CALL carrega_paleta

        XOR ax,ax               ;inicializa o mouse (AX = FFFFh se existir)
        INT 33h
        CMP ax,0FFFFh
        JNE sem_mouse
        MOV mouse_ok,1
sem_mouse:
        CALL limpa_tudo
        CALL desenha_tela
        CMP mouse_ok,1
        JE  com_mouse
        LEA di,info             ;avisa que so o teclado funciona
        LEA si,t_semmo
        CALL txt_copia
        CALL desenha_display
        JMP laco
com_mouse:
        MOV ax,1                ;mostra o ponteiro do mouse
        INT 33h

;------------------------------------------------------------------------------
; laco principal: verifica teclado e mouse o tempo todo
;------------------------------------------------------------------------------
laco:
        CMP sair,1
        JE  fim

        MOV ah,01h              ;tem tecla no buffer?
        INT 16h
        JZ  ve_mouse
        MOV ah,00h              ;le a tecla (AL = ASCII, AH = scan code)
        INT 16h
        CALL traduz_tecla       ;AL = acao do botao correspondente (ou 0)
        CMP al,0
        JE  laco
        PUSH ax
        CALL pisca_botao        ;mostra o botao "afundando"
        POP ax
        CALL executa
        JMP laco

ve_mouse:
        CMP mouse_ok,1
        JNE laco
        MOV ax,3                ;BX = botoes, CX = x (0..639), DX = y
        INT 33h
        TEST bx,1               ;botao esquerdo apertado?
        JZ  laco
        SHR cx,1                ;no modo 13h o driver usa x de 0 a 639
        CALL acha_botao         ;SI = botao sob o mouse
        JC  espera_soltar_fora

        MOV al,1                ;desenha o botao apertado
        CALL desenha_botao
espera_soltar:
        MOV ax,3
        INT 33h
        TEST bx,1
        JNZ espera_soltar
        SHR cx,1
        PUSH si
        CALL acha_botao         ;soltou em cima do mesmo botao?
        MOV bx,si
        POP si
        JC  solta_fora
        CMP bx,si
        JNE solta_fora
        MOV al,0
        CALL desenha_botao
        MOV al,[si+B_ACAO]
        CALL executa            ;clique completo: executa a acao
        JMP laco
solta_fora:
        MOV al,0                ;arrastou para fora: cancela o clique
        CALL desenha_botao
        JMP laco

espera_soltar_fora:
        MOV ax,3
        INT 33h
        TEST bx,1
        JNZ espera_soltar_fora
        JMP laco

fim:
        XOR ax,ax               ;desliga o mouse
        INT 33h
        MOV ax,0003h            ;volta para o modo texto
        INT 10h
        LEA dx,t_tchau
        MOV ah,09h
        INT 21h
        MOV ax,4C00h
        INT 21h
main endp

;==============================================================================
;                          LOGICA DA CALCULADORA
;==============================================================================

;------------------------------------------------------------------------------
; executa: realiza a acao de um botao (AL = codigo da acao)
;------------------------------------------------------------------------------
executa proc
        CMP al,'Q'
        JNE ex_nao_sai
        MOV sair,1
        RET
ex_nao_sai:
        CMP al,'C'
        JNE ex_nao_limpa
        CALL limpa_tudo
        JMP ex_redesenha
ex_nao_limpa:
        CMP erro,0
        JE  ex_despacha
        ;visor em erro: CE limpa, um digito comeca do zero, o resto e ignorado
        CMP al,'E'
        JNE ex_erro_digito
        CALL limpa_tudo
        JMP ex_redesenha
ex_erro_digito:
        CMP al,'0'
        JB  ex_bipe
        CMP al,'9'
        JA  ex_bipe
        CALL limpa_tudo

ex_despacha:
        CMP al,'0'
        JB  ex_nao_digito
        CMP al,'9'
        JA  ex_nao_digito
        CALL acao_digito
        JMP ex_redesenha
ex_nao_digito:
        CMP al,'+'
        JE  ex_operador
        CMP al,'-'
        JE  ex_operador
        CMP al,'*'
        JE  ex_operador
        CMP al,'/'
        JE  ex_operador
        CMP al,'='
        JE  ex_igual
        CMP al,'B'
        JE  ex_apaga
        CMP al,'E'
        JE  ex_ce
        CMP al,'N'
        JE  ex_sinal
        JMP ex_bipe

ex_operador:
        CALL acao_operador
        JMP ex_redesenha
ex_igual:
        CALL acao_igual
        JMP ex_redesenha
ex_apaga:
        CALL acao_apaga
        JMP ex_redesenha
ex_ce:
        MOV digitando,1         ;CE: zera so o numero que esta sendo digitado
        MOV buflen,0
        LEA di,info
        CALL txt_limpa
        JMP ex_redesenha
ex_sinal:
        CALL acao_sinal
        JMP ex_redesenha

ex_bipe:
        CALL bipe
        RET
ex_redesenha:
        CALL desenha_display
        RET
executa endp

;------------------------------------------------------------------------------
; limpa_tudo: volta a calculadora ao estado inicial (botao C)
;------------------------------------------------------------------------------
limpa_tudo proc
        MOV WORD PTR acc,0
        MOV WORD PTR acc+2,0
        MOV oper,0
        MOV digitando,0
        MOV erro,0
        MOV buflen,0
        LEA di,hist
        CALL txt_limpa
        LEA di,info
        CALL txt_limpa
        MOV info_cor,COR_APAGADO
        RET
limpa_tudo endp

;------------------------------------------------------------------------------
; acao_digito: acrescenta o digito AL ao numero sendo digitado
;------------------------------------------------------------------------------
acao_digito proc
        CMP digitando,1
        JE  ad_continua
        MOV digitando,1         ;comeca um numero novo
        MOV buflen,0
        LEA di,info
        CALL txt_limpa
        CMP oper,0              ;sem operacao pendente = conta nova: limpa o historico
        JNE ad_continua
        LEA di,hist
        CALL txt_limpa
ad_continua:
        MOV bx,buflen
        ;um "0" sozinho (ou "-0") e trocado pelo novo digito: evita "007"
        CMP bx,1
        JNE ad_ve_menos_zero
        CMP buf,'0'
        JNE ad_acrescenta
        MOV bx,0
        JMP ad_acrescenta
ad_ve_menos_zero:
        CMP bx,2
        JNE ad_acrescenta
        CMP buf,'-'
        JNE ad_acrescenta
        CMP buf+1,'0'
        JNE ad_acrescenta
        MOV bx,1
ad_acrescenta:
        CMP bx,TAM_MAX
        JAE ad_recusa
        MOV buf[bx],al
        LEA si,buf              ;ainda cabe em 32 bits?
        MOV cx,bx
        INC cx
        CALL str2num
        JC  ad_recusa
        INC bx
        MOV buflen,bx
        RET
ad_recusa:
        CALL bipe
        RET
acao_digito endp

;------------------------------------------------------------------------------
; acao_operador: botoes + - x /   (AL = operacao)
;   Se havia uma conta pendente, ela e resolvida antes (contas encadeadas).
;------------------------------------------------------------------------------
acao_operador proc
        PUSH ax
        LEA di,info
        CALL txt_limpa
        MOV info_cor,COR_APAGADO
        CMP digitando,1
        JNE ao_troca_operador   ;nada digitado: so troca a operacao pendente
        CALL valor_digitado     ;num_b = numero digitado
        MOV digitando,0
        CMP oper,0
        JE  ao_primeiro
        CALL calcula            ;acc = acc (oper) num_b
        JNC ao_troca_operador
        POP ax                  ;deu erro: a nova operacao e descartada
        RET
ao_primeiro:
        MOV ax,WORD PTR num_b   ;primeiro numero da conta vai para o acumulador
        MOV dx,WORD PTR num_b+2
        MOV WORD PTR acc,ax
        MOV WORD PTR acc+2,dx
ao_troca_operador:
        POP ax
        MOV oper,al
        LEA di,hist             ;historico: "<acc> <op>"
        CALL txt_limpa
        MOV ax,WORD PTR acc
        MOV dx,WORD PTR acc+2
        CALL txt_numero
        MOV al,' '
        CALL txt_char
        CALL simbolo_oper
        CALL txt_char
        RET
acao_operador endp

;------------------------------------------------------------------------------
; acao_igual: botao =
;------------------------------------------------------------------------------
acao_igual proc
        CMP oper,0
        JNE ai_tem_operacao
        CMP digitando,1         ;sem conta pendente: so confirma o numero digitado
        JNE ai_sai
        CALL valor_digitado
        MOV ax,WORD PTR num_b
        MOV dx,WORD PTR num_b+2
        MOV WORD PTR acc,ax
        MOV WORD PTR acc+2,dx
        MOV digitando,0
ai_sai:
        RET

ai_tem_operacao:
        CMP digitando,1
        JE  ai_digitado
        MOV ax,WORD PTR acc     ;"5 + =" usa o proprio 5 como segundo numero
        MOV dx,WORD PTR acc+2
        MOV WORD PTR num_b,ax
        MOV WORD PTR num_b+2,dx
        JMP ai_monta
ai_digitado:
        CALL valor_digitado
ai_monta:
        LEA di,hist             ;historico: "<acc> <op> <num_b> ="
        CALL txt_limpa
        MOV ax,WORD PTR acc
        MOV dx,WORD PTR acc+2
        CALL txt_numero
        MOV al,' '
        CALL txt_char
        CALL simbolo_oper
        CALL txt_char
        MOV al,' '
        CALL txt_char
        MOV ax,WORD PTR num_b
        MOV dx,WORD PTR num_b+2
        CALL txt_numero
        MOV al,' '
        CALL txt_char
        MOV al,'='
        CALL txt_char

        LEA di,info
        CALL txt_limpa
        MOV info_cor,COR_APAGADO
        CALL calcula
        MOV oper,0
        MOV digitando,0
        RET
acao_igual endp

;------------------------------------------------------------------------------
; acao_apaga: BACKSPACE, apaga o ultimo caractere digitado
;------------------------------------------------------------------------------
acao_apaga proc
        CMP digitando,1
        JNE aa_bipe
        CMP buflen,0
        JE  aa_bipe
        DEC buflen
        RET
aa_bipe:
        CALL bipe
        RET
acao_apaga endp

;------------------------------------------------------------------------------
; acao_sinal: botao +/- (troca o sinal do numero do visor)
;------------------------------------------------------------------------------
acao_sinal proc
        CMP digitando,1
        JE  as_alterna
        MOV digitando,1
        MOV buflen,0
        CMP oper,0              ;com operacao pendente comeca um numero novo ("-")
        JNE as_alterna
        MOV ax,WORD PTR acc     ;sem operacao: o resultado do visor vira o numero digitado
        MOV dx,WORD PTR acc+2
        LEA di,buf
        CALL num2str            ;CX = tamanho
        MOV buflen,cx
        LEA di,hist
        CALL txt_limpa
        LEA di,info
        CALL txt_limpa
as_alterna:
        MOV bx,buflen
        CMP bx,0
        JE  as_poe_menos
        CMP buf,'-'
        JNE as_poe_menos
        CALL buf_tira_menos     ;tira o '-' ...
        LEA si,buf
        MOV cx,buflen
        CALL str2num            ;... mas 2147483648 positivo nao cabe em 32 bits
        JNC as_sai
        CALL buf_poe_menos
        CALL bipe
        RET
as_poe_menos:
        CMP bx,TAM_MAX
        JAE as_sai
        CALL buf_poe_menos
as_sai:
        RET
acao_sinal endp

buf_poe_menos proc              ;insere '-' no inicio de buf
        MOV bx,buflen
        MOV cx,bx
        JCXZ bpm_poe
bpm_laco:
        MOV al,buf[bx-1]
        MOV buf[bx],al
        DEC bx
        LOOP bpm_laco
bpm_poe:
        MOV buf,'-'
        INC buflen
        RET
buf_poe_menos endp

buf_tira_menos proc             ;remove o primeiro caractere de buf
        XOR bx,bx
        MOV cx,buflen
        DEC cx
        JCXZ btm_fim
btm_laco:
        MOV al,buf[bx+1]
        MOV buf[bx],al
        INC bx
        LOOP btm_laco
btm_fim:
        DEC buflen
        RET
buf_tira_menos endp

;------------------------------------------------------------------------------
; valor_digitado: num_b = numero que esta em buf
;------------------------------------------------------------------------------
valor_digitado proc
        LEA si,buf
        MOV cx,buflen
        CALL str2num            ;sempre cabe: cada digito foi validado ao digitar
        MOV WORD PTR num_b,ax
        MOV WORD PTR num_b+2,dx
        RET
valor_digitado endp

;------------------------------------------------------------------------------
; calcula: acc = acc (oper) num_b.   CF = 1 em caso de erro (visor mostra ERRO)
;------------------------------------------------------------------------------
calcula proc
        MOV ax,WORD PTR acc
        MOV dx,WORD PTR acc+2
        MOV bx,WORD PTR num_b
        MOV cx,WORD PTR num_b+2

        CMP oper,'+'
        JNE ca_nao_soma
        CALL soma32
        JMP ca_resultado
ca_nao_soma:
        CMP oper,'-'
        JNE ca_nao_sub
        CALL subtrai32
        JMP ca_resultado
ca_nao_sub:
        CMP oper,'*'
        JNE ca_divide
        CALL mult32
        JMP ca_resultado

ca_divide:
        MOV si,bx               ;divisor zero?
        OR  si,cx
        JZ  ca_div_zero
        CALL div32              ;DX:AX = quociente, CX:BX = resto
        JC  ca_estouro
        MOV WORD PTR resto,bx
        MOV WORD PTR resto+2,cx
        MOV WORD PTR acc,ax
        MOV WORD PTR acc+2,dx
        LEA di,info             ;linha de baixo: "resto: R"
        CALL txt_limpa
        LEA si,t_resto
        CALL txt_copia
        MOV ax,WORD PTR resto
        MOV dx,WORD PTR resto+2
        CALL txt_numero
        CLC
        RET

ca_resultado:
        JC  ca_estouro
        MOV WORD PTR acc,ax
        MOV WORD PTR acc+2,dx
        CLC
        RET

ca_div_zero:
        LEA si,t_div0
        JMP ca_erro
ca_estouro:
        LEA si,t_estou
ca_erro:
        LEA di,info
        CALL txt_limpa
        CALL txt_copia
        MOV info_cor,COR_ERRO
        MOV erro,1
        MOV oper,0
        MOV digitando,0
        CALL bipe
        STC
        RET
calcula endp

;------------------------------------------------------------------------------
; simbolo_oper: AL = caractere que representa a operacao pendente
;------------------------------------------------------------------------------
simbolo_oper proc
        MOV al,oper
        CMP al,'*'
        JNE so_nao_mult
        MOV al,'x'
        RET
so_nao_mult:
        CMP al,'/'
        JNE so_sai
        MOV al,127              ;sinal de divisao da fonte
so_sai:
        RET
simbolo_oper endp

;------------------------------------------------------------------------------
; traduz_tecla: AL = ASCII, AH = scan code  ->  AL = acao do botao (0 = nada)
;------------------------------------------------------------------------------
traduz_tecla proc
        CMP al,'0'
        JB  tt_simbolos
        CMP al,'9'
        JBE tt_sai              ;digitos: a acao e o proprio digito
tt_simbolos:
        CMP al,'+'
        JE  tt_sai
        CMP al,'-'
        JE  tt_sai
        CMP al,'/'
        JE  tt_sai
        CMP al,'*'
        JE  tt_sai
        CMP al,'='
        JE  tt_sai
        MOV bl,al
        MOV al,'*'
        CMP bl,'x'
        JE  tt_sai
        CMP bl,'X'
        JE  tt_sai
        MOV al,'='
        CMP bl,13               ;ENTER
        JE  tt_sai
        MOV al,'B'
        CMP bl,8                ;BACKSPACE
        JE  tt_sai
        MOV al,'Q'
        CMP bl,27               ;ESC
        JE  tt_sai
        AND bl,0DFh             ;letras: maiuscula ou minuscula tanto faz
        MOV al,'C'
        CMP bl,'C'
        JE  tt_sai
        MOV al,'E'
        CMP bl,'E'
        JE  tt_sai
        CMP ah,53h              ;DELETE (scan code 53h)
        JE  tt_sai
        MOV al,'N'
        CMP bl,'N'
        JE  tt_sai
        XOR al,al               ;tecla sem funcao
tt_sai:
        RET
traduz_tecla endp

;------------------------------------------------------------------------------
; bipe: apita (BEL)
;------------------------------------------------------------------------------
bipe proc
        PUSH ax
        PUSH dx
        MOV dl,7
        MOV ah,02h
        INT 21h
        POP dx
        POP ax
        RET
bipe endp

;==============================================================================
;                   TEXTOS DO VISOR  ([tamanho DW] + texto + '$')
;==============================================================================

txt_limpa proc                  ;DI = linha de texto
        MOV WORD PTR [di],0
        MOV BYTE PTR [di+2],'$'
        RET
txt_limpa endp

txt_char proc                   ;DI = linha, AL = caractere a acrescentar
        PUSH bx
        MOV bx,[di]
        CMP bx,46               ;protege o tamanho do buffer
        JAE tc_sai
        MOV [di+bx+2],al
        INC bx
        MOV BYTE PTR [di+bx+2],'$'
        MOV [di],bx
tc_sai:
        POP bx
        RET
txt_char endp

txt_copia proc                  ;DI = linha, SI = texto terminado em '$'
        PUSH ax
        PUSH si
tcp_laco:
        MOV al,[si]
        CMP al,'$'
        JE  tcp_fim
        CALL txt_char
        INC si
        JMP tcp_laco
tcp_fim:
        POP si
        POP ax
        RET
txt_copia endp

txt_numero proc                 ;DI = linha, DX:AX = numero
        PUSH cx
        PUSH si
        PUSH di
        LEA di,num_txt
        CALL num2str
        POP di
        LEA si,num_txt
        CALL txt_copia
        POP si
        POP cx
        RET
txt_numero endp

;==============================================================================
;                              DESENHO (VGA 13h)
;==============================================================================

;------------------------------------------------------------------------------
; carrega_paleta: define as cores 32..48 (porta 3C8h = indice, 3C9h = R,G,B)
;------------------------------------------------------------------------------
carrega_paleta proc
        MOV dx,3C8h
        MOV al,COR_FUNDO
        OUT dx,al
        INC dx                  ;3C9h
        LEA si,paleta
        MOV cx,QTD_CORES*3
cp_laco:
        MOV al,[si]
        OUT dx,al
        INC si
        LOOP cp_laco
        RET
carrega_paleta endp

;------------------------------------------------------------------------------
; vezes320: AX = AX * 320, sem MUL:  320*y = 256*y + 64*y
;------------------------------------------------------------------------------
vezes320 proc
        PUSH cx
        PUSH dx
        MOV dx,ax
        MOV cl,8
        SHL ax,cl               ;256 * y
        MOV cl,6
        SHL dx,cl               ;64 * y
        ADD ax,dx
        POP dx
        POP cx
        RET
vezes320 endp

;------------------------------------------------------------------------------
; retangulo: preenche (rx, ry, rw, rh) com a cor rcor
;------------------------------------------------------------------------------
retangulo proc
        PUSH ax
        PUSH bx
        PUSH cx
        PUSH di
        PUSH es
        MOV ax,0A000h           ;memoria de video
        MOV es,ax
        MOV ax,ry
        CALL vezes320
        ADD ax,rx
        MOV di,ax               ;DI = y*320 + x
        MOV bx,rh
        MOV al,rcor
re_linha:
        CMP bx,0
        JE  re_fim
        PUSH di
        MOV cx,rw
        REP STOSB               ;pinta uma linha inteira
        POP di
        ADD di,320
        DEC bx
        JMP re_linha
re_fim:
        POP es
        POP di
        POP cx
        POP bx
        POP ax
        RET
retangulo endp

;------------------------------------------------------------------------------
; pixel: pinta o ponto (AX = x, BX = y) com a cor DL
;------------------------------------------------------------------------------
pixel proc
        PUSH ax
        PUSH di
        PUSH es
        MOV di,ax
        MOV ax,bx
        CALL vezes320
        ADD di,ax
        MOV ax,0A000h
        MOV es,ax
        MOV es:[di],dl
        POP es
        POP di
        POP ax
        RET
pixel endp

;------------------------------------------------------------------------------
; desenha_char: desenha o caractere AL em (tx, ty), cor tcor, escala tesc (1/2)
;------------------------------------------------------------------------------
desenha_char proc
        PUSH ax
        PUSH bx
        PUSH cx
        PUSH dx
        PUSH si
        PUSH di
        PUSH es

        CMP al,32               ;fora da fonte vira '?'
        JB  dch_troca
        CMP al,129
        JBE dch_ok
dch_troca:
        MOV al,'?'
dch_ok:
        SUB al,32               ;SI = fonte8x8 + (caractere - 32) * 8
        XOR ah,ah
        MOV cl,3
        SHL ax,cl
        MOV si,ax
        ADD si,OFFSET fonte8x8

        MOV ax,ty
        CALL vezes320
        ADD ax,tx
        MOV di,ax
        MOV ax,0A000h
        MOV es,ax
        MOV dl,tcor
        MOV dh,tesc
        MOV bh,8                ;8 linhas
dch_linha:
        MOV ah,[si]             ;bits da linha (bit 7 = pixel da esquerda)
        INC si
        MOV bl,8                ;8 colunas
        PUSH di
dch_coluna:
        SHL ah,1
        JNC dch_pula
        MOV es:[di],dl
        CMP dh,1
        JE  dch_pula
        MOV es:[di+1],dl        ;escala 2: cada ponto vira um quadrado 2x2
        MOV es:[di+320],dl
        MOV es:[di+321],dl
dch_pula:
        INC di
        CMP dh,1
        JE  dch_prox_coluna
        INC di
dch_prox_coluna:
        DEC bl
        JNZ dch_coluna
        POP di
        ADD di,320
        CMP dh,1
        JE  dch_prox_linha
        ADD di,320
dch_prox_linha:
        DEC bh
        JNZ dch_linha

        POP es
        POP di
        POP si
        POP dx
        POP cx
        POP bx
        POP ax
        RET
desenha_char endp

;------------------------------------------------------------------------------
; largura_texto: AX = largura em pixels do texto em DS:SI (terminado em '$')
;------------------------------------------------------------------------------
largura_texto proc
        PUSH cx
        PUSH si
        XOR ax,ax
lt_laco:
        CMP BYTE PTR [si],'$'
        JE  lt_fim
        INC ax
        INC si
        JMP lt_laco
lt_fim:
        MOV cl,3                ;8 pixels por caractere
        CMP tesc,1
        JE  lt_desloca
        MOV cl,4                ;16 pixels na escala 2
lt_desloca:
        SHL ax,cl
        POP si
        POP cx
        RET
largura_texto endp

;------------------------------------------------------------------------------
; desenha_texto: escreve DS:SI (terminado em '$') a partir de (tx, ty)
;------------------------------------------------------------------------------
desenha_texto proc
        PUSH ax
        PUSH bx
        PUSH si
        PUSH tx
        MOV bx,8
        CMP tesc,1
        JE  dt_laco
        MOV bx,16
dt_laco:
        MOV al,[si]
        CMP al,'$'
        JE  dt_fim
        CALL desenha_char
        ADD tx,bx
        INC si
        JMP dt_laco
dt_fim:
        POP tx
        POP si
        POP bx
        POP ax
        RET
desenha_texto endp

;------------------------------------------------------------------------------
; texto_direita: escreve DS:SI terminando na coluna AX (alinhado a direita)
;------------------------------------------------------------------------------
texto_direita proc
        PUSH ax
        PUSH bx
        MOV bx,ax
        CALL largura_texto
        SUB bx,ax
        MOV tx,bx
        CALL desenha_texto
        POP bx
        POP ax
        RET
texto_direita endp

;------------------------------------------------------------------------------
; esconde_mouse / mostra_mouse: o ponteiro precisa sumir enquanto desenhamos
;------------------------------------------------------------------------------
esconde_mouse proc
        CMP mouse_ok,1
        JNE em_sai
        PUSH ax
        MOV ax,2
        INT 33h
        POP ax
em_sai:
        RET
esconde_mouse endp

mostra_mouse proc
        CMP mouse_ok,1
        JNE mm_sai
        PUSH ax
        MOV ax,1
        INT 33h
        POP ax
mm_sai:
        RET
mostra_mouse endp

;------------------------------------------------------------------------------
; desenha_tela: fundo, titulo, visor e todos os botoes
;------------------------------------------------------------------------------
desenha_tela proc
        CALL esconde_mouse
        MOV rx,0
        MOV ry,0
        MOV rw,320
        MOV rh,200
        MOV rcor,COR_FUNDO
        CALL retangulo

        MOV tesc,1
        MOV tcor,COR_TITULO
        MOV tx,9
        MOV ty,4
        LEA si,titulo
        CALL desenha_texto
        MOV tcor,COR_APAGADO
        LEA si,subtit
        MOV ax,311
        CALL texto_direita

        MOV rx,8                ;moldura do visor
        MOV ry,16
        MOV rw,304
        MOV rh,48
        MOV rcor,COR_BORDA
        CALL retangulo

        LEA si,botoes
        MOV cx,NUM_BOTOES
dte_laco:
        MOV al,0
        CALL desenha_botao
        ADD si,TAM_BOTAO
        LOOP dte_laco

        CALL desenha_display
        CALL mostra_mouse
        RET
desenha_tela endp

;------------------------------------------------------------------------------
; desenha_display: redesenha o visor (historico, numero grande, info)
;------------------------------------------------------------------------------
desenha_display proc
        PUSH ax
        PUSH bx
        PUSH cx
        PUSH dx
        PUSH si
        PUSH di
        CALL esconde_mouse

        MOV rx,9                ;fundo do visor
        MOV ry,17
        MOV rw,302
        MOV rh,46
        MOV rcor,COR_PAINEL
        CALL retangulo

        MOV tesc,1              ;linha de cima: historico da conta
        MOV tcor,COR_APAGADO
        MOV ty,21
        LEA si,hist+2
        MOV ax,304
        CALL texto_direita

        MOV tesc,2              ;numero grande
        MOV tcor,COR_TEXTO
        MOV ty,32
        CMP erro,1
        JNE dd_sem_erro
        MOV tcor,COR_ERRO
        LEA si,t_erro
        JMP dd_numero
dd_sem_erro:
        CMP digitando,1
        JNE dd_acumulador
        MOV bx,buflen
        CMP bx,0
        JNE dd_buf
        LEA si,t_zero           ;nada digitado ainda: mostra 0
        JMP dd_numero
dd_buf:
        MOV buf[bx],'$'
        LEA si,buf
        JMP dd_numero
dd_acumulador:
        MOV ax,WORD PTR acc
        MOV dx,WORD PTR acc+2
        LEA di,num_txt
        CALL num2str
        LEA si,num_txt
dd_numero:
        MOV ax,304
        CALL texto_direita

        MOV tesc,1              ;linha de baixo: resto ou mensagem
        MOV al,info_cor
        MOV tcor,al
        MOV ty,52
        LEA si,info+2
        MOV ax,304
        CALL texto_direita

        CALL mostra_mouse
        POP di
        POP si
        POP dx
        POP cx
        POP bx
        POP ax
        RET
desenha_display endp

;------------------------------------------------------------------------------
; desenha_botao: SI = botao da tabela, AL = 1 apertado / 0 normal
;------------------------------------------------------------------------------
desenha_botao proc
        PUSH ax
        PUSH bx
        PUSH cx
        PUSH dx
        PUSH si
        MOV apertado,al
        CALL esconde_mouse

        MOV ax,[si+B_X]         ;limpa a area inteira do botao
        MOV rx,ax
        MOV ax,[si+B_Y]
        MOV ry,ax
        MOV ax,[si+B_L]
        MOV rw,ax
        MOV ax,[si+B_A]
        MOV rh,ax
        MOV rcor,COR_FUNDO
        CALL retangulo

        MOV ax,[si+B_Y]         ;corpo: desce 2 pixels quando apertado
        CMP apertado,1
        JNE db_topo
        ADD ax,2
db_topo:
        MOV topo_b,ax
        MOV ry,ax
        MOV ax,[si+B_A]
        SUB ax,2
        MOV rh,ax
        MOV al,[si+B_COR]
        CMP apertado,1
        JNE db_cor
        MOV al,COR_APERTO
db_cor:
        MOV rcor,al
        CALL retangulo

        CMP apertado,1          ;sombra embaixo (so quando solto)
        JE  db_cantos
        MOV ax,[si+B_Y]
        ADD ax,[si+B_A]
        SUB ax,2
        MOV ry,ax
        MOV rh,2
        MOV al,[si+B_SOM]
        MOV rcor,al
        CALL retangulo

db_cantos:                      ;cantos arredondados: pinta os 4 cantos com o fundo
        MOV dl,COR_FUNDO
        MOV ax,[si+B_X]
        MOV bx,topo_b
        CALL pixel
        MOV cx,[si+B_Y]
        ADD cx,[si+B_A]
        DEC cx                  ;CX = ultima linha do botao
        MOV bx,cx
        CALL pixel
        ADD ax,[si+B_L]
        DEC ax                  ;AX = ultima coluna
        CALL pixel
        MOV bx,topo_b
        CALL pixel

        MOV al,[si+B_ESC]       ;rotulo centralizado
        MOV tesc,al
        MOV al,[si+B_CTXT]
        MOV tcor,al
        PUSH si
        MOV si,[si+B_ROT]
        CALL largura_texto      ;AX = largura do rotulo
        POP si
        MOV bx,[si+B_L]
        SUB bx,ax
        SHR bx,1
        ADD bx,[si+B_X]
        MOV tx,bx               ;tx = x + (largura - texto) / 2
        MOV bx,[si+B_A]
        SUB bx,10               ;altura do corpo (h - 2) menos 8 pixels de texto
        CMP tesc,1
        JE  db_centro_y
        SUB bx,8                ;texto de 16 pixels
db_centro_y:
        SHR bx,1
        ADD bx,topo_b
        MOV ty,bx
        MOV si,[si+B_ROT]
        CALL desenha_texto

        CALL mostra_mouse
        POP si
        POP dx
        POP cx
        POP bx
        POP ax
        RET
desenha_botao endp

;------------------------------------------------------------------------------
; acha_botao: CX = x, DX = y  ->  SI = botao nessa posicao (CF = 1 se nenhum)
;------------------------------------------------------------------------------
acha_botao proc
        PUSH ax
        PUSH bx
        LEA si,botoes
        MOV bx,NUM_BOTOES
ab_laco:
        MOV ax,[si+B_X]
        CMP cx,ax
        JB  ab_proximo
        ADD ax,[si+B_L]
        CMP cx,ax
        JAE ab_proximo
        MOV ax,[si+B_Y]
        CMP dx,ax
        JB  ab_proximo
        ADD ax,[si+B_A]
        CMP dx,ax
        JAE ab_proximo
        CLC                     ;achou
        JMP ab_sai
ab_proximo:
        ADD si,TAM_BOTAO
        DEC bx
        JNZ ab_laco
        STC                     ;nenhum botao
ab_sai:
        POP bx
        POP ax
        RET
acha_botao endp

;------------------------------------------------------------------------------
; pisca_botao: AL = acao. Mostra o botao correspondente apertado por um instante
;------------------------------------------------------------------------------
pisca_botao proc
        PUSH ax
        PUSH cx
        PUSH dx
        PUSH si
        LEA si,botoes
        MOV cx,NUM_BOTOES
pb_procura:
        CMP [si+B_ACAO],al
        JE  pb_achou
        ADD si,TAM_BOTAO
        LOOP pb_procura
        JMP pb_sai
pb_achou:
        MOV al,1
        CALL desenha_botao
        CALL espera_tique
        CALL espera_tique
        MOV al,0
        CALL desenha_botao
pb_sai:
        POP si
        POP dx
        POP cx
        POP ax
        RET
pisca_botao endp

;------------------------------------------------------------------------------
; espera_tique: espera o relogio da BIOS avancar (1 tique = ~55 ms)
;------------------------------------------------------------------------------
espera_tique proc
        PUSH ax
        PUSH bx
        PUSH cx
        PUSH dx
        MOV ah,00h
        INT 1Ah                 ;CX:DX = tiques desde a meia-noite
        MOV bx,dx
et_laco:
        MOV ah,00h
        INT 1Ah
        CMP dx,bx
        JE  et_laco
        POP dx
        POP cx
        POP bx
        POP ax
        RET
espera_tique endp

        INCLUDE aritmet.inc     ;soma32, subtrai32, mult32, div32, num2str, str2num

end main
