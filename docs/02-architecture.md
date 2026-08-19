# 02 — Arquitetura

## Três insumos

A explicação nunca é só "LLM sobre código". Ela combina três fontes:

1. **Mapa de design vivo** (prior) — estrutura e intenção do projeto, mantida de
   rotina. Orienta *onde* buscar.
2. **Fatos determinísticos** (escopados) — de git, ast-grep e SCIP.
3. **Síntese do LLM** — julgamento e redação, uma única vez, no fim.

## Dois caminhos

- **Caminho frio** (infra, amortizado): constrói o índice SCIP e regenera a
  camada estrutural do mapa de design. Roda em CI/background. Produz caches.
- **Caminho quente** (por pedido): lê os caches e roda o pipeline escopado.
  Deve ser rápido. Nunca constrói nada caro.

O único trabalho whole-repo e caro (índice SCIP) fica fora do caminho quente.
É isso que garante tempo ~constante mesmo em base grande.

## Pipeline do caminho quente

```
ler pedido + mapa → localizar fatia → expandir impacto (limitado)
  → montar dossiê (compacto) → síntese LLM → explicação + handoff
```

Passos 1–5 determinísticos; passo 6 é a única chamada pesada de LLM.

Ver [04-execution-flow.md](04-execution-flow.md) para o detalhe de cada estágio
e [05-performance.md](05-performance.md) para os controles de custo.
