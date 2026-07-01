    .global main

    .section .data
        fmt_input_real:     .asciz "%lf"
        fmt_input_char:     .asciz " %c"
        fmt_input_int:      .asciz "%ld"
        fmt_resultado:      .asciz "Resultado: %.10g\n"
        fmt_continuar:      .asciz "Deseja continuar? (s/n): "
        fmt_continuar_input:.asciz " %c"
        fmt_erro_div:       .asciz "Erro: divisao por zero nao e possivel.\n"
        fmt_erro_neg:       .asciz "Erro: operacao nao suportada para operandos negativos ou nao inteiros.\n"
        fmt_erro_comb:      .asciz "Erro: n deve ser maior ou igual a r.\n"
        fmt_erro_sqrt:      .asciz "Erro: raiz quadrada de numero negativo nao e possivel.\n"
        fmt_erro_inv:       .asciz "Erro: inverso de zero nao e possivel.\n"
        fmt_erro_log:       .asciz "Erro: logaritmando deve ser > 0 e base positiva diferente de 1.\n"
        fmt_erro_op:        .asciz "Erro: operador invalido.\n"
        fmt_op1:            .asciz "Digite o primeiro operando: "
        fmt_op2:            .asciz "Digite o segundo operando: "
        fmt_operador:       .asciz "Digite o operador (+,-,*,/,^,c,a,!,i,r,l,p): "
        fmt_primo:          .asciz "Resultado: %ld\n"
        .one:   .double 1.0


    .section .bss
        .lcomm      op1,8
        .lcomm      op2,8
        .lcomm      op2_tmp,8
        .lcomm      operador,1
        .lcomm      resposta,1
        .lcomm      tmp_int,8

    .section .text


main:
    pushq %rbp
    movq %rsp, %rbp
    # preserve callee-saved
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    subq $8, %rsp    # align

.loop_principal:
    # Ler primeiro operando
    movq $fmt_op1, %rdi
    call ler_operando
    movsd %xmm0, op1(%rip)

    # Ler operador
    movq $fmt_operador, %rdi
    movq $0, %rax
    call printf

    movq $fmt_input_char, %rdi
    leaq operador(%rip), %rsi
    movq $0, %rax
    call scanf

    movb operador(%rip), %bl

    # Verifica se operador precisa de segundo operando
    # +,-,*,/,^,c,a,l precisam de 2 operandos
    cmpb $'+', %bl
    je .ler_op2
    cmpb $'-', %bl
    je .ler_op2
    cmpb $'*', %bl
    je .ler_op2
    cmpb $'/', %bl
    je .ler_op2
    cmpb $'^', %bl
    je .ler_op2
    cmpb $'c', %bl
    je .ler_op2
    cmpb $'a', %bl
    je .ler_op2
    cmpb $'l', %bl
    je .ler_op2
    jmp .calcular

.ler_op2:
    movq $fmt_op2, %rdi
    call ler_operando
    movsd %xmm0, op2(%rip)

.calcular:
    movb operador(%rip), %bl

    cmpb $'+', %bl
    je .op_soma
    cmpb $'-', %bl
    je .op_sub
    cmpb $'*', %bl
    je .op_mul
    cmpb $'/', %bl
    je .op_div
    cmpb $'^', %bl
    je .op_pow
    cmpb $'c', %bl
    je .op_comb
    cmpb $'a', %bl
    je .op_arr
    cmpb $'!', %bl
    je .op_fat
    cmpb $'i', %bl
    je .op_inv
    cmpb $'r', %bl
    je .op_sqrt
    cmpb $'l', %bl
    je .op_log
    cmpb $'p', %bl
    je .op_primo
    # operador invalido
    movq $fmt_erro_op, %rdi
    movq $0, %rax
    call printf
    jmp .perguntar_continuar


# Exibe mensagem e lê um double do usuário
ler_operando:
    pushq %rbp
    movq %rsp, %rbp
    subq $16, %rsp
    movq %rdi, %r12


    movq %r12, %rdi
    movq $0, %rax
    call printf

    leaq -8(%rbp), %rsi
    movq $fmt_input_real, %rdi
    movq $0, %rax
    call scanf

    movsd -8(%rbp), %xmm0

    addq $16, %rsp
    popq %rbp
    ret






# helper: verifica se r12 é primo, retorna 1 em rax se sim
.eh_primo:
    pushq %rbx
    movq %r12, %rbx
    cmpq $2, %rbx
    jl .nao_primo
    je .eh_primo_sim
    # verifica se é par
    movq %rbx, %rax
    andq $1, %rax
    cmpq $0, %rax
    je .nao_primo
    # testa divisores de 3 a sqrt(n)
    movq $3, %rcx
.ep_loop:
    movq %rcx, %rax
    imulq %rcx, %rax
    cmpq %rbx, %rax
    jg .eh_primo_sim
    movq %rbx, %rax
    cqto
    idivq %rcx
    cmpq $0, %rdx
    je .nao_primo
    addq $2, %rcx
    jmp .ep_loop
.eh_primo_sim:
    movq $1, %rax
    popq %rbx
    ret
.nao_primo:
    movq $0, %rax
    popq %rbx
    ret



# ----- Soma -----
.op_soma:
    movsd op1(%rip), %xmm0
    addsd op2(%rip), %xmm0
    jmp .exibir_resultado

# ----- Subtração -----
.op_sub:
    movsd op1(%rip), %xmm0
    subsd op2(%rip), %xmm0
    jmp .exibir_resultado

# ----- Multiplicação -----
.op_mul:
    movsd op1(%rip), %xmm0
    mulsd op2(%rip), %xmm0
    jmp .exibir_resultado

# ----- Divisão -----
.op_div:
    # verifica divisor == 0
    xorpd %xmm1, %xmm1
    movsd op2(%rip), %xmm2
    ucomisd %xmm1, %xmm2
    je .erro_div
    movsd op1(%rip), %xmm0
    divsd op2(%rip), %xmm0
    jmp .exibir_resultado
.erro_div:
    movq $fmt_erro_div, %rdi
    movq $0, %rax
    call printf
    jmp .perguntar_continuar

# ----- Potência -----
# Observacao: assume base > 0 (caso base <= 0 fica a cargo da
# validacao feita antes de chamar esta rotina, se necessario).

.op_pow:
    movsd op1(%rip), %xmm0
    movsd op2(%rip), %xmm1
    call my_pow
    jmp .exibir_resultado

my_pow:
    pushq %rbp
    movq %rsp, %rbp
    subq $16, %rsp

    movsd %xmm1, (%rsp)    # expoente
    movsd %xmm0, 8(%rsp)   # base

    fldl (%rsp)     # st0 = expoente
    fldl 8(%rsp)    # st0 = base, st1 = expoente
    fyl2x           # st0 = expoente * log2(base), pop

    # calcula 2^st0 (algoritmo classico da FPU)
    fld %st(0)          # st0 = x, st1 = x
    frndint             # st0 = round(x), st1 = x
    fxch                # st0 = x, st1 = round(x)
    fsub %st(1), %st    # st0 = x - round(x) = fracao
    f2xm1               # st0 = 2^fracao - 1
    fld1
    faddp               # st0 = 2^fracao
    fscale              # st0 = 2^fracao * 2^round(x), st1 = round(x)
    fstp %st(1)         # descarta st1, mantem resultado em st0

    fstpl (%rsp)
    movsd (%rsp), %xmm0

    addq $16, %rsp
    popq %rbp
    ret


# ----- Fatorial -----
.op_fat:
    # valida: inteiro e não negativo
    movsd op1(%rip), %xmm0
    cvttsd2si %xmm0, %rax
    cvtsi2sd %rax, %xmm1
    ucomisd %xmm0, %xmm1
    jne .erro_neg_int
    cmpq $0, %rax
    jl .erro_neg_int
    movq %rax, %rdi
    call fatorial
    cvtsi2sd %rax, %xmm0
    jmp .exibir_resultado


fatorial:
    pushq %rbp
    movq %rsp, %rbp
    movq $1, %rax
    movq %rdi, %rcx
    cmpq $0, %rcx
    jle .fat_fim
.fat_loop:
    imulq %rcx, %rax
    decq %rcx
    jnz .fat_loop
.fat_fim:
    popq %rbp
    ret
# ----- Inverso -----
.op_inv:
    xorpd %xmm1, %xmm1
    movsd op1(%rip), %xmm0
    ucomisd %xmm1, %xmm0
    je .erro_inv
    movsd op1(%rip), %xmm1
    movsd .one(%rip), %xmm0
    divsd %xmm1, %xmm0
    jmp .exibir_resultado
.erro_inv:
    movq $fmt_erro_inv, %rdi
    movq $0, %rax
    call printf
    jmp .perguntar_continuar

# ----- Raiz Quadrada -----
.op_sqrt:
    xorpd %xmm1, %xmm1
    movsd op1(%rip), %xmm0
    ucomisd %xmm0, %xmm1
    ja .erro_sqrt
    sqrtsd %xmm0, %xmm0
    jmp .exibir_resultado
.erro_sqrt:
    movq $fmt_erro_sqrt, %rdi
    movq $0, %rax
    call printf
    jmp .perguntar_continuar

# ----- Logaritmo -----
.op_log:
    # log_base(op2) de op1 = ln(op1)/ln(op2)
    # op1 > 0, op2 > 0 e op2 != 1
    xorpd %xmm1, %xmm1
    movsd op1(%rip), %xmm0
    ucomisd %xmm1, %xmm0
    jbe .erro_log

    movsd op2(%rip), %xmm0
    ucomisd %xmm1, %xmm0
    jbe .erro_log
    # verifica base != 1
    movsd .one(%rip), %xmm1
    movsd op2(%rip), %xmm0
    ucomisd %xmm1, %xmm0
    je .erro_log

    movsd op1(%rip), %xmm0
    call my_log
    movsd %xmm0, op2_tmp(%rip)    # salva ln(op1) em variavel temporaria
    # ln(op2)
    movsd op2(%rip), %xmm0
    call my_log
    movsd op2_tmp(%rip), %xmm1    # recupera ln(op1)
    divsd %xmm0, %xmm1
    movsd %xmm1, %xmm0
    jmp .exibir_resultado

my_log:
    pushq %rbp
    movq %rsp, %rbp
    subq $16, %rsp

    movsd %xmm0, (%rsp)
    fldln2          # st0 = ln(2)
    fldl (%rsp)     # st0 = x, st1 = ln(2)
    fyl2x           # st0 = ln(2) * log2(x) = ln(x), pop

    fstpl (%rsp)
    movsd (%rsp), %xmm0

    addq $16, %rsp
    popq %rbp
    ret

.erro_log:
    movq $fmt_erro_log, %rdi
    movq $0, %rax
    call printf
    jmp .perguntar_continuar

# ----- Próximo Primo -----
.op_primo:
    movsd op1(%rip), %xmm0
    cvttsd2si %xmm0, %rdi
    cmpq $2, %rdi
    jge .pp_ok
    movq $2, %rdi
.pp_ok:
    call proximo_primo
    movq %rax, %rsi
    movq $fmt_primo, %rdi
    movq $0, %rax
    call printf
    jmp .perguntar_continuar

# Recebe n em rdi, retorna o próximo primo >= n em rax
proximo_primo:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13

    movq %rdi, %r12       # candidato atual
    cmpq $2, %r12
    jge .pp_testa
    movq $2, %r12
.pp_testa:
    movq %r12, %r13       # guardar para teste
    # testa se r12 é primo
    call .eh_primo
    cmpq $1, %rax
    je .pp_achou
    incq %r12
    jmp .pp_testa
.pp_achou:
    movq %r12, %rax
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret 

# ----- Combinação -----
.op_comb:
    # valida n e r inteiros não negativos, n >= r
    movsd op1(%rip), %xmm0
    cvttsd2si %xmm0, %rax
    cvtsi2sd %rax, %xmm1
    ucomisd %xmm0, %xmm1
    jne .erro_neg_int
    cmpq $0, %rax
    jl .erro_neg_int
    movq %rax, %r12   # n

    movsd op2(%rip), %xmm0
    cvttsd2si %xmm0, %rax
    cvtsi2sd %rax, %xmm1
    ucomisd %xmm0, %xmm1
    jne .erro_neg_int
    cmpq $0, %rax
    jl .erro_neg_int
    movq %rax, %r13   # r

    cmpq %r13, %r12
    jl .erro_comb

    # C(n,r) = n! / (r! * (n-r)!)
    movq %r12, %rdi
    call fatorial
    movq %rax, %r14   # n!

    movq %r13, %rdi
    call fatorial
    movq %rax, %r15   # r!

    movq %r12, %rax
    subq %r13, %rax
    movq %rax, %rdi
    call fatorial
    movq %rax, %rbx   # (n-r)!

    imulq %r15, %rbx  # r! * (n-r)!
    movq %r14, %rax
    cqto
    idivq %rbx        # n! / (r!*(n-r)!)
    cvtsi2sd %rax, %xmm0
    jmp .exibir_resultado

.erro_comb:
    movq $fmt_erro_comb, %rdi
    movq $0, %rax
    call printf
    jmp .perguntar_continuar

# ----- Arranjo -----
.op_arr:
    # valida n e r inteiros não negativos, n >= r
    movsd op1(%rip), %xmm0
    cvttsd2si %xmm0, %rax
    cvtsi2sd %rax, %xmm1
    ucomisd %xmm0, %xmm1
    jne .erro_neg_int
    cmpq $0, %rax
    jl .erro_neg_int
    movq %rax, %r12   # n

    movsd op2(%rip), %xmm0
    cvttsd2si %xmm0, %rax
    cvtsi2sd %rax, %xmm1
    ucomisd %xmm0, %xmm1
    jne .erro_neg_int
    cmpq $0, %rax
    jl .erro_neg_int
    movq %rax, %r13   # r

    cmpq %r13, %r12
    jl .erro_comb

    # A(n,r) = n! / (n-r)!
    movq %r12, %rdi
    call fatorial
    movq %rax, %r14   # n!

    movq %r12, %rax
    subq %r13, %rax
    movq %rax, %rdi
    call fatorial
    movq %rax, %rbx   # (n-r)!

    movq %r14, %rax
    cqto            # pega o bit de sinal de rax para rbx(Mudar muito confuso)
    idivq %rbx
    cvtsi2sd %rax, %xmm0
    jmp .exibir_resultado

.erro_neg_int:
    movq $fmt_erro_neg, %rdi
    movq $0, %rax
    call printf
    jmp .perguntar_continuar

# ----- Exibir resultado -----
.exibir_resultado:
    movq $fmt_resultado, %rdi
    movq $1, %rax
    call printf

# ----- Perguntar se continua -----
.perguntar_continuar:
    movq $fmt_continuar, %rdi
    movq $0, %rax
    call printf

    movq $fmt_continuar_input, %rdi
    leaq resposta(%rip), %rsi
    movq $0, %rax
    call scanf

    movb resposta(%rip), %al
    cmpb $'s', %al
    je .loop_principal
    cmpb $'S', %al
    je .loop_principal

    # encerrar
    movq $0, %rax
    addq $8, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

