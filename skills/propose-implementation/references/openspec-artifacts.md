# Artefatos do OpenSpec — estrutura do handoff

O OpenSpec organiza cada mudança em um pacote autocontido:
`openspec/changes/<id>/` com `proposal.md`, `design.md`, `tasks.md` e, quando
há mudança de comportamento, delta specs por capacidade. O fluxo documentado é
proposal → specs → design → tasks → implement.

> Nota: o OpenSpec permite customizar o schema (quais artefatos são gerados e com
> que estrutura). Os templates aqui seguem o padrão documentado; sempre rode
> `openspec validate <id> --strict` para conferir contra o schema do seu projeto.

## proposal.md — por quê + o que muda

- **Why**: o problema/motivação (venha da explicação da fase 1).
- **What changes**: o escopo da mudança, em alto nível.
- **Impact**: o que é afetado (do `proposal_impact.sh`).

Curto e objetivo. É a chance de pegar desalinhamento cedo, antes do código.

## specs/*.spec.md — comportamento (delta)

Só quando a mudança altera comportamento observável. Marque as seções como
`## ADDED`, `## MODIFIED` ou `## REMOVED`, com requisitos e cenários por
capacidade. Descreve o **o quê** do comportamento, não o **como**.

## design.md — como (decisões técnicas)

- **Abordagem escolhida** e por quê (as alternativas consideradas viram um ADR).
- **Decisões de arquitetura** — contexto, opções, escolha, consequências.
- **Pontos de integração** e estratégia de implementação.
- **Riscos** e mitigação; o que a análise estática não confirmou.

## tasks.md — checklist de implementação

Tarefas pequenas, ordenadas por dependência, cada uma com critério de aceitação.
Formato de checklist:

```markdown
## Tarefas

- [ ] 1. <tarefa atômica> — aceite: <critério verificável / teste>
- [ ] 2. <tarefa atômica> — aceite: <critério verificável / teste>
```

## Anexos da fase 1

O `emit_openspec_change.sh` também copia, se presentes,
`current-state.md` e `current-state.dossier.json` para o pacote — assim o
entendimento investigado fica junto da proposta e não se perde.
