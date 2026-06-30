# Calculadora em Assembly (x86-64)

Calculadora de linha de comando escrita em x86-64 (AT&T/GAS), sem uso de libc. Toda a entrada/saída é feita via syscalls diretas (`read`, `write`, `exit`), e as operações matemáticas (potência, log, raiz) são implementadas com instruções nativas da FPU x87.

## Compilação

```bash
as -o main.o main.s
as -o funcoes.o funcoes.s
ld -o calculadora main.o funcoes.o
```

## Execução

```bash
./calculadora
```

## Modo de uso

A calculadora pergunta o primeiro operando. A partir daí, dois modos são aceitos:

### Modo clássico

Digite apenas o número. Em seguida será pedido o operador e (se necessário) o segundo operando.

```
Digite o primeiro operando: 10
Digite o operador (+,-,*,/,^,c,a,!,i,r,l,p): +
Digite o segundo operando: 5
Resultado: 15
```

### Modo de expressão

Digite a conta inteira na mesma linha:

```
Digite o primeiro operando: 10 + 5
Resultado: 15
```

## Operadores disponíveis

| Operador | Operação                          |
|----------|------------------------------------|
| `+`      | Soma                                |
| `-`      | Subtração                           |
| `*`      | Multiplicação                       |
| `/`      | Divisão                             |
| `^`      | Potência                            |
| `c`      | Combinação (C de n, r)              |
| `a`      | Arranjo                             |
| `!`      | Fatorial                            |
| `i`      | Inverso                             |
| `r`      | Raiz quadrada                       |
| `l`      | Logaritmo                           |
| `p`      | Teste de primalidade                |

## Variáveis

É possível guardar um valor numérico em uma variável de uma letra (`a` a `z`) e reutilizá-la em expressões posteriores.

```
Digite o primeiro operando: x = 10
Resultado: 10
Digite o primeiro operando: x + 5
Resultado: 15
```

## Funções

Também é possível definir funções de um parâmetro usando as operações já existentes, e depois chamá-las com um número ou com uma variável.

```
Digite o primeiro operando: f(x) = x * x
OK
Digite o primeiro operando: f(4)
Resultado: 16
Digite o primeiro operando: y = 3
Resultado: 3
Digite o primeiro operando: f(y)
Resultado: 9
Digite o primeiro operando: f(2) + 1
Resultado: 5
```

O nome usado como parâmetro na definição (`x` no exemplo acima) é local à função: ele não interfere em variáveis externas de mesmo nome, e variáveis externas não interferem no cálculo interno da função.

## Continuar ou sair

Após cada resultado, a calculadora pergunta se deseja continuar (`s`/`n`). Qualquer resposta diferente de `s`/`S` encerra o programa.
