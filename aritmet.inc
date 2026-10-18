;==============================================================================
; ARITMET.INC - Rotinas aritmeticas de 32 bits para 8086 SEM MUL/IMUL/DIV/IDIV
;==============================================================================
; Compartilhado por Calculadora.asm (modo texto) e CalcGUI.asm (modo grafico).
; Deve ser incluido DENTRO do segmento de codigo (.CODE).
;
; Convencao de registradores (o 8086 so tem registradores de 16 bits, entao
; cada numero de 32 bits ocupa um PAR de registradores):
;   numero A  ->  DX:AX   (DX = 16 bits altos, AX = 16 bits baixos)
;   numero B  ->  CX:BX   (CX = 16 bits altos, BX = 16 bits baixos)
;
; Todos os numeros sao inteiros COM SINAL (complemento de 2):
;   de -2147483648 ate 2147483647
;
; Toda rotina que pode falhar devolve CF = 1 em caso de erro
; (estouro / divisao por zero) e CF = 0 em caso de sucesso.
;==============================================================================

;------------------------------------------------------------------------------
; neg_dxax: DX:AX = -DX:AX  (troca o sinal de um numero de 32 bits)
;------------------------------------------------------------------------------
neg_dxax proc
        NEG dx                  ;nega a parte alta
        NEG ax                  ;nega a parte baixa (CF = 1 se AX era diferente de 0)
        SBB dx,0                ;se a parte baixa nao era zero, corrige a parte alta
        RET
neg_dxax endp

;------------------------------------------------------------------------------
; soma32: DX:AX = DX:AX + CX:BX        CF = 1 se o resultado nao couber
;------------------------------------------------------------------------------
soma32 proc
        ADD ax,bx               ;soma as partes baixas
        ADC dx,cx               ;soma as partes altas + o "vai um" da parte baixa
        JO  s32_estouro         ;OF = 1 -> resultado com sinal estourou 32 bits
        CLC
        RET
s32_estouro:
        STC
        RET
soma32 endp

;------------------------------------------------------------------------------
; subtrai32: DX:AX = DX:AX - CX:BX     CF = 1 se o resultado nao couber
;------------------------------------------------------------------------------
subtrai32 proc
        SUB ax,bx               ;subtrai as partes baixas
        SBB dx,cx               ;subtrai as partes altas e o "empresta um"
        JO  sb32_estouro
        CLC
        RET
sb32_estouro:
        STC
        RET
subtrai32 endp

;------------------------------------------------------------------------------
; mult32: DX:AX = DX:AX * CX:BX        CF = 1 se o resultado nao couber
;
; Algoritmo "desloca e soma" (o mesmo que fazemos no papel, so que em binario):
;   produto = 0
;   enquanto multiplicador != 0:
;       se o bit 0 do multiplicador for 1: produto = produto + multiplicando
;       multiplicador = multiplicador >> 1
;       multiplicando = multiplicando << 1
; O sinal e tratado a parte: multiplicamos os valores absolutos e no final
; aplicamos o sinal (negativo se os sinais forem diferentes).
;------------------------------------------------------------------------------
mult32 proc
        PUSH si
        PUSH di
        PUSH bp

        MOV bp,dx               ;bit 15 de BP = sinal(A) XOR sinal(B) = sinal do resultado
        XOR bp,cx

        TEST dx,8000h           ;A negativo? usa o valor absoluto
        JZ  m_a_positivo
        CALL neg_dxax
m_a_positivo:
        TEST cx,8000h           ;B negativo? usa o valor absoluto
        JZ  m_b_positivo
        NEG cx
        NEG bx
        SBB cx,0
m_b_positivo:
        ;multiplicando = DX:AX, multiplicador = CX:BX, produto = DI:SI
        XOR si,si
        XOR di,di

m_laco:
        TEST bx,bx              ;multiplicador == 0? entao acabou
        JNZ m_continua
        TEST cx,cx
        JZ  m_fim
m_continua:
        TEST bx,1               ;bit 0 do multiplicador
        JZ  m_sem_soma
        ADD si,ax               ;produto = produto + multiplicando
        ADC di,dx
        JC  m_estouro           ;passou de 32 bits
m_sem_soma:
        SHR cx,1                ;multiplicador = multiplicador >> 1 (32 bits)
        RCR bx,1
        TEST bx,bx              ;se o multiplicador zerou nao precisa deslocar mais
        JNZ m_desloca
        TEST cx,cx
        JZ  m_fim
m_desloca:
        SHL ax,1                ;multiplicando = multiplicando << 1 (32 bits)
        RCL dx,1
        JC  m_estouro           ;ainda ha bits no multiplicador -> o produto nao cabe
        JMP m_laco

m_fim:
        ;DI:SI = |A| * |B| (sem sinal). Cabe se for <= 7FFFFFFFh,
        ;ou exatamente 80000000h quando o resultado for negativo.
        TEST di,8000h
        JZ  m_cabe
        TEST bp,8000h
        JZ  m_estouro
        CMP di,8000h
        JNE m_estouro
        TEST si,si
        JNZ m_estouro
m_cabe:
        MOV ax,si
        MOV dx,di
        TEST bp,8000h           ;aplica o sinal do resultado
        JZ  m_ok
        CALL neg_dxax
m_ok:
        CLC
        JMP m_sai
m_estouro:
        STC
m_sai:
        POP bp
        POP di
        POP si
        RET
mult32 endp

;------------------------------------------------------------------------------
; div32: divide DX:AX (dividendo) por CX:BX (divisor)
;   saida: DX:AX = quociente, CX:BX = resto
;   CF = 1 se o divisor for zero ou se o quociente nao couber (-2147483648 / -1)
;
; Algoritmo de divisao com restauracao (a "divisao longa" do papel, em binario),
; 32 iteracoes, um bit do quociente por vez:
;   resto = 0
;   para cada bit do dividendo, do mais alto para o mais baixo:
;       resto = (resto << 1) | proximo bit do dividendo
;       se resto >= divisor: resto = resto - divisor; bit do quociente = 1
; O quociente e truncado em direcao ao zero e o resto tem o sinal do dividendo
; (mesma regra do C / Java):  -7 / 2 = -3 resto -1
;------------------------------------------------------------------------------
div32 proc
        TEST bx,bx              ;divisor == 0?
        JNZ d_divisor_ok
        TEST cx,cx
        JNZ d_divisor_ok
        STC                     ;divisao por zero
        RET
d_divisor_ok:
        PUSH si
        PUSH di
        PUSH bp

        MOV si,dx               ;bit 15 = sinal do quociente (sinal(A) XOR sinal(B))
        XOR si,cx
        PUSH si
        PUSH dx                 ;bit 15 = sinal do resto (mesmo sinal do dividendo)

        TEST dx,8000h           ;trabalha com os valores absolutos
        JZ  d_a_positivo
        CALL neg_dxax
d_a_positivo:
        TEST cx,8000h
        JZ  d_b_positivo
        NEG cx
        NEG bx
        SBB cx,0
d_b_positivo:
        ;DX:AX = dividendo (vira o quociente), CX:BX = divisor, DI:SI = resto
        XOR si,si
        XOR di,di
        MOV bp,32               ;32 bits -> 32 iteracoes

d_laco:
        SHL ax,1                ;desloca o conjunto  resto:dividendo  1 bit para a esquerda
        RCL dx,1                ;(o bit mais alto do dividendo entra no resto)
        RCL si,1
        RCL di,1
        CMP di,cx               ;resto >= divisor ? (comparacao sem sinal de 32 bits)
        JB  d_menor
        JA  d_subtrai
        CMP si,bx
        JB  d_menor
d_subtrai:
        SUB si,bx               ;resto = resto - divisor
        SBB di,cx
        OR  al,1                ;bit do quociente = 1
d_menor:
        DEC bp
        JNZ d_laco

        POP bp                  ;sinal do resto
        TEST bp,8000h
        JZ  d_resto_positivo
        NEG di
        NEG si
        SBB di,0
d_resto_positivo:
        POP bp                  ;sinal do quociente
        TEST dx,8000h           ;quociente >= 2^31 so cabe se for negativo
        JZ  d_q_cabe            ;(unico caso: -2147483648 / -1 estoura)
        TEST bp,8000h
        JZ  d_estouro
d_q_cabe:
        TEST bp,8000h
        JZ  d_q_positivo
        CALL neg_dxax
d_q_positivo:
        MOV bx,si               ;resto em CX:BX
        MOV cx,di
        CLC
        JMP d_sai
d_estouro:
        STC
d_sai:
        POP bp
        POP di
        POP si
        RET
div32 endp

;------------------------------------------------------------------------------
; Potencias de 10 usadas na conversao para texto (ficam no segmento de codigo)
;------------------------------------------------------------------------------
pot10   DD 1000000000, 100000000, 10000000, 1000000, 100000
        DD 10000, 1000, 100, 10, 1

;------------------------------------------------------------------------------
; num2str: converte DX:AX (com sinal) em texto decimal
;   entrada: DS:DI = buffer (minimo 12 bytes)
;   saida:   buffer = "-123...$"  (terminado em '$', pronto para INT 21h/09h)
;            CX = quantidade de caracteres (sem contar o '$')
;
; Sem DIV: cada digito e obtido contando quantas vezes conseguimos subtrair
; a potencia de 10 correspondente (no maximo 9 subtracoes por digito).
;------------------------------------------------------------------------------
num2str proc
        PUSH ax
        PUSH bx
        PUSH dx
        PUSH si
        PUSH di

        MOV bx,di               ;guarda o inicio do buffer (para calcular o tamanho)
        TEST dx,8000h
        JZ  n_positivo
        MOV BYTE PTR [di],'-'
        INC di
        CALL neg_dxax           ;agora DX:AX e o valor absoluto (sem sinal)
n_positivo:
        XOR si,si               ;indice na tabela de potencias (de 4 em 4 bytes)
        MOV ch,0                ;CH = 1 quando ja escreveu algum digito (corta zeros a esquerda)
n_potencia:
        MOV cl,'0'              ;CL = digito atual, em ASCII
n_compara:
        CMP dx,WORD PTR cs:pot10[si+2]  ;DX:AX >= potencia ?
        JB  n_fim_digito
        JA  n_subtrai
        CMP ax,WORD PTR cs:pot10[si]
        JB  n_fim_digito
n_subtrai:
        SUB ax,WORD PTR cs:pot10[si]    ;DX:AX = DX:AX - potencia
        SBB dx,WORD PTR cs:pot10[si+2]
        INC cl                  ;digito + 1
        JMP n_compara
n_fim_digito:
        CMP cl,'0'
        JNE n_escreve
        CMP ch,0
        JE  n_proximo           ;zero a esquerda: nao escreve
n_escreve:
        MOV [di],cl
        INC di
        MOV ch,1
n_proximo:
        ADD si,4
        CMP si,40               ;10 potencias x 4 bytes
        JB  n_potencia

        CMP ch,0                ;o numero era zero: escreve "0"
        JNE n_termina
        MOV BYTE PTR [di],'0'
        INC di
n_termina:
        MOV BYTE PTR [di],'$'
        MOV cx,di
        SUB cx,bx               ;tamanho = fim - inicio

        POP di
        POP si
        POP dx
        POP bx
        POP ax
        RET
num2str endp

;------------------------------------------------------------------------------
; str2num: converte texto decimal em numero de 32 bits com sinal
;   entrada: DS:SI = texto (so digitos, com '-' opcional no inicio)
;            CX    = quantidade de caracteres
;   saida:   DX:AX = numero;  CF = 1 se o numero nao couber em 32 bits
;
; Sem MUL: numero * 10 = numero * 8 + numero * 2 = (numero << 3) + (numero << 1)
;------------------------------------------------------------------------------
str2num proc
        PUSH bx
        PUSH cx
        PUSH si
        PUSH di
        PUSH bp

        XOR ax,ax
        XOR dx,dx
        XOR bp,bp               ;BP = 1 se o numero for negativo
        JCXZ s_ok
        CMP BYTE PTR [si],'-'
        JNE s_laco
        MOV bp,1
        INC si
        DEC cx
        JCXZ s_ok
s_laco:
        SHL ax,1                ;DX:AX = 2 * numero
        RCL dx,1
        JC  s_estouro
        MOV bx,ax               ;DI:BX = 2 * numero
        MOV di,dx
        SHL ax,1                ;DX:AX = 4 * numero
        RCL dx,1
        JC  s_estouro
        SHL ax,1                ;DX:AX = 8 * numero
        RCL dx,1
        JC  s_estouro
        ADD ax,bx               ;DX:AX = 8 * numero + 2 * numero = 10 * numero
        ADC dx,di
        JC  s_estouro
        MOV bl,[si]             ;soma o proximo digito
        SUB bl,'0'
        XOR bh,bh
        ADD ax,bx
        ADC dx,0
        JC  s_estouro
        INC si
        LOOP s_laco

        ;limite: 2147483647 (positivo) ou 2147483648 (negativo)
        TEST dx,8000h
        JZ  s_sinal
        CMP bp,0
        JE  s_estouro
        CMP dx,8000h
        JNE s_estouro
        CMP ax,0
        JNE s_estouro
s_sinal:
        CMP bp,0
        JE  s_ok
        CALL neg_dxax
s_ok:
        CLC
        JMP s_sai
s_estouro:
        STC
s_sai:
        POP bp
        POP di
        POP si
        POP cx
        POP bx
        RET
str2num endp
