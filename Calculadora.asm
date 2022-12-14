TITLE NOME: JEAN OKABE REZENDE PITON | RA: 22013310 ||| NOME: MATHEUS ZANON CARITÁ | RA: 22014203
.MODEL SMALL                            
.DATA                                   
    msg1 DB 10,'==============================================================',10,'Primeiro Numero: ','$'            
    msg2 DB 10,'Segundo Numero: ','$'      
    msg3 DB 10,'Quociente: ','$'
    msg4 DB 'Resto: ','$'   
    msg5 DB 10,'==============================================================',10,'+ - Calculadora x /',10,10,'Sao aceitos somente numeros de um digito (entre 0 e 9)','$'
    msg6 DB 10,'==============================================================',10,'-> Adicao (1)',10,'-> Subtracao (2)',10,'-> Multiplicacao (3)',10,'-> Divisao (4)',10,'-> Encerrar Programa (5)',10,'==============================================================',10,'Opcao: ','$'
    msg7 DB 10,10,'==============================================================',10,'Deseja realizar outra operacao?',10,'-> Digite (s) para continuar',10,'-> Pressione qualquer tecla para finalizar',10,'==============================================================',10,'Opcao: ','$'
    msg8 DB 10,'Resultado: ','$'
    msg9 DB 10,'Programa Encerrado','$'
    msg10 DB 10,10,'Obs: Nao eh possivel dividir numeros por zero.',10,10,'Escolha o dividendo e o divisor, nesta ordem.',10,'$'
    msg11 DB 10,10,'Nao utilize o ENTER do teclado, o programa realiza',10,'as operacoes automaticamente',10,10,'Nao utilize o BACKSPACE (Apagar) do teclado',10,'o programa ignora a digitacao incorreta.',10,10,'Escolha a operacao digitando um dos numeros em parenteses:','$'
    var1 DB ?                    ;variavel que armazena o primeiro numero digitado pelo usuario
    var2 DB ?                    ;variavel que armazena o segundo numero digitado pelo usuario
    aux1 DB ?                    ;variavel auxiliar para evitar conflitos no programa entre os registradores
    aux2 DB ?                    ;variavel auxiliar para evitar conflitos no programa entre os registradores
.CODE

    main proc
        MOV ax,@DATA            ;inicializa o data
        MOV ds,ax

    NOVAMENTE:                  ;repeticao caso o usuario tenha pressionado (s) e queira fazer outra operacao
        MOV ax,03               ;apaga o conteúdo da tela
        INT 10h                 
        XOR ax,ax

        MOV ah,09h              ;funcao imprimir string
        LEA dx,msg5             ;msg5 string calculadora e escolha de operacao
        INT 21h

        LEA dx,msg11
        INT 21h
       
        LEA dx,msg6             ;msg6 string operandos de 1 a 5
        INT 21h
        
    INVALIDO1:
        MOV ah,01h              ;escolha entre 1 e 5
        INT 21h

        CMP al,49               ;a partir deste ponto, o programa compara se o valor digitado eh menor que
        JL INVALIDO1            ;49 (digito 1 na tabela ascii) e maior que 53 (digito 5 na tabela ascii)
        CMP al,53
        JG INVALIDO1            ;fim da comparacao
    
        CMP al,49               ;a partir deste ponto, o programa faz a checagem de qual eh a operacao desejada pelo
        JE SOMAR                ;usuario, sendo: 49 = 1 (adicao), 50 = 2 (subtracao), 51 = 3 (multiplicacao)
                                ;52 = 4 (divisao) e 53 = 5 (encerra o programa) Obs: 49 a 53 = repersentacoes da tabela ascii    
        CMP al,50               
        JE TIRAR                

        CMP al,51
        JE MULTIPLICAR

        CMP al,52
        JE DIVIDIR

        CMP al,53
        JE FINALIZAR           ;fim da checagem

    
    SOMAR:
        CALL adicao                 ;chama o procedimento que realiza a adicao
        CALL msg_outra_operacao     ;chama o procedimento que pergunta ao usuario se ele deseja fazer outra operacao
                                    ;(s) para sim e nao para qualquer outra tecla digitada

        MOV ah,01h                  ;coleta o caractere digitado pelo usuario, que vai para al
        INT 21h

        CMP al,115                  ;compara se al = 115 (representacao do "s" na tabela ascii)
        JE NOVAMENTE                ;se sim, repete
        JMP FINALIZAR               ;caso contrario, finaliza

    TIRAR:
        CALL subtracao              ;chama o procedimento que realiza a subtracao
        CALL msg_outra_operacao     ;chama o procedimento de continuacao do programa (citado anteriormente em "SOMAR:")

        MOV ah,01h
        INT 21h

        CMP al,115                  ;realiza a comparacao se al = 115 (citado anteriormente em "SOMAR:")
        JE NOVAMENTE
        JMP FINALIZAR

    MULTIPLICAR:
        CALL multiplicacao          ;chama o procedimento que realiza a multiplicacao
        CALL msg_outra_operacao     ;chama o procedimento de continuacao do programa (citado anteriormente em "SOMAR:")

        MOV ah,01h
        INT 21h

        CMP al,115                 ;realiza a comparacao se al = 115 (citado anteriormente em "SOMAR:")
        JE NOVAMENTE
        JMP FINALIZAR

    
    DIVIDIR:
        CALL divisao                ;chama o procedimento que realiza a divisao
        CALL msg_outra_operacao     ;chama o procedimento de continuacao do programa (citado anteriormente em "SOMAR:")

        MOV ah,01h
        INT 21h

        CMP al,115                  ;realiza a comparacao se al = 115 (citado anteriormente em "SOMAR:")
        JE NOVAMENTE
        JMP FINALIZAR
        
    FINALIZAR:    
        LEA dx,msg9                ;faz a leitura da mensagem de encerramento e exibe para o usuario
        MOV ah,09h
        INT 21h
        MOV ah,4ch                 ;finalizacao do programa
        INT 21h
    main endp                      ;fim da main

    ;procedimento adicao
    adicao proc
        CALL input                 ;chama o procedimento input, que coleta do usuario os numeros que serao utilizados na operacao      
        
        XOR ax,ax                  ;limpa o registrador ax (ah e al)

        MOV al,var1                ;move o primeiro numero (que estava em var1) para al
        ADD al,var2                ;faz a subtracao entre al (primeiro numero) e var2 (segundo numero armazenado na variavel)
        

        MOV bl,10                  ;move o valor 10 para bl
        DIV bl                     ;realiza a divisao por 10 (o quociente fica em al e o resto em ah)

        MOV bx,ax                  ;move o quociente e o resto para bx (bl e bh, respectivamente)

        CALL quebra_linha          ;chama procedimento de quebra de linha (estetico)
        CALL msg_resultado         ;chama procedimento que imprime a mensagem resultado (estetico)

        MOV dl,bl                  ;move o quociente de bl para dl
        ADD dl,30h                 ;transforma em caractere, para imprimir
        MOV ah,02h                 ;imprime primeiro caractere
        INT 21h

        MOV dl,bh                  ;move o resto da divisao de bh para dl
        ADD dl,30h                 ;transforma em caractere
        MOV ah,02h                 ;imprime o segundo caractere, formando o resultado total da adicao para o usuario
        INT 21h
        RET                        ;retorna as operacoes realizadas no procedimento para quando for chamado
    adicao endp                    ;fim do procedimento de adicao

    ;procedimento subtracao
    subtracao proc
        CALL input                 ;chama o procedimento input, que coleta do usuario os numeros que serao utilizados na operacao

        MOV bl,var1                ;move o primeiro numero (que estava em var1) para bl
        SUB bl,var2                ;faz a subtracao entre bl (primeiro numero) e var2 (segundo numero armazenado na variavel)

        JNS POSITIVO               ;realiza o jump se o numero for positivo

        CALL quebra_linha          ;procedimento estetico
        CALL msg_resultado         ;procedimento estetico

        MOV dl,'-'                 ;dl recebe o sinal '-', que torna a representacao amigavel ao usuario (estetico)
        MOV ah,02h                 ;imprime o '-'
        INT 21h
        NEG bl                     ;troca o sinal de bl, necessario para adicionar 30h e imprimir o resultado correto na tela
        
        JMP NEGATIVO               ;realiza o jump para nao repetir a quebra de linha em 'positivo'

    POSITIVO:                      ;caso o resultado da operacao seja positivo, o salto eh feito ate aqui 
        CALL quebra_linha
        CALL msg_resultado

    NEGATIVO:
        ADD bl,30h                 ;adiciona 30h ao resultado armazenado em bl, transformando em caractere para imprimir
        MOV dl,bl                  ;move para dl
        MOV ah,02h                 ;imprime o valor na tela
        INT 21h             
        RET                        ;retorna as operacoes realizadas no procedimento para quando for chamado
    subtracao endp                 ;fim do procedimento de subtracao

    ;procedimento multiplicacao
    multiplicacao proc
        MOV cl,4                   ;contador

        CALL input

        CALL quebra_linha          ;procedimento estetico
        CALL msg_resultado         ;procedimento estetico

        XOR bx,bx                  ;limpa bx por precaução

        MOV bh,var1                ;Multiplicando
        MOV bl,var2                ;Multiplicador/Produto

        SHL bh,4                   ;joga o numero para os 4 primeiros bits do registrador

    MULT:
        TEST bl,01h                ;testa o ultimo bit do multiplicador, se for igual a 1 o multiplicando deve ser somado ao produto, caso contrário nada acontece
        JZ ZERO
        ADD bl,bh                  ;soma do multiplicando ao produto
    ZERO:
        SHR bl,1                   ;prepara o multiplicador para o próximo test e o produto para a próxima soma/resultado
        DEC cl
        JNZ MULT

        XOR ax,ax                  ;zera ax só pra ter certeza de que ah vai estar vazio
        MOV al,bl
        MOV bh,10       
        DIV bh                     ;binario para decimal
        MOV bl,ah                  ;unidade

        MOV ah,2h
        MOV dl,al                  ;dezena
        ADD dl,30h
        INT 21h
        mov dl,bl
        ADD dl,30h
        INT 21h
        RET
    multiplicacao endp
    
    ;procedimento divisao
    divisao proc
    TENTE_NOVAMENTE:
        LEA dx,msg10
        MOV ah,09h
        INT 21h
        XOR ax,ax
        XOR dx,dx

        CALL input

        ADD var2,30h                ;transforma var2 (segundo numero escolhido pelo usuario, que eh o divisor) 
        CMP var2,48                 ;em caractere para comparar com 48 (zero na tabela ascii)
        JE TENTE_NOVAMENTE          ;se for igual a zero, o usuario tera que escolher outro numero, pois eh impossivel dividir por zero

        SUB var2,30h

        MOV bl,var1                 ;dividendo/resto
        MOV bh,var2                 ;divisor
        MOV ch,4                    ;loop

        CALL quebra_linha

        CMP bh,bl                   
        JG MAIOR                    ;caso o divisor seja maior que o dividendo os dados serão analisados
    N9:
        SHL bh,4
        SHL bl,1
    DIVI:
        SUB bl,bh                   ;compara se o dividendo é maior que o divisor
        CMP bl,0
        JGE D1                      ;se o dividendo é maior que o divisor move o quociente 1 a esquerda e adiciona 1
        ADD bl,bh
        SHL bl,1
        JMP D0                      ;se o dividendo é menor desfaz a subtração e apenas move o quociente 1 a esquerda
    D1:
        SHL bl,1
        ADD bl,1
    D0:
        DEC ch
        JNZ DIVI

        MOV al,bl
        AND al,0F0H                 ;bl contem o quociente nos 4 bits da direita e o resto nos 4 bits da esquerda, al recebe o resto e bl mantem apenas o quociente
        SHR al,5
        AND bl,0FH
    PRINT:
        MOV aux1,bl
        MOV aux2,al

        CALL msg_quociente

        MOV AH,2                    ;coloca 02h
        MOV dl,aux1
        MOV bl,aux2
        ADD dl,30h                  ;inicio transforma em caractere
        INT 21h                     ;executa

        CALL quebra_linha
        CALL msg_resto

        MOV ah,02h
        MOV dl,aux2
        ADD dl,30h
        INT 21h
        RET

    MAIOR:                          ;caso o divisor seja 9 e o dividendo não seja 9 o programa não da o resultado correto por conta de overflow
        CMP bh,9
        JNZ N9
        MOV al,0                    ;X menor que 9 dividido por 9 resulta em quociente 0 e resto X
        XCHG al,bl
        JMP PRINT
    divisao ENDP
    
    ;procedimento input
    input proc
        LEA dx,msg1                     ;escreve a mensagem requisitando o primeiro numero
        MOV ah,09h                      ;
        INT 21h                         ;executa

    REPETE_INPUT1:                      ;repeticao caso o primeiro numero digitado seja invalido
        MOV ah,01h                      ;requisita o primeiro numero
        INT 21h

        CMP al,57                       ;faz a comparacao
        JG REPETE_INPUT1                ;se o numero digitado for maior que 9 da tabela ascii (57), eh requisitado novamente

        CMP al,48                       ;faz a comparacao
        JL REPETE_INPUT1                ;se o numero digitado for menor que 0 da tabela ascii (48), eh requisitado novamente

        MOV bl,al                       ;move o primeiro numero para o registrador bl
        SUB bl,30h                      ;transforma em digito
        MOV var1,bl                     ;move o digito para var1 (variavel criada para armazenar o digito 1)

        LEA dx,msg2                     ;escreve a mensagem requisitando o segundo numero
        MOV ah,09h                      ;
        INT 21h                         ;executa

    REPETE_INPUT2:                      ;repeticao caso o segundo numero digitado seja invalido
        MOV ah,01h                      ;requisita o segundo numero
        INT 21h                         

        CMP al,57                       ;comparacao identica ao primeiro numero digitado, com o 9 (57) e o 0 (48) na tabela ascii
        JG REPETE_INPUT2

        CMP al,48
        JL REPETE_INPUT2
    
        MOV bl,al                       ;move o segundo numero para o registrador bl 
        SUB bl,30h                      ;transforma em digito
        MOV var2,bl                     ;move o digito para var2 (variavel criada para armazenar o digito 2)
        RET                             ;retorna as operacoes realizadas no procedimento para quando for chamado
    input endp                          ;fim do procedimento input
    
    quebra_linha proc                   ;procedimento estetico de quebrar linhas, evita repeticao desnecessaria no programa
        MOV dl,10                       ;move para dl o valor 10 (equivale ao caractere de quebrar linha)
        MOV ah,02h                      ;imprime o caractere e quebra a linha
        INT 21h                         ;executa
        XOR ax,ax                       ;limpa o registrador ax e dx (para evitar conflitos com outras operacoes)
        XOR dx,dx
        RET                             ;retorna as operacoes realizadas no procedimento para quando for chamado
    quebra_linha endp                   ;fim do procedimento de quebrar linhas

    msg_quociente proc                  ;procedimento feito para ser utilizado na operacao de divisao
        LEA dx,msg3                     ;o procedimento exibe a mensagem "quociente" na tela (estetica)
        MOV ah,09h
        INT 21h
        XOR ax,ax                       ;limpa os registradores ax e dx, para evitar conflitos
        XOR dx,dx
        RET                             ;retorna as operacoes realizadas no procedimento para quando for chamado
    msg_quociente endp                  ;fim do procedimento quociente

    msg_resto proc                      ;procedimento feito para ser utilizado na operacao de divisao
        LEA dx,msg4                     ;o procedimento exibe a mensagem "resto" na tela (estetico)
        MOV ah,09h
        INT 21h
        XOR ax,ax                       ;limpa os registradores ax e dx, para evitar conflitos
        XOR dx,dx
        RET                             ;retorna as operacoes realizadas no procedimento para quando for chamado
    msg_resto endp                      ;fim do procedimento resto

    msg_outra_operacao proc             ;procedimento feito para perguntar ao usuario se ele deseja realizar
        LEA dx,msg7                     ;outra operacao (estetico). o procedimento evita repeticoes desnecessarias
        MOV ah,09h
        INT 21h
        XOR ax,ax                       ;limpa os registradores ax e dx, para evitar conflitos
        XOR dx,dx
        RET                             ;retorna as operacoes realizadas no procedimento para quando for chamado
    msg_outra_operacao endp             ;fim do procedimento

    msg_resultado proc                  ;procedimento feito exibir a mensagem "resultado" na tela (estético)
        LEA dx,msg8                     ;o procedimento evita repeticoes desnecessarias
        MOV ah,09h
        INT 21h
        XOR ax,ax                       ;limpa os registradores ax e dx, para evitar conflitos
        XOR dx,dx
        RET                             ;retorna as operacoes realizadas no procedimento para quando for chamado
    msg_resultado endp                  ;fim do procedimento 

end main                                ;fecha o programa principal
