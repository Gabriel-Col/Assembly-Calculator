# =====================================================================
# Calculadora em assembly x86-64 (AT&T / GAS) SEM uso de libc.
# Nao utiliza printf, scanf, pow, log da libc.
# Entrada/saida feita via syscalls diretas (read=0, write=1, exit=60).
# Operacoes matematicas (pow, log, sqrt) implementadas com instrucoes
# nativas da FPU x87 (FYL2X, F2XM1, FSCALE, FSQRT, etc).
# =====================================================================

    .section .data

ten_const:      .double 10.0
tenth_const:    .double 0.1
one_const:      .double 1.0
zero_const:     .double 0.0

msg_op1:        .string "Digite o primeiro operando: "
msg_op2:        .string "Digite o segundo operando: "
msg_operador:   .string "Digite o operador (+,-,*,/,^,c,a,!,i,r,l,p): "
msg_resultado:  .string "Resultado: "
msg_continuar:  .string "Deseja continuar? (s/n): "
msg_nl:         .string "\n"
msg_ok:         .string "OK\n"

erro_div:       .string "Erro: divisao por zero nao e possivel.\n"
erro_neg:       .string "Erro: operacao nao suportada para operandos negativos ou nao inteiros.\n"
erro_comb:      .string "Erro: n deve ser maior ou igual a r.\n"
erro_sqrt:      .string "Erro: raiz quadrada de numero negativo nao e possivel.\n"
erro_inv:       .string "Erro: inverso de zero nao e possivel.\n"
erro_log:       .string "Erro: logaritmando deve ser > 0 e base positiva diferente de 1.\n"
erro_pow:       .string "Erro: base deve ser positiva para expoente nao inteiro.\n"
erro_op:        .string "Erro: operador invalido.\n"

    .section .bss
op1:        .skip 8
op2:        .skip 8
y_mem:      .skip 8
i_mem:      .skip 8
int_tmp:    .skip 8
mem_acc:    .skip 8
mem_place:  .skip 8
input_buf:  .skip 128
output_buf: .skip 64
operador:   .skip 2
erro_flag:  .skip 8
io_buffer:  .skip 256
io_buf_pos: .skip 8
io_buf_len: .skip 8
var_values: .skip 208
var_set:    .skip 26
func_set:   .skip 26
func_param: .skip 26
func_body:  .skip 1664
eval_pos:   .skip 8
func_arg:   .skip 8
active_param: .skip 1

    .section .text
    .global _start
    .global op1, op2, y_mem, i_mem, int_tmp, erro_flag
    .global zero_const, one_const
    .global compare_doubles, is_integer_check
    .extern calc_soma, calc_sub, calc_mul, calc_div, calc_pow, calc_comb
    .extern calc_arr, calc_fat, calc_inv, calc_sqrt, calc_log, calc_primo

# =====================================================================
# print_cstr: rdi = endereco de string terminada em NUL (0)
# Escreve a string na saida padrao (stdout) via syscall write.
# =====================================================================
print_cstr:
    push %rbp
    movq %rsp, %rbp
    movq %rdi, %r12
    xorq %r13, %r13
.pc_strlen:
    cmpb $0, (%r12, %r13, 1)
    je .pc_write
    incq %r13
    jmp .pc_strlen
.pc_write:
    movq %r13, %rdx
    movq %r12, %rsi
    movq $1, %rax
    movq $1, %rdi
    syscall
    movq %rbp, %rsp
    pop %rbp
    ret

# =====================================================================
# print_buf: rdi = endereco do buffer, rdx = quantidade de bytes
# =====================================================================
print_buf:
    push %rbp
    movq %rsp, %rbp
    movq %rdi, %rsi
    movq $1, %rax
    movq $1, %rdi
    syscall
    movq %rbp, %rsp
    pop %rbp
    ret

# =====================================================================
# read_line: rdi = buffer destino, rdx = tamanho maximo do destino
# Le uma linha via um buffer interno (io_buffer), que pode conter
# varias linhas de uma so vez quando a entrada vem de um pipe (a
# chamada read() nao garante uma linha por vez quando nao eh um
# terminal). Retorna em rax o numero de caracteres da linha lida
# (sem contar o '\n'); o destino fica terminado em NUL (0).
# =====================================================================
read_line:
    push %rbp
    movq %rsp, %rbp
    movq %rdi, %r12
    movq %rdx, %r13
    xorq %r14, %r14

.rl_char_loop:
    movq io_buf_pos(%rip), %rax
    cmpq io_buf_len(%rip), %rax
    jl .rl_tem_dado

    movq $0, %rax
    movq $0, %rdi
    leaq io_buffer(%rip), %rsi
    movq $256, %rdx
    syscall
    cmpq $0, %rax
    jle .rl_eof
    movq %rax, io_buf_len(%rip)
    movq $0, io_buf_pos(%rip)

.rl_tem_dado:
    movq io_buf_pos(%rip), %rax
    leaq io_buffer(%rip), %rbx
    movb (%rbx, %rax, 1), %cl
    incq %rax
    movq %rax, io_buf_pos(%rip)

    cmpb $10, %cl
    je .rl_fim_linha
    cmpq %r13, %r14
    jge .rl_char_loop
    movb %cl, (%r12, %r14, 1)
    incq %r14
    jmp .rl_char_loop

.rl_fim_linha:
    movb $0, (%r12, %r14, 1)
    movq %r14, %rax
    jmp .rl_ret
.rl_eof:
    movb $0, (%r12, %r14, 1)
    movq %r14, %rax
.rl_ret:
    movq %rbp, %rsp
    pop %rbp
    ret

# =====================================================================
# parse_double: rdi = buffer (string terminada em NUL)
# Converte a string para double, deixando o resultado em st(0).
# Suporta sinal '-' e parte fracionaria apos '.'.
# =====================================================================
parse_double:
    push %rbp
    movq %rsp, %rbp
    push %rbx
    push %r12

    movq %rdi, %rbx
    xorq %r12, %r12

    movb (%rbx), %al
    cmpb $'-', %al
    jne .pd_sem_sinal
    movq $1, %r12
    incq %rbx
.pd_sem_sinal:
    fldz
    fstpl mem_acc(%rip)

.pd_int_loop:
    movb (%rbx), %al
    cmpb $0, %al
    je .pd_fim
    cmpb $'.', %al
    je .pd_frac_prep
    cmpb $'0', %al
    jl .pd_fim
    cmpb $'9', %al
    jg .pd_fim
    subb $'0', %al
    movzbl %al, %eax
    movl %eax, int_tmp(%rip)
    fldl mem_acc(%rip)
    fldl ten_const(%rip)
    fmulp
    fildl int_tmp(%rip)
    faddp
    fstpl mem_acc(%rip)
    incq %rbx
    jmp .pd_int_loop

.pd_frac_prep:
    incq %rbx
    fldl tenth_const(%rip)
    fstpl mem_place(%rip)

.pd_frac_loop:
    movb (%rbx), %al
    cmpb $0, %al
    je .pd_fim
    cmpb $'0', %al
    jl .pd_fim
    cmpb $'9', %al
    jg .pd_fim
    subb $'0', %al
    movzbl %al, %eax
    movl %eax, int_tmp(%rip)
    fildl int_tmp(%rip)
    fldl mem_place(%rip)
    fmulp
    fldl mem_acc(%rip)
    faddp
    fstpl mem_acc(%rip)
    fldl mem_place(%rip)
    fldl tenth_const(%rip)
    fmulp
    fstpl mem_place(%rip)
    incq %rbx
    jmp .pd_frac_loop

.pd_fim:
    fldl mem_acc(%rip)
    cmpq $0, %r12
    je .pd_sem_negacao
    fchs
.pd_sem_negacao:
    pop %r12
    pop %rbx
    movq %rbp, %rsp
    pop %rbp
    ret

# =====================================================================
# int_to_str: rdi = valor inteiro (int64, assumido nao-negativo aqui)
#             rsi = buffer destino
# Retorna em rax a quantidade de caracteres escritos.
# =====================================================================
int_to_str:
    push %rbp
    movq %rsp, %rbp
    push %rbx
    push %r12
    push %r13

    movq %rsi, %r12
    xorq %r13, %r13

    cmpq $0, %rdi
    jne .its_loop
    movb $'0', (%r12)
    movq $1, %rax
    jmp .its_ret

.its_loop:
    cmpq $0, %rdi
    je .its_reverso
    movq %rdi, %rax
    movq $10, %rbx
    cqto
    idivq %rbx
    addq $'0', %rdx
    movb %dl, (%r12, %r13, 1)
    incq %r13
    movq %rax, %rdi
    jmp .its_loop

.its_reverso:
    xorq %rbx, %rbx
    movq %r13, %rcx
    decq %rcx
.its_rev_loop:
    cmpq %rcx, %rbx
    jge .its_rev_fim
    movb (%r12, %rbx, 1), %al
    movb (%r12, %rcx, 1), %dl
    movb %dl, (%r12, %rbx, 1)
    movb %al, (%r12, %rcx, 1)
    incq %rbx
    decq %rcx
    jmp .its_rev_loop
.its_rev_fim:
    movq %r13, %rax

.its_ret:
    pop %r13
    pop %r12
    pop %rbx
    movq %rbp, %rsp
    pop %rbp
    ret

# =====================================================================
# format_double: valor em st(0) (consumido), rdi = buffer destino
# Converte o double para string decimal (6 casas, sem zeros finais).
# Retorna em rax a quantidade de caracteres escritos.
# =====================================================================
format_double:
    push %rbp
    movq %rsp, %rbp
    push %rbx
    push %r12
    push %r13
    push %r14

    movq %rdi, %r12
    xorq %r13, %r13

    fldz
    fcomi %st(1), %st(0)
    fstp %st(0)
    jbe .fd_positivo
    movb $'-', (%r12, %r13, 1)
    incq %r13
    fchs
.fd_positivo:
    fld %st(0)
    fisttpll int_tmp(%rip)
    movq int_tmp(%rip), %r14

    movq %r14, %rdi
    leaq (%r12, %r13, 1), %rsi
    call int_to_str
    addq %rax, %r13

    fildll int_tmp(%rip)
    fsubr %st(0), %st(1)
    fstp %st(0)

    movb $'.', (%r12, %r13, 1)
    incq %r13

    movq $6, %rbx
.fd_frac_loop:
    cmpq $0, %rbx
    je .fd_frac_fim
    fldl ten_const(%rip)
    fmulp
    fld %st(0)
    fisttpll int_tmp(%rip)
    movq int_tmp(%rip), %rax
    addq $'0', %rax
    movb %al, (%r12, %r13, 1)
    incq %r13
    fildll int_tmp(%rip)
    fsubr %st(0), %st(1)
    fstp %st(0)
    decq %rbx
    jmp .fd_frac_loop

.fd_frac_fim:
    fstp %st(0)

.fd_trim_loop:
    movb -1(%r12, %r13, 1), %al
    cmpb $'0', %al
    jne .fd_trim_fim
    decq %r13
    jmp .fd_trim_loop
.fd_trim_fim:
    movb -1(%r12, %r13, 1), %al
    cmpb $'.', %al
    jne .fd_trim_real_fim
    decq %r13
.fd_trim_real_fim:

    movq %r13, %rax
    pop %r14
    pop %r13
    pop %r12
    pop %rbx
    movq %rbp, %rsp
    pop %rbp
    ret

# =====================================================================
# compare_doubles: rdi = endereco de A, rsi = endereco de B
# Retorna em rax: -1 se A<B, 0 se A==B, 1 se A>B
# =====================================================================
compare_doubles:
    push %rbp
    movq %rsp, %rbp
    fldl (%rsi)
    fldl (%rdi)
    fcomi %st(1), %st(0)
    fstp %st(0)
    fstp %st(0)
    jb .cd_menor
    je .cd_igual
    movq $1, %rax
    jmp .cd_fim
.cd_menor:
    movq $-1, %rax
    jmp .cd_fim
.cd_igual:
    movq $0, %rax
.cd_fim:
    movq %rbp, %rsp
    pop %rbp
    ret

# =====================================================================
# is_integer_check: valor em st(0) (preservado ao final)
# Retorna em rax: 1 se o valor for inteiro, 0 caso contrario.
# Deixa em int_tmp(memoria) o valor truncado (int64), para reuso.
# =====================================================================
is_integer_check:
    push %rbp
    movq %rsp, %rbp
    fld %st(0)
    fisttpll int_tmp(%rip)
    fildll int_tmp(%rip)
    fcomi %st(1), %st(0)
    movq $0, %rax
    jne .iic_fim
    movq $1, %rax
.iic_fim:
    fstp %st(0)
    movq %rbp, %rsp
    pop %rbp
    ret

# =====================================================================
# skip_spaces_eval: avanca eval_pos enquanto houver espacos.
# =====================================================================
skip_spaces_eval:
    push %rbp
    movq %rsp, %rbp
.sse_loop:
    movq eval_pos(%rip), %rbx
    movb (%rbx), %al
    cmpb $' ', %al
    jne .sse_fim
    incq %rbx
    movq %rbx, eval_pos(%rip)
    jmp .sse_loop
.sse_fim:
    movq %rbp, %rsp
    pop %rbp
    ret

# =====================================================================
# parse_value_eval: le numero, variavel ou chamada f(x). Resultado em st(0).
# =====================================================================
parse_value_eval:
    push %rbp
    movq %rsp, %rbp
    call skip_spaces_eval
    movq eval_pos(%rip), %rbx
    movb (%rbx), %al
    cmpb $'a', %al
    jl .pve_num
    cmpb $'z', %al
    jg .pve_num

    movzbq %al, %r12
    subq $'a', %r12
    movb 1(%rbx), %cl
    cmpb $'(', %cl
    je .pve_func

    movb active_param(%rip), %cl
    cmpb %al, %cl
    je .pve_param
    fldl var_values(,%r12,8)
    incq %rbx
    movq %rbx, eval_pos(%rip)
    jmp .pve_fim

.pve_param:
    fldl func_arg(%rip)
    incq %rbx
    movq %rbx, eval_pos(%rip)
    jmp .pve_fim

.pve_func:
    movq eval_pos(%rip), %r13
    movzbq active_param(%rip), %r14
    push %r14
    push %r12
    addq $2, %rbx
    movq %rbx, eval_pos(%rip)
    call eval_expr
    fstpl func_arg(%rip)
    pop %r12
    pop %r14
    call skip_spaces_eval
    movq eval_pos(%rip), %rbx
    cmpb $')', (%rbx)
    jne .pve_call_body
    incq %rbx
    movq %rbx, eval_pos(%rip)
.pve_call_body:
    movq eval_pos(%rip), %r15
    movb func_param(%r12), %al
    movb %al, active_param(%rip)
    movq %r12, %rax
    shlq $6, %rax
    leaq func_body(%rip), %rbx
    addq %rax, %rbx
    movq %rbx, eval_pos(%rip)
    push %r15
    push %r14
    call eval_expr
    pop %r14
    pop %r15
    movq %r15, eval_pos(%rip)
    movb %r14b, active_param(%rip)
    jmp .pve_fim

.pve_num:
    movq %rbx, %rdi
    call parse_double
.pve_adv_num:
    movb (%rbx), %al
    cmpb $'-', %al
    je .pve_inc
    cmpb $'.', %al
    je .pve_inc
    cmpb $'0', %al
    jl .pve_num_fim
    cmpb $'9', %al
    jg .pve_num_fim
.pve_inc:
    incq %rbx
    jmp .pve_adv_num
.pve_num_fim:
    movq %rbx, eval_pos(%rip)
.pve_fim:
    movq %rbp, %rsp
    pop %rbp
    ret

# =====================================================================
# eval_expr: avalia valor [operador valor] ou valor operador_unario.
# Resultado em st(0), erro_flag definido pelas operacoes.
# =====================================================================
eval_expr:
    push %rbp
    movq %rsp, %rbp
    movq $0, erro_flag(%rip)
    call parse_value_eval
    fstpl op1(%rip)
    call skip_spaces_eval
    movq eval_pos(%rip), %rbx
    movb (%rbx), %al
    cmpb $0, %al
    je .ee_so_op1
    cmpb $')', %al
    je .ee_so_op1
    movb %al, operador(%rip)
    movzbq %al, %r15
    incq %rbx
    movq %rbx, eval_pos(%rip)

    cmpb $'!', %al
    je .ee_fat
    cmpb $'i', %al
    je .ee_inv
    cmpb $'r', %al
    je .ee_sqrt
    cmpb $'p', %al
    je .ee_primo

    fldl op1(%rip)
    sub $8, %rsp
    fstpl (%rsp)
    push %r15
    call parse_value_eval
    pop %r15
    fstpl op2(%rip)
    fldl (%rsp)
    add $8, %rsp
    fstpl op1(%rip)
    movb %r15b, %al
    cmpb $'+', %al
    je .ee_soma
    cmpb $'-', %al
    je .ee_sub
    cmpb $'*', %al
    je .ee_mul
    cmpb $'/', %al
    je .ee_div
    cmpb $'^', %al
    je .ee_pow
    cmpb $'c', %al
    je .ee_comb
    cmpb $'a', %al
    je .ee_arr
    cmpb $'l', %al
    je .ee_log
    movq $9, erro_flag(%rip)
    fldz
    jmp .ee_fim
.ee_so_op1:
    fldl op1(%rip)
    jmp .ee_fim
.ee_soma:
    call calc_soma
    jmp .ee_fim
.ee_sub:
    call calc_sub
    jmp .ee_fim
.ee_mul:
    call calc_mul
    jmp .ee_fim
.ee_div:
    call calc_div
    jmp .ee_fim
.ee_pow:
    call calc_pow
    jmp .ee_fim
.ee_comb:
    call calc_comb
    jmp .ee_fim
.ee_arr:
    call calc_arr
    jmp .ee_fim
.ee_log:
    call calc_log
    jmp .ee_fim
.ee_fat:
    call calc_fat
    jmp .ee_fim
.ee_inv:
    call calc_inv
    jmp .ee_fim
.ee_sqrt:
    call calc_sqrt
    jmp .ee_fim
.ee_primo:
    call calc_primo
.ee_fim:
    movq %rbp, %rsp
    pop %rbp
    ret

# =====================================================================
# copy_func_body: r12=indice da funcao, rbx=endereco do corpo.
# =====================================================================
copy_func_body:
    push %rbp
    movq %rsp, %rbp
    movq %r12, %rax
    shlq $6, %rax
    leaq func_body(%rip), %r13
    addq %rax, %r13
    xorq %r14, %r14
.cfb_loop:
    cmpq $63, %r14
    jge .cfb_zero
    movb (%rbx,%r14,1), %al
    movb %al, (%r13,%r14,1)
    cmpb $0, %al
    je .cfb_fim
    incq %r14
    jmp .cfb_loop
.cfb_zero:
    movb $0, (%r13,%r14,1)
.cfb_fim:
    movq %rbp, %rsp
    pop %rbp
    ret

# =====================================================================
# _start: laco principal da calculadora
# =====================================================================
_start:
.loop_principal:
    leaq msg_op1(%rip), %rdi
    call print_cstr
    leaq input_buf(%rip), %rdi
    movq $128, %rdx
    call read_line

    leaq input_buf(%rip), %rbx
.lp_skip_ini:
    cmpb $' ', (%rbx)
    jne .lp_ini_ok
    incq %rbx
    jmp .lp_skip_ini
.lp_ini_ok:
    movb (%rbx), %al
    cmpb $0, %al
    je .perguntar_continuar

    cmpb $'a', %al
    jl .lp_scan_expr
    cmpb $'z', %al
    jg .lp_scan_expr
    movb 1(%rbx), %cl
    cmpb $'(', %cl
    je .definir_funcao
    movq %rbx, %r12
    incq %r12
.lp_ass_skip:
    cmpb $' ', (%r12)
    jne .lp_ass_check
    incq %r12
    jmp .lp_ass_skip
.lp_ass_check:
    cmpb $'=', (%r12)
    je .atribuir_variavel
    jmp .lp_tem_expr

.lp_scan_expr:
    movq %rbx, %r12
    xorq %r13, %r13
.lp_scan_loop:
    movb (%r12), %al
    cmpb $0, %al
    je .lp_scan_fim
    cmpb $' ', %al
    je .lp_tem_expr
    cmpb $'(', %al
    je .lp_tem_expr
    cmpb $'+', %al
    je .lp_tem_expr
    cmpb $'*', %al
    je .lp_tem_expr
    cmpb $'/', %al
    je .lp_tem_expr
    cmpb $'^', %al
    je .lp_tem_expr
    cmpb $'c', %al
    je .lp_tem_expr
    cmpb $'a', %al
    je .lp_tem_expr
    cmpb $'!', %al
    je .lp_tem_expr
    cmpb $'i', %al
    je .lp_tem_expr
    cmpb $'r', %al
    je .lp_tem_expr
    cmpb $'l', %al
    je .lp_tem_expr
    cmpb $'p', %al
    je .lp_tem_expr
    incq %r12
    jmp .lp_scan_loop
.lp_scan_fim:
    jmp .modo_antigo
.lp_tem_expr:
    movq %rbx, eval_pos(%rip)
    movb $0, active_param(%rip)
    call eval_expr
    jmp .tratar_resultado_eval

.atribuir_variavel:
    movzbq (%rbx), %r14
    subq $'a', %r14
    incq %r12
    movq %r12, eval_pos(%rip)
    movb $0, active_param(%rip)
    call eval_expr
    fstpl var_values(,%r14,8)
    movb $1, var_set(%r14)
    fldl var_values(,%r14,8)
    jmp .tratar_resultado_eval

.definir_funcao:
    movq %rbx, %r15
    movzbq (%rbx), %r12
    subq $'a', %r12
    movq %rbx, %r14
.df_procura_igual:
    cmpb $0, (%r14)
    je .df_chamada_funcao
    cmpb $'=', (%r14)
    je .df_achou_igual
    incq %r14
    jmp .df_procura_igual
.df_achou_igual:
    movb 2(%rbx), %al
    movb %al, func_param(%r12)
    movq %r14, %rbx
    incq %rbx
.df_skip_body:
    cmpb $' ', (%rbx)
    jne .df_copia
    incq %rbx
    jmp .df_skip_body
.df_copia:
    call copy_func_body
    movb $1, func_set(%r12)
    leaq msg_ok(%rip), %rdi
    call print_cstr
    jmp .perguntar_continuar

.erro_op_linha:
    leaq erro_op(%rip), %rdi
    call print_cstr
    jmp .perguntar_continuar

.df_chamada_funcao:
    movq %r15, %rbx
    jmp .lp_tem_expr

.modo_antigo:
    leaq input_buf(%rip), %rdi
    call parse_double
    fstpl op1(%rip)

    leaq msg_operador(%rip), %rdi
    call print_cstr
    leaq input_buf(%rip), %rdi
    movq $64, %rdx
    call read_line
    movb input_buf(%rip), %al
    movb %al, operador(%rip)

    cmpb $'+', %al
    je .ler_op2
    cmpb $'-', %al
    je .ler_op2
    cmpb $'*', %al
    je .ler_op2
    cmpb $'/', %al
    je .ler_op2
    cmpb $'^', %al
    je .ler_op2
    cmpb $'c', %al
    je .ler_op2
    cmpb $'a', %al
    je .ler_op2
    cmpb $'l', %al
    je .ler_op2
    jmp .calcular

.ler_op2:
    leaq msg_op2(%rip), %rdi
    call print_cstr
    leaq input_buf(%rip), %rdi
    movq $128, %rdx
    call read_line
    leaq input_buf(%rip), %rdi
    call parse_double
    fstpl op2(%rip)
    jmp .calcular

.tratar_resultado_eval:
    movq erro_flag(%rip), %rax
    cmpq $0, %rax
    je .exibir_resultado
    cmpq $1, %rax
    je .erro_generico_eval
    cmpq $2, %rax
    je .erro_comb_compartilhado
    cmpq $9, %rax
    je .erro_op_eval
    jmp .exibir_resultado
.erro_op_eval:
    fstp %st(0)
    jmp .erro_op_linha
.erro_generico_eval:
    movb operador(%rip), %al
    cmpb $'/', %al
    je .erro_div_lbl
    cmpb $'^', %al
    je .erro_pow_lbl
    cmpb $'l', %al
    je .erro_log_lbl
    cmpb $'r', %al
    je .erro_sqrt_lbl
    cmpb $'i', %al
    je .erro_inv_lbl
    jmp .erro_neg_compartilhado

.calcular:
    movb operador(%rip), %al
    cmpb $'+', %al
    je .op_soma
    cmpb $'-', %al
    je .op_sub
    cmpb $'*', %al
    je .op_mul
    cmpb $'/', %al
    je .op_div
    cmpb $'^', %al
    je .op_pow
    cmpb $'c', %al
    je .op_comb
    cmpb $'a', %al
    je .op_arr
    cmpb $'!', %al
    je .op_fat
    cmpb $'i', %al
    je .op_inv
    cmpb $'r', %al
    je .op_sqrt
    cmpb $'l', %al
    je .op_log
    cmpb $'p', %al
    je .op_primo
    leaq erro_op(%rip), %rdi
    call print_cstr
    jmp .perguntar_continuar

.op_soma:
    call calc_soma
    jmp .exibir_resultado

.op_sub:
    call calc_sub
    jmp .exibir_resultado

.op_mul:
    call calc_mul
    jmp .exibir_resultado

.op_div:
    call calc_div
    movq erro_flag(%rip), %rax
    cmpq $1, %rax
    je .erro_div_lbl
    jmp .exibir_resultado
.erro_div_lbl:
    fstp %st(0)
    leaq erro_div(%rip), %rdi
    call print_cstr
    jmp .perguntar_continuar

.op_pow:
    call calc_pow
    movq erro_flag(%rip), %rax
    cmpq $1, %rax
    je .erro_pow_lbl
    jmp .exibir_resultado
.erro_pow_lbl:
    fstp %st(0)
    leaq erro_pow(%rip), %rdi
    call print_cstr
    jmp .perguntar_continuar

.op_log:
    call calc_log
    movq erro_flag(%rip), %rax
    cmpq $1, %rax
    je .erro_log_lbl
    jmp .exibir_resultado
.erro_log_lbl:
    fstp %st(0)
    leaq erro_log(%rip), %rdi
    call print_cstr
    jmp .perguntar_continuar

.op_sqrt:
    call calc_sqrt
    movq erro_flag(%rip), %rax
    cmpq $1, %rax
    je .erro_sqrt_lbl
    jmp .exibir_resultado
.erro_sqrt_lbl:
    fstp %st(0)
    leaq erro_sqrt(%rip), %rdi
    call print_cstr
    jmp .perguntar_continuar

.op_inv:
    call calc_inv
    movq erro_flag(%rip), %rax
    cmpq $1, %rax
    je .erro_inv_lbl
    jmp .exibir_resultado
.erro_inv_lbl:
    fstp %st(0)
    leaq erro_inv(%rip), %rdi
    call print_cstr
    jmp .perguntar_continuar

.op_fat:
    call calc_fat
    movq erro_flag(%rip), %rax
    cmpq $1, %rax
    je .erro_neg_compartilhado
    jmp .exibir_resultado

.op_comb:
    call calc_comb
    movq erro_flag(%rip), %rax
    cmpq $1, %rax
    je .erro_neg_compartilhado
    cmpq $2, %rax
    je .erro_comb_compartilhado
    jmp .exibir_resultado

.op_arr:
    call calc_arr
    movq erro_flag(%rip), %rax
    cmpq $1, %rax
    je .erro_neg_compartilhado
    cmpq $2, %rax
    je .erro_comb_compartilhado
    jmp .exibir_resultado

.op_primo:
    call calc_primo
    jmp .exibir_resultado

.erro_neg_compartilhado:
    fstp %st(0)
    leaq erro_neg(%rip), %rdi
    call print_cstr
    jmp .perguntar_continuar

.erro_comb_compartilhado:
    fstp %st(0)
    leaq erro_comb(%rip), %rdi
    call print_cstr
    jmp .perguntar_continuar

.exibir_resultado:
    leaq msg_resultado(%rip), %rdi
    call print_cstr
    leaq output_buf(%rip), %rdi
    call format_double
    leaq output_buf(%rip), %rdi
    movq %rax, %rdx
    call print_buf
    leaq msg_nl(%rip), %rdi
    call print_cstr

.perguntar_continuar:
    leaq msg_continuar(%rip), %rdi
    call print_cstr
    leaq input_buf(%rip), %rdi
    movq $64, %rdx
    call read_line
    movb input_buf(%rip), %al
    cmpb $'s', %al
    je .loop_principal
    cmpb $'S', %al
    je .loop_principal

    movq $60, %rax
    movq $0, %rdi
    syscall
