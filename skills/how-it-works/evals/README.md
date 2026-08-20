# Evals — testes da skill `how-it-works`

## O que é isto

A saída desta skill é texto escrito por um LLM: ela sai **diferente a cada
execução**. Não dá para testar comparando com um texto esperado, como se faz com
a saída de um script. O que se testa é se os **fatos certos apareceram** e se a
**forma** exigida pelo `references/synthesis-prompt.md` foi respeitada.

Cada caso tem duas metades:

- **Asserções programáticas** (`check_assertions.sh`) — verificáveis por `grep`,
  baratas e objetivas. "Cita `schema.sql`?" "Tem a seção Pontos a confirmar?"
  "Inventou um símbolo que não existe?"
- **Rubrica** (campo `rubrica` no `evals.json`) — o que exige julgamento e
  portanto precisa de um LLM juiz. "A visão geral permite saber onde mexer?"

## O que NÃO mora aqui

Só os **casos** e o **gabarito** ficam versionados. Os **resultados** de cada
rodada (saídas, tempos, contagens de token) vão para
`how-it-works-workspace/`, irmão da pasta da skill e no `.gitignore` —
mudam a cada execução e não têm por que entrar no repositório.

Esta pasta nunca é lida em tempo de execução: a `SKILL.md` não a menciona, então
o modelo não a carrega e ela não custa token nenhum ao usuário da skill.

## Como rodar

O `skill-creator` (`~/.claude/skills/skill-creator/`) é quem orquestra: dispara
a execução com a versão atual e com a versão anterior lado a lado, coleta tempo
e tokens de cada uma, e agrega média e desvio padrão. Peça a ele.

Para checar só as asserções programáticas de uma saída já produzida:

```bash
evals/check_assertions.sh petclinic-busca-owner /caminho/da/explicacao.md
```

## Por que o commit é pinado

Cada caso fixa um SHA. O gabarito cita `db/h2/schema.sql:39` e o commit
`bb37aad`; se o caso apontasse para o branch, um commit novo no upstream moveria
as linhas e o eval acusaria uma regressão que não existe.
