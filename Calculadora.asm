TITLE NOME: JEAN OKABE REZENDE PITON | RA: 22013310 ||| NOME: MATHEUS ZANON CARITA | RA: 22014203
;==============================================================================
; Calculadora em Assembly 8086 (modo texto / DOS)
;   Adicao, Subtracao, Multiplicacao e Divisao de inteiros de 32 bits com sinal
;   (-2147483648 ate 2147483647) SEM usar as instrucoes MUL, IMUL, DIV ou IDIV.
;
;   As contas ficam em aritmet.inc (compartilhado com a versao grafica CalcGUI.asm).
;
; Montagem:
;   MASM/LINK : masm Calculadora.asm;  e  link Calculadora.obj;
;   TASM      : tasm Calculadora.asm   e  tlink Calculadora.obj
;   JWasm     : jwasm -mz Calculadora.asm
;   EMU8086   : abrir o arquivo e clicar em "emulate" (aritmet.inc na mesma pasta)
;==============================================================================
.MODEL SMALL
.STACK 200h

CR      EQU 13
LF      EQU 10
TAM_MAX EQU 11                  ;'-' + 10 digitos

.DATA
    linha   DB '==============================================================',CR,LF,'$'
    msg_cab DB '          + - Calculadora x /   (Assembly 8086)',CR,LF,'$'
    msg_inf DB CR,LF,'Aceita numeros inteiros de -2147483648 a 2147483647.',CR,LF
            DB 'Multiplicacao e divisao feitas sem MUL e sem DIV.',CR,LF,CR,LF
            DB 'ENTER confirma o numero, BACKSPACE apaga o ultimo digito',CR,LF
            DB 'e ESC volta para este menu.',CR,LF,CR,LF
            DB 'Escolha a operacao digitando um dos numeros em parenteses:',CR,LF,'$'
    msg_menu DB '-> Adicao (1)',CR,LF,'-> Subtracao (2)',CR,LF,'-> Multiplicacao (3)',CR,LF
             DB '-> Divisao (4)',CR,LF,'-> Encerrar Programa (5)',CR,LF,'$'
    msg_opc DB 'Opcao: ','$'
    msg_n1  DB CR,LF,CR,LF,'Primeiro Numero: ','$'
    msg_n2  DB CR,LF,'Segundo Numero: ','$'
    msg_dv1 DB CR,LF,CR,LF,'Dividendo: ','$'
    msg_dv2 DB CR,LF,'Divisor: ','$'
    msg_res DB CR,LF,CR,LF,'Resultado: ','$'
    msg_quo DB CR,LF,CR,LF,'Quociente: ','$'
    msg_rst DB CR,LF,'Resto: ','$'
    msg_zer DB CR,LF,'Nao eh possivel dividir por zero. Digite outro divisor.','$'
    msg_est DB CR,LF,CR,LF,'Erro: o resultado ultrapassa o limite de 32 bits',CR,LF
            DB '(-2147483648 a 2147483647).','$'
    msg_mais DB CR,LF,CR,LF,'==============================================================',CR,LF
             DB 'Deseja realizar outra operacao?',CR,LF,'-> Digite (s) para continuar',CR,LF
             DB '-> Pressione qualquer outra tecla para finalizar',CR,LF
             DB '==============================================================',CR,LF
             DB 'Opcao: ','$'
    msg_fim DB CR,LF,CR,LF,'Programa Encerrado',CR,LF,'$'
    apaga   DB 8,' ',8,'$'      ;backspace visual: volta, escreve espaco, volta

    operacao DB ?               ;'1' a '4'
    num1    DD ?                ;primeiro numero
    num2    DD ?                ;segundo numero
    buf     DB TAM_MAX+1 DUP(?) ;texto digitado pelo usuario
    buflen  DW 0                ;quantidade de caracteres em buf
    saida   DB 16 DUP(?)        ;texto de um numero convertido (num2str)

.CODE

main proc
        MOV ax,@DATA            ;inicializa DS
        MOV ds,ax
        CLD

NOVAMENTE:
        MOV ax,0003h            ;modo texto 80x25 (tambem limpa a tela)
        INT 10h

        LEA dx,linha
        CALL escreve
        LEA dx,msg_cab
        CALL escreve
        LEA dx,linha
        CALL escreve
        LEA dx,msg_inf
        CALL escreve
        LEA dx,linha
        CALL escreve
        LEA dx,msg_menu
        CALL escreve
        LEA dx,linha
        CALL escreve
        LEA dx,msg_opc
        CALL escreve

LE_OPCAO:
        CALL le_tecla           ;tecla em AL (sem eco)
        CMP al,'1'
        JB  OPCAO_INVALIDA
        CMP al,'5'
        JA  OPCAO_INVALIDA
        MOV operacao,al
        CALL eco                ;mostra a opcao valida
        CMP al,'5'
        JNE LE_NUMEROS
        JMP FINALIZAR
OPCAO_INVALIDA:
        CALL bipe               ;tecla invalida: apenas apita e ignora
        JMP LE_OPCAO

LE_NUMEROS:
        LEA dx,msg_n1           ;na divisao os nomes mudam para dividendo/divisor
        CMP operacao,'4'
        JNE MOSTRA_N1
        LEA dx,msg_dv1
MOSTRA_N1:
        CALL escreve
        CALL le_numero          ;DX:AX = numero (CF = 1 se apertou ESC)
        JC  NOVAMENTE
        MOV WORD PTR num1,ax
        MOV WORD PTR num1+2,dx

PEDE_N2:
        LEA dx,msg_n2
        CMP operacao,'4'
        JNE MOSTRA_N2
        LEA dx,msg_dv2
MOSTRA_N2:
        CALL escreve
        CALL le_numero
        JNC N2_LIDO             ;(JC direto passaria do alcance de 128 bytes do 8086)
        JMP NOVAMENTE
N2_LIDO:
        MOV WORD PTR num2,ax
        MOV WORD PTR num2+2,dx

        CMP operacao,'4'        ;divisao por zero? pede outro divisor
        JNE CALCULA
        OR  ax,dx
        JNZ CALCULA
        LEA dx,msg_zer
        CALL escreve
        JMP PEDE_N2

CALCULA:
        MOV ax,WORD PTR num1    ;A = DX:AX
        MOV dx,WORD PTR num1+2
        MOV bx,WORD PTR num2    ;B = CX:BX
        MOV cx,WORD PTR num2+2

        CMP operacao,'1'
        JNE NAO_SOMA
        CALL soma32
        JMP MOSTRA_RESULTADO
NAO_SOMA:
        CMP operacao,'2'
        JNE NAO_SUBTRAI
        CALL subtrai32
        JMP MOSTRA_RESULTADO
NAO_SUBTRAI:
        CMP operacao,'3'
        JNE DIVIDE
        CALL mult32
        JMP MOSTRA_RESULTADO

DIVIDE:
        CALL div32              ;DX:AX = quociente, CX:BX = resto
        JC  ESTOUROU
        PUSH cx
        PUSH bx
        PUSH dx
        PUSH ax
        LEA dx,msg_quo
        CALL escreve
        POP ax
        POP dx
        CALL escreve_num
        LEA dx,msg_rst
        CALL escreve
        POP ax                  ;resto
        POP dx
        CALL escreve_num
        JMP PERGUNTA

MOSTRA_RESULTADO:
        JC  ESTOUROU            ;CF vem da rotina aritmetica
        PUSH dx
        PUSH ax
        LEA dx,msg_res
        CALL escreve
        POP ax
        POP dx
        CALL escreve_num
        JMP PERGUNTA

ESTOUROU:
        LEA dx,msg_est
        CALL escreve

PERGUNTA:
        LEA dx,msg_mais
        CALL escreve
PERGUNTA_TECLA:
        CALL le_tecla
        CMP al,0                ;tecla especial (setas, F1...) nao conta como resposta
        JE  PERGUNTA_TECLA
        CMP al,'s'              ;aceita 's' e 'S'
        JE  CONTINUA
        CMP al,'S'
        JE  CONTINUA
        CALL eco
        JMP FINALIZAR
CONTINUA:
        JMP NOVAMENTE

FINALIZAR:
        LEA dx,msg_fim
        CALL escreve
        MOV ax,4C00h            ;encerra o programa
        INT 21h
main endp

;------------------------------------------------------------------------------
; le_numero: le um numero do teclado com edicao
;   - aceita '-' somente como primeiro caractere
;   - BACKSPACE apaga o ultimo caractere
;   - ENTER confirma (precisa ter pelo menos um digito)
;   - ESC cancela: devolve CF = 1
;   - digitos que fariam o numero passar de 32 bits sao recusados (bipe)
;   saida: DX:AX = numero, CF = 0
;------------------------------------------------------------------------------
le_numero proc
        PUSH bx
        PUSH cx
        PUSH si
        MOV buflen,0
ln_tecla:
        CALL le_tecla
        CMP al,CR
        JE  ln_enter
        CMP al,8
        JE  ln_apaga
        CMP al,27
        JE  ln_esc
        CMP al,'-'
        JE  ln_menos
        CMP al,'0'
        JB  ln_invalida
        CMP al,'9'
        JA  ln_invalida

        MOV bx,buflen           ;digito
        CMP bx,TAM_MAX
        JAE ln_invalida
        MOV buf[bx],al
        PUSH ax
        LEA si,buf              ;o numero com esse digito ainda cabe em 32 bits?
        MOV cx,bx
        INC cx
        CALL str2num
        POP ax
        JC  ln_invalida
        INC buflen
        CALL eco
        JMP ln_tecla

ln_menos:
        CMP buflen,0            ;sinal so no comeco
        JNE ln_invalida
        MOV buf,al
        MOV buflen,1
        CALL eco
        JMP ln_tecla

ln_apaga:
        CMP buflen,0
        JE  ln_invalida
        DEC buflen
        LEA dx,apaga
        CALL escreve
        JMP ln_tecla

ln_enter:
        MOV cx,buflen           ;precisa ter ao menos um digito
        JCXZ ln_invalida
        CMP cx,1
        JNE ln_converte
        CMP buf,'-'
        JE  ln_invalida
ln_converte:
        LEA si,buf
        CALL str2num            ;ja foi validado digito a digito, entao cabe
        CLC
        JMP ln_sai

ln_esc:
        STC
        JMP ln_sai

ln_invalida:
        CALL bipe
        JMP ln_tecla

ln_sai:
        POP si
        POP cx
        POP bx
        RET
le_numero endp

;------------------------------------------------------------------------------
; le_tecla: espera uma tecla sem eco e devolve em AL.
;   Teclas especiais (setas, F1, Delete...) chegam como 0 + codigo; o codigo
;   extra e consumido aqui e AL volta 0, para nao ser confundido com letra.
;------------------------------------------------------------------------------
le_tecla proc
        MOV ah,08h
        INT 21h
        CMP al,0
        JNE lt_sai
        MOV ah,08h              ;descarta o segundo byte da tecla especial
        INT 21h
        XOR al,al
lt_sai:
        RET
le_tecla endp

;------------------------------------------------------------------------------
; eco: escreve o caractere de AL na tela (preserva AX e DX)
;------------------------------------------------------------------------------
eco proc
        PUSH ax
        PUSH dx
        MOV dl,al
        MOV ah,02h
        INT 21h
        POP dx
        POP ax
        RET
eco endp

;------------------------------------------------------------------------------
; bipe: apita (caractere BEL) para indicar tecla invalida
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

;------------------------------------------------------------------------------
; escreve: imprime a string (terminada em '$') apontada por DS:DX
;------------------------------------------------------------------------------
escreve proc
        PUSH ax
        MOV ah,09h
        INT 21h
        POP ax
        RET
escreve endp

;------------------------------------------------------------------------------
; escreve_num: imprime DX:AX (com sinal) em decimal
;------------------------------------------------------------------------------
escreve_num proc
        PUSH cx
        PUSH dx
        PUSH di
        LEA di,saida
        CALL num2str
        LEA dx,saida
        CALL escreve
        POP di
        POP dx
        POP cx
        RET
escreve_num endp

        INCLUDE aritmet.inc     ;soma32, subtrai32, mult32, div32, num2str, str2num

end main
