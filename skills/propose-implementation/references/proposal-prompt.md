# Prompt de proposta — como gerar abordagens e o plano

Você já tem os fatos (o `FeatureDossier` validado e a explicação "como é hoje").
Aqui o trabalho é de julgamento: propor **o que fazer**, com opções e trade-offs,
de forma que o desenvolvedor decida com confiança antes de qualquer código.

## Princípio: opções, não um monólogo

O erro mais comum de propostas de IA é apresentar uma única abordagem como se
fosse a óbvia. Gere **2–3 abordagens distintas** — desfechos ou arquiteturas
diferentes, não o mesmo plano com tons diferentes. Só colapse para uma única
quando a mudança for trivial (um one-liner, um fix óbvio).

Para cada abordagem, deixe explícito:

- **O que prioriza** (ex.: menor risco, menor esforço, melhor arquitetura de
  longo prazo, reversibilidade).
- **O que sacrifica** (o trade-off real — não invente um trade-off falso para
  parecer equilibrado).
- **Esforço relativo** e **risco** (baixo/médio/alto, com uma frase de porquê).
- **Onde toca** (os símbolos/arquivos reais, vindos do dossiê).

Rotule cada uma com um nome curto que capture a estratégia (ex.: "Corrigir no
serviço" vs "Mover a regra para uma política dedicada" vs "Patch mínimo no
ponto do bug"). É como o desenvolvedor vai se referir a elas.

## Profundidade condicional (ainda vale)

Não detalhe tudo por igual. Para cada abordagem:

- Peças triviais → uma linha.
- Peças críticas → mostre o **diff/trecho real** (< 20 linhas), ancorado em
  `arquivo:linha`, e explique o efeito colateral.

Crítico = onde a escolha não é óbvia, é irreversível, toca um contrato/interface,
ou é o ponto onde o bug/mudança de fato vive.

## Ancoragem e verificação (obrigatório)

Toda referência a símbolo ou arquivo deve vir do dossiê (já existe) ou ser
marcada como **nova** (será criada). Nunca cite uma API que você não confirmou.

Antes de apresentar o **plano final** da abordagem escolhida, extraia as
afirmações sobre o código para um arquivo de claims e rode
`scripts/validate_proposal.sh`. Se acusar `missing` (símbolo/arquivo que deveria
existir mas não existe) ou `collision` (novo que já existe), **corrija a
proposta** — isso é sinal de alucinação ou de suposição errada.

## Impacto explícito

Rode `scripts/proposal_impact.sh` sobre os pontos que a abordagem escolhida vai
tocar. Traga para o plano: o que pode quebrar (dependentes), quais testes cobrem
o código tocado, e onde há lacuna de cobertura. O desenvolvedor não deve ser
surpreendido depois.

## O plano (após o dev escolher)

Só depois do checkpoint humano, elabore a abordagem escolhida em um plano:

1. **Decisões de arquitetura** — o que muda estruturalmente e **por quê**;
   registre como ADR no `design.md` (contexto, opções, escolha, consequências).
2. **Design dos componentes** — o que cada peça nova/alterada faz.
3. **Pontos de integração** — onde encosta em outros módulos/serviços.
4. **Avaliação de risco** — o que pode dar errado, e a mitigação.
5. **Detalhe crítico** — diff real só nas peças críticas.

## Tarefas

Quebre em tarefas pequenas, **ordenadas por dependência**, cada uma:

- implementável isoladamente;
- com **critério de aceitação verificável** (idealmente um teste);
- revisável sozinha — nunca um despejo gigante de mudanças.

Referencie os testes afetados (do impacto) e marque quais precisam ser criados.

## Honestidade

Termine o plano com **riscos e incertezas**: o que a análise estática não pôde
confirmar (DI, dispatch dinâmico, chamadas cross-service), suposições feitas, e
o que depende de validação em runtime. Um plano honesto sobre o que não sabe é
mais confiável que um que finge certeza.

## Anti-exemplo (não faça)

> "Proposta: refatorar o módulo de pricing para melhorar a manutenibilidade,
> aplicando boas práticas e desacoplando as responsabilidades."

Vago, sem trade-off, sem âncora. Compare:

> **Abordagem A — Patch mínimo no ponto do bug** (risco baixo, esforço baixo)
> Adiciona o teto de 40% em `PricingService.applyDiscount()`
> (`pricing/service.cs:94`). Prioriza reversibilidade; sacrifica: a regra de
> teto fica espalhada se surgirem outros pontos de desconto.
> Toca: `PricingService` (existente). Afeta 3 chamadores; teste
> `PricingServiceTests.Discount` cobre o caso.
>
> **Abordagem B — Política dedicada** (risco médio, esforço médio)
> Extrai o teto para `DiscountCapPolicy` (novo). Prioriza um único lugar para a
> regra; sacrifica: mais superfície e um ponto de integração novo em
> `applyDiscount()`. Toca: `PricingService` (mod) + `DiscountCapPolicy` (novo).
