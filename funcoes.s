# =====================================================================
# Operacoes da calculadora em assembly x86-64 (AT&T / GAS) SEM libc.
# Chamadas por main.s e implementadas sem funcoes da libc.
# =====================================================================

    .section .text
    .global calc_soma, calc_sub, calc_mul, calc_div, calc_pow, calc_comb
    .global calc_arr, calc_fat, calc_inv, calc_sqrt, calc_log, calc_primo
    .global fatorial, proximo_primo
    .extern op1, op2, y_mem, i_mem, int_tmp, erro_flag
    .extern zero_const, one_const
    .extern compare_doubles, is_integer_check

# =====================================================================
# calc_soma: calcula op1 + op2. Resultado em st(0).
# =====================================================================
calc_soma:
    push %rbp
    movq %rsp, %rbp
    movq $0, erro_flag(%rip)
    fldl op1(%rip)
    fldl op2(%rip)
    fadd %st(0), %st(1)
    fstp %st(0)
    movq %rbp, %rsp
    pop %rbp
    ret

# =====================================================================
# calc_sub: calcula op1 - op2. Resultado em st(0).
# =====================================================================
calc_sub:
    push %rbp
    movq %rsp, %rbp
    movq $0, erro_flag(%rip)
    fldl op1(%rip)
    fldl op2(%rip)
    fsubr %st(0), %st(1)        # st1 = st1-st0 = op1-op2 (older-newer)
    fstp %st(0)
    movq %rbp, %rsp
    pop %rbp
    ret

# =====================================================================
# calc_mul: calcula op1 * op2. Resultado em st(0).
# =====================================================================
calc_mul:
    push %rbp
    movq %rsp, %rbp
    movq $0, erro_flag(%rip)
    fldl op1(%rip)
    fldl op2(%rip)
    fmul %st(0), %st(1)
    fstp %st(0)
    movq %rbp, %rsp
    pop %rbp
    ret

# =====================================================================
# calc_div: calcula op1 / op2. Resultado em st(0). erro_flag=1 se op2=0.
# =====================================================================
calc_div:
    push %rbp
    movq %rsp, %rbp
    movq $0, erro_flag(%rip)
    leaq op2(%rip), %rdi
    leaq zero_const(%rip), %rsi
    call compare_doubles
    cmpq $0, %rax
    je .cdv_erro
    fldl op1(%rip)
    fldl op2(%rip)
    fdivr %st(0), %st(1)        # st1 = st1/st0 = op1/op2 (older/newer)
    fstp %st(0)
    jmp .cdv_fim
.cdv_erro:
    movq $1, erro_flag(%rip)
    fldz
.cdv_fim:
    movq %rbp, %rsp
    pop %rbp
    ret

# =====================================================================
# fatorial: rdi = n (int64, >=0). Retorna n! em rax.
# =====================================================================
fatorial:
    push %rbp
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
    movq %rbp, %rsp
    pop %rbp
    ret

# =====================================================================
# eh_primo: r12 = candidato. Retorna em rax: 1 se primo, 0 caso contrario.
# (funcao auxiliar de proximo_primo)
# =====================================================================
eh_primo:
    push %rbp
    movq %rsp, %rbp
    movq %r12, %rbx
    cmpq $2, %rbx
    jl .ep_nao
    je .ep_sim
    movq %rbx, %rax
    andq $1, %rax
    cmpq $0, %rax
    je .ep_nao
    movq $3, %rcx
.ep_loop:
    movq %rcx, %rax
    imulq %rcx, %rax
    cmpq %rbx, %rax
    jg .ep_sim
    movq %rbx, %rax
    cqto
    idivq %rcx
    cmpq $0, %rdx
    je .ep_nao
    addq $2, %rcx
    jmp .ep_loop
.ep_sim:
    movq $1, %rax
    jmp .ep_fim
.ep_nao:
    movq $0, %rax
.ep_fim:
    movq %rbp, %rsp
    pop %rbp
    ret

# =====================================================================
# proximo_primo: rdi = n. Retorna em rax o proximo primo >= n.
# =====================================================================
proximo_primo:
    push %rbp
    movq %rsp, %rbp
    push %r12

    movq %rdi, %r12
    cmpq $2, %r12
    jge .pp_testa
    movq $2, %r12
.pp_testa:
    call eh_primo
    cmpq $1, %rax
    je .pp_achou
    incq %r12
    jmp .pp_testa
.pp_achou:
    movq %r12, %rax
    pop %r12
    movq %rbp, %rsp
    pop %rbp
    ret

# =====================================================================
# calc_fat: calcula op1!. Resultado em st(0). erro_flag=1 se invalido.
# =====================================================================
calc_fat:
    push %rbp
    movq %rsp, %rbp
    movq $0, erro_flag(%rip)
    fldl op1(%rip)
    call is_integer_check
    fstp %st(0)
    cmpq $1, %rax
    jne .cfat_erro
    movq int_tmp(%rip), %rdi
    cmpq $0, %rdi
    jl .cfat_erro
    call fatorial
    movq %rax, int_tmp(%rip)
    fildll int_tmp(%rip)
    jmp .cfat_fim
.cfat_erro:
    movq $1, erro_flag(%rip)
    fldz
.cfat_fim:
    movq %rbp, %rsp
    pop %rbp
    ret

# =====================================================================
# calc_comb: calcula combinacao simples C(op1, op2).
# erro_flag=1 para operandos invalidos, 2 para op1 < op2.
# =====================================================================
calc_comb:
    push %rbp
    movq %rsp, %rbp
    movq $0, erro_flag(%rip)

    fldl op1(%rip)
    call is_integer_check
    fstp %st(0)
    cmpq $1, %rax
    jne .cc_erro_neg
    movq int_tmp(%rip), %r12
    cmpq $0, %r12
    jl .cc_erro_neg

    fldl op2(%rip)
    call is_integer_check
    fstp %st(0)
    cmpq $1, %rax
    jne .cc_erro_neg
    movq int_tmp(%rip), %r13
    cmpq $0, %r13
    jl .cc_erro_neg

    cmpq %r13, %r12
    jl .cc_erro_comb

    movq %r12, %rdi
    call fatorial
    movq %rax, %r14

    movq %r13, %rdi
    call fatorial
    movq %rax, %r15

    movq %r12, %rax
    subq %r13, %rax
    movq %rax, %rdi
    call fatorial
    movq %rax, %rbx

    imulq %r15, %rbx
    movq %r14, %rax
    cqto
    idivq %rbx
    movq %rax, int_tmp(%rip)
    fildll int_tmp(%rip)
    jmp .cc_fim
.cc_erro_neg:
    movq $1, erro_flag(%rip)
    fldz
    jmp .cc_fim
.cc_erro_comb:
    movq $2, erro_flag(%rip)
    fldz
.cc_fim:
    movq %rbp, %rsp
    pop %rbp
    ret

# =====================================================================
# calc_arr: calcula arranjo simples A(op1, op2).
# erro_flag=1 para operandos invalidos, 2 para op1 < op2.
# =====================================================================
calc_arr:
    push %rbp
    movq %rsp, %rbp
    movq $0, erro_flag(%rip)

    fldl op1(%rip)
    call is_integer_check
    fstp %st(0)
    cmpq $1, %rax
    jne .ca_erro_neg
    movq int_tmp(%rip), %r12
    cmpq $0, %r12
    jl .ca_erro_neg

    fldl op2(%rip)
    call is_integer_check
    fstp %st(0)
    cmpq $1, %rax
    jne .ca_erro_neg
    movq int_tmp(%rip), %r13
    cmpq $0, %r13
    jl .ca_erro_neg

    cmpq %r13, %r12
    jl .ca_erro_comb

    movq %r12, %rdi
    call fatorial
    movq %rax, %r14

    movq %r12, %rax
    subq %r13, %rax
    movq %rax, %rdi
    call fatorial
    movq %rax, %rbx

    movq %r14, %rax
    cqto
    idivq %rbx
    movq %rax, int_tmp(%rip)
    fildll int_tmp(%rip)
    jmp .ca_fim
.ca_erro_neg:
    movq $1, erro_flag(%rip)
    fldz
    jmp .ca_fim
.ca_erro_comb:
    movq $2, erro_flag(%rip)
    fldz
.ca_fim:
    movq %rbp, %rsp
    pop %rbp
    ret

# =====================================================================
# calc_inv: calcula 1 / op1. Resultado em st(0). erro_flag=1 se op1=0.
# =====================================================================
calc_inv:
    push %rbp
    movq %rsp, %rbp
    movq $0, erro_flag(%rip)
    leaq op1(%rip), %rdi
    leaq zero_const(%rip), %rsi
    call compare_doubles
    cmpq $0, %rax
    je .ci_erro
    fld1
    fldl op1(%rip)
    fdivr %st(0), %st(1)        # st1 = st1/st0 = 1.0/op1 (older/newer)
    fstp %st(0)
    jmp .ci_fim
.ci_erro:
    movq $1, erro_flag(%rip)
    fldz
.ci_fim:
    movq %rbp, %rsp
    pop %rbp
    ret

# =====================================================================
# calc_sqrt: calcula raiz quadrada de op1. erro_flag=1 se op1<0.
# =====================================================================
calc_sqrt:
    push %rbp
    movq %rsp, %rbp
    movq $0, erro_flag(%rip)
    leaq op1(%rip), %rdi
    leaq zero_const(%rip), %rsi
    call compare_doubles
    cmpq $-1, %rax
    je .csq_erro
    fldl op1(%rip)
    fsqrt
    jmp .csq_fim
.csq_erro:
    movq $1, erro_flag(%rip)
    fldz
.csq_fim:
    movq %rbp, %rsp
    pop %rbp
    ret

# =====================================================================
# calc_primo: calcula o proximo primo >= op1. Resultado em st(0).
# =====================================================================
calc_primo:
    push %rbp
    movq %rsp, %rbp
    movq $0, erro_flag(%rip)
    fldl op1(%rip)
    fisttpll int_tmp(%rip)
    movq int_tmp(%rip), %rdi
    cmpq $2, %rdi
    jge .cpr_ok
    movq $2, %rdi
.cpr_ok:
    call proximo_primo
    movq %rax, int_tmp(%rip)
    fildll int_tmp(%rip)
    movq %rbp, %rsp
    pop %rbp
    ret

# =====================================================================
# calc_log: usa op1 (logaritmando) e op2 (base) da memoria.
# Resultado em st(0). Em caso de erro de dominio: erro_flag=1.
# log_base(b) de x = log2(x) / log2(b)
# =====================================================================
calc_log:
    push %rbp
    movq %rsp, %rbp

    movq $0, erro_flag(%rip)

    # valida op1 > 0
    leaq op1(%rip), %rdi
    leaq zero_const(%rip), %rsi
    call compare_doubles
    cmpq $1, %rax
    jne .cl_erro

    # valida op2 > 0
    leaq op2(%rip), %rdi
    leaq zero_const(%rip), %rsi
    call compare_doubles
    cmpq $1, %rax
    jne .cl_erro

    # valida op2 != 1
    leaq op2(%rip), %rdi
    leaq one_const(%rip), %rsi
    call compare_doubles
    cmpq $0, %rax
    je .cl_erro

    fld1
    fldl op1(%rip)
    fyl2x                       # st0 = log2(op1)

    fld1
    fldl op2(%rip)
    fyl2x                       # st0 = log2(op2), st1 = log2(op1)

    fdivr %st(0), %st(1)        # st1 = st1_old/st0_old = log2(op1)/log2(op2)
    fstp %st(0)
    jmp .cl_fim

.cl_erro:
    movq $1, erro_flag(%rip)
    fldz
.cl_fim:
    movq %rbp, %rsp
    pop %rbp
    ret

# =====================================================================
# calc_pow: usa op1 (base) e op2 (expoente) da memoria.
# Resultado em st(0). Em caso de erro de dominio: erro_flag=1.
# =====================================================================
calc_pow:
    push %rbp
    movq %rsp, %rbp

    movq $0, erro_flag(%rip)

    fldl op2(%rip)
    call is_integer_check        # rax=1 se expoente inteiro; int_tmp=expoente truncado; st0 preservado=expoente
    cmpq $1, %rax
    je .cp_inteiro

    # expoente nao-inteiro: base deve ser > 0
    fstp %st(0)                  # descarta expoente (FPU), vamos usar memoria op1/op2 daqui
    leaq op1(%rip), %rdi
    leaq zero_const(%rip), %rsi
    call compare_doubles
    cmpq $1, %rax
    jne .cp_erro
    jmp .cp_geral

.cp_inteiro:
    fstp %st(0)                  # descarta expoente da pilha FPU (usaremos int_tmp)
    movq int_tmp(%rip), %r12     # expoente inteiro
    movq %r12, %r13
    cmpq $0, %r13
    jge .cp_exp_pos
    negq %r13
.cp_exp_pos:
    fld1                          # acumulador = 1.0
    movq %r13, %rcx
.cp_loop:
    cmpq $0, %rcx
    je .cp_loop_fim
    fldl op1(%rip)                  # st0=base, st1=acumulador
    fmul %st(0), %st(1)               # st1 = st1*st0 (comutativo)
    fstp %st(0)                       # st0 = novo acumulador
    decq %rcx
    jmp .cp_loop
.cp_loop_fim:
    cmpq $0, %r12
    jge .cp_fim
    fld1                                # st0=1.0, st1=acumulador
    fdiv %st(0), %st(1)                   # st1 = st0_old/st1_old = 1.0/acumulador (newer/older)
    fstp %st(0)
    jmp .cp_fim

.cp_geral:
    fldl op2(%rip)
    fldl op1(%rip)
    fyl2x                                  # st0 = expoente*log2(base) = y

    fstl y_mem(%rip)
    frndint                                  # st0 = i = round(y)
    fstl i_mem(%rip)

    fldl y_mem(%rip)                           # st0=y, st1=i
    fsub %st(0), %st(1)                          # st1 = y - i = f  (newer-older)
    fstp %st(0)                                    # st0 = f

    f2xm1                                            # st0 = 2^f - 1
    fld1                                                # st0=1.0, st1=(2^f-1)
    fadd %st(0), %st(1)                                   # st1 = soma (comutativo)
    fstp %st(0)                                             # st0 = 2^f

    fldl i_mem(%rip)                                          # st0=i, st1=2^f
    fxch                                                         # st0=2^f, st1=i
    fscale                                                         # st0=resultado; st1=i sobra
    fxch                                                             # st0=i, st1=resultado
    fstp %st(0)                                                        # descarta i, st0=resultado
    jmp .cp_fim

.cp_erro:
    movq $1, erro_flag(%rip)
    fldz
.cp_fim:
    movq %rbp, %rsp
    pop %rbp
    ret
