# Tiers de precisão e degradação graciosa

A skill roda em qualquer repo de código-fonte porque nunca depende de uma única
ferramenta. Ela detecta o que existe e escolhe o **teto de precisão** possível,
degradando sem quebrar.

## As três camadas

| Camada | Ferramenta | Cobre | Precisa de | Papel |
|---|---|---|---|---|
| 0 — universal | git, ripgrep | tudo (agnóstico) | só o repo | "porquê" (blame/log/PR) + busca textual |
| 1 — estrutural | ast-grep (`sg`) | .NET, Java, Kotlin, Go, Python, TS, JS | só o binário | localizar fatia, call sites aproximados |
| 2 — preciso | SCIP (scip-*) | as mesmas 7 | repo **buildável** + índice | find-references reais (impacto exato) |

`scip-java` cobre Kotlin+Java; `scip-typescript` cobre Angular+React;
`scip-dotnet` cobre C#; `scip-python` e `scip-go` completam. O orquestrador
`scip-io` instala e faz merge de índices multi-linguagem.

## A escada de degradação

1. Índice SCIP presente e **fresco** → `tier2`, arestas precisas.
2. Índice SCIP **stale** → use, mas marque a incerteza na explicação.
3. Sem SCIP ou repo **não compila** → `tier1`, arestas do ast-grep (aproximadas).
4. Sem ast-grep → `tier0`, textual (ruidoso, último recurso).

O caminho quente **nunca constrói** o índice — isso é trabalho frio (CI /
background), keyed por commit e incremental. Ver `docs/05-performance.md`.

## Limites honestos (todos os tiers)

Análise estática é de alta precisão, mas **não é completa**. Não enxerga:

- dispatch dinâmico / reflexão;
- injeção de dependência (muito comum em .NET e Spring/Java);
- roteamento por string;
- fronteiras entre serviços (HTTP, filas, wiring por config).

Nesses pontos, o dossiê marca a lacuna e o LLM deve sinalizar "resolvido em
runtime, confirme comigo" — nunca assumir completude.

## O mapa de design vivo como acelerador

Se o projeto tiver um mapa de design (ex.: `docs/design-map.md`) mantido de
rotina, a localização parte já apontada para o módulo certo — mais rápido, mais
preciso, mais objetivo. A camada estrutural do mapa deve ser **gerada
automaticamente** (árvore de diretórios, responsabilidades, arestas); só a
camada de intenção (o "porquê" dos limites de módulo) é curada à mão. Ver
`docs/06-living-design-map.md`.
