# 05 — Performance

Alvo: **rápido mesmo em bases grandes**. O custo não deve escalar com o tamanho
do repo.

## Princípio

Manter o trabalho frio e whole-repo **fora do caminho quente**. Cada explicação
toca só: consultas escopadas + um índice já pronto + uma chamada de LLM limitada.

## Os quatro controles

1. **Mapa como prior**: a localização parte apontada para o módulo certo, em vez
   de redescobrir a estrutura. Corta a varredura ampla.
2. **Expansão limitada**: 1 salto (2 só se crítico), top-N por importância de
   referência. O conjunto de trabalho fica pequeno por construção.
3. **Índice amortizado**: SCIP é caro de produzir mas reutilizável. Construído
   frio (CI/background), keyed por commit, incremental. O caminho quente só lê.
4. **Dossiê capado**: o LLM recebe top-N símbolos/chamadores, não código cru.
   A latência da síntese também fica limitada.

## Ordens de grandeza (prático)

- Camadas 0/1 (git, ripgrep, ast-grep): ms a poucos segundos, escopadas.
- `git log -S` (pickaxe): o mais lento dos três; limitado e cacheável.
- Camada 2 (build + índice SCIP): segundos a minutos — **frio**, fora do quente.
- Caminho quente: dominado pela chamada de LLM; resto sub-segundo a poucos seg.

Quando tudo está no lugar, o gargalo passa a ser o LLM — o único passo que
agrega julgamento.

Ver [decisions/0003-cold-hot-path-split.md](decisions/0003-cold-hot-path-split.md).
