# Calculadora em Assembly (x86-64)

## Compilação

```bash
gcc -no-pie -o calc main.s
```

## Execução

```bash
./calc
```

## Modo de uso

A calculadora pergunta o primeiro operando

Digite apenas o número. Em seguida será pedido o operador e (se necessário) o segundo operando.

```
Digite o primeiro operando: 10
Digite o operador (+,-,*,/,^,c,a,!,i,r,l,p): +
Digite o segundo operando: 5
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
| `c`      | Combinação                          |
| `a`      | Arranjo                             |
| `!`      | Fatorial                            |
| `i`      | Inverso                             |
| `r`      | Raiz quadrada                       |
| `l`      | Logaritmo                           |
| `p`      | Teste de primalidade                |


## Continuar ou sair

Após cada resultado, a calculadora pergunta se deseja continuar (`s`/`n`). Qualquer resposta diferente de `s`/`S` encerra o programa.
