---
name: propose-implementation
description: >-
  Gera uma proposta de implementacao clara e discutivel para uma mudanca de
  codigo (bug, feature, refatoracao, melhoria), com abordagens alternativas e
  seus trade-offs, ANTES de escrever codigo e antes de rodar "openspec propose".
  Use esta skill sempre que o usuario ja entende como o codigo esta hoje e
  precisa decidir COMO implementar — ou pedir "proponha uma solucao", "quais as
  abordagens", "como voce faria isso", "monte o plano antes de codar", "gere o
  openspec propose". Consome o dossie validado da fase 1 (how-it-works);
  se ele nao existir, roda a investigacao primeiro. Valida a proposta de forma
  deterministica (os simbolos/arquivos citados existem? qual o raio de impacto
  real?) para evitar propor APIs que nao existem. Emite os artefatos do OpenSpec
  (proposal.md, design.md, tasks.md). Funciona em .NET, Java, Kotlin, Go, Python,
  Angular e React.
---

# Propose Implementation

Esta skill executa a **fase 2** do fluxo: depois de entender *como e hoje* (fase
1), definir *o que fazer*. Diferente da fase 1 (investigacao pura), aqui o
trabalho e de julgamento — gerar opcoes e trade-offs. Por isso o LLM tem papel
maior; mas ele e **cercado por validacao deterministica** que confere os fatos
da proposta antes de ela chegar ao desenvolvedor.

Objetivo: produzir uma proposta objetiva e discutivel, revisavel **antes** de
qualquer codigo, que depois alimenta o `openspec propose` ja fundamentada.

## Pre-requisito: o dossie da fase 1

Esta skill consome o `FeatureDossier` validado e a explicacao "como e hoje"
produzidos pela skill `how-it-works`. Procure em:

- `openspec/changes/<id>/current-state.dossier.json`
- `openspec/changes/<id>/current-state.md`

**Se nao existirem**, rode a fase 1 primeiro (invoque `how-it-works`)
para nao propor sobre entendimento vazio. Nunca proponha sem os fatos da fatia.

## O fluxo (respeite o checkpoint humano)

### Passo 1 — Ingerir o entendimento

Leia o dossie e a explicacao validada da fase 1. Toda a proposta deve se ancorar
nesses fatos: simbolos reais, arquivos reais, raio de impacto conhecido, o
"porque" do codigo atual. Leia tambem o mapa de design vivo, se existir, para
respeitar limites de modulo e invariantes.

### Passo 2 — Gerar abordagens alternativas (LLM)

Leia `references/proposal-prompt.md` e siga-o. Gere **2–3 abordagens distintas**
(desfechos/arquiteturas diferentes, nao apenas tons diferentes). Para cada uma:
o que ela prioriza, o que ela sacrifica, esforco relativo e risco. Detalhe de
codigo **condicional**: mostre o trecho/diff real so onde a mudanca e critica.

Apresente as abordagens no formato de `assets/proposal-template.md`. Este e o
**artefato discutivel** — nao pule direto para uma unica abordagem, a menos que
a mudanca seja trivial.

### Passo 3 — CHECKPOINT: o desenvolvedor escolhe/ajusta

Pare e apresente as abordagens. Espere o desenvolvedor escolher uma, combinar
partes ou pedir ajustes. **Nao avance para o plano detalhado sem essa decisao.**
Este checkpoint e o que evita elaborar em profundidade uma abordagem errada.

### Passo 4 — Validar a proposta escolhida (deterministico)

Antes de detalhar, confira os fatos da abordagem escolhida. Extraia as
afirmacoes que ela faz sobre o codigo e escreva em um arquivo de claims
(uma por linha):

```
existing-symbol:PricingService
existing-file:src/pricing/service.cs
new-symbol:DiscountCapPolicy
new-file:src/pricing/discount_cap_policy.cs
```

```bash
scripts/validate_proposal.sh claims.txt
```

Se `verdict` for `needs_fix`, corrija a proposta (simbolos inexistentes = risco
de alucinacao; colisao = criar algo que ja existe) **antes** de continuar. Esse
passo elimina o erro classico de propor APIs que nao existem.

Depois, levante o raio de impacto real dos pontos que a proposta vai tocar:

```bash
scripts/proposal_impact.sh "Simbolo1,Simbolo2" "arquivo1,arquivo2" "<scip_index_ou_vazio>"
```

Use o resultado para nao surpreender o dev: o que pode quebrar, quais testes
serao afetados, onde ha lacuna de cobertura.

### Passo 5 — Elaborar o plano (LLM, informado pela validacao)

Para a abordagem escolhida e validada, produza o plano: decisoes de arquitetura
(com o porque), design dos componentes, pontos de integracao, avaliacao de
risco, e o detalhe de codigo/diff para as pecas criticas. Ancore tudo nos fatos
validados. Marque honestamente o que a analise estatica nao pode confirmar (DI,
dispatch dinamico, cross-service).

### Passo 6 — Quebrar em tarefas

Decomponha em tarefas pequenas, **ordenadas por dependencia**, cada uma:
implementavel isoladamente, com criterio de aceitacao verificavel, e revisavel
sozinha (nao um despejo gigante). Referencie os testes afetados do passo 4.

### Passo 7 — Emitir o pacote OpenSpec

Monte `proposal.md`, `design.md` e `tasks.md` seguindo
`references/openspec-artifacts.md` (templates em `assets/openspec-change/`).
Depois materialize o pacote:

```bash
scripts/emit_openspec_change.sh <change-id> <dir_com_os_artefatos>
```

Ele cria `openspec/changes/<id>/`, copia junto o current-state da fase 1, e roda
`openspec validate` se o CLI existir. A partir daqui, o `openspec propose` (e o
apply/archive) seguem o fluxo normal do OpenSpec, ja fundamentados.

## Regras que fazem a proposta ser boa

- **Opcoes, nao um monologo**: 2–3 abordagens com trade-offs reais, para o dev
  decidir. So colapse para uma se a mudanca for trivial.
- **Ancorada e verificada**: nada de simbolo/arquivo inventado. Rode
  `validate_proposal.sh` e corrija antes de apresentar o plano final.
- **Profundidade condicional**: diff real so no que e critico; o resto, conciso.
- **Impacto explicito**: diga o que quebra e o que os testes cobrem.
- **Honesta**: riscos, incertezas e lacunas da analise estatica ficam visiveis.
- **Tarefas revisaveis**: pequenas, ordenadas, testaveis — nunca um despejo.

## Anti-objetivo

Evite o "monstro de markdown": a proposta e para decidir rapido, nao para gerar
burocracia. Abordagens curtas, trade-offs claros, plano enxuto. Se estiver
ficando verboso, corte.
