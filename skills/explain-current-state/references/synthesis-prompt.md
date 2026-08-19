# Prompt de síntese — como escrever a explicação

Este é o único passo em que o LLM raciocina. Todo o resto do pipeline entregou
fatos determinísticos no `FeatureDossier`. Seu trabalho aqui é transformar esse
dossiê em uma explicação que um desenvolvedor entenda e possa discutir — não em
uma salada de buzzwords.

## O que faz uma explicação ser boa (e por quê)

Explicações de código costumam falhar por dois motivos: dão termos chiques
("camada de orquestração") sem dizer o que significam na prática, e param no *o
quê* sem tocar no *porquê*. Evite os dois. A estrutura abaixo é a receita.

### 1. Visão geral primeiro (a "visão da águia")

Comece com 2–4 frases que dão o mapa mental: qual é o papel dessa fatia, que
problema ela resolve, e quais são as poucas peças-chave. Sem detalhe de
implementação ainda. Se o desenvolvedor lesse só isso, já deveria saber "onde
está" no código.

### 2. Mergulho, mas condicional (o "deep dive")

Só então detalhe as peças — e **não uniformemente**. Para cada elemento tocado,
classifique a profundidade:

- **Trivial** → uma linha. ("`FormatDate` só formata a data para exibição.")
- **Significativo** → um parágrafo curto explicando o papel e como se conecta.
- **Crítico** → mostre o **trecho de código real** (ancorado em `arquivo:linha`)
  e explique o **efeito colateral** ou a razão de ser. Crítico = a escolha não é
  óbvia, é irreversível, toca um contrato/interface, ou é onde o bug/mudança vive.

Esta classificação é o que resolve "as explicações não entram no detalhe que
importa". O detalhe de código é caro e ruidoso quando aplicado a tudo; aplicado
só ao crítico, é exatamente o que o desenvolvedor precisa.

### 3. Sempre o "porquê"

Use a proveniência do dossiê (`provenance_b64`: commits, PRs). Quando souber por
que algo foi feito assim, diga. "Este retry foi adicionado no PR #412 por causa
de timeouts intermitentes do gateway" vale mais que "há um retry aqui".

### 4. Ancore tudo

Cada afirmação sobre o código aponta para `arquivo:linha`. O leitor precisa
poder verificar. Não parafraseie o código de forma vaga; cite o real.

### 5. Mostre o impacto

Do `blast_radius_b64`: quem chama e o que é chamado. Se houver um call graph,
renderize como Mermaid `graph TD`. Isso deixa claro o que a mudança futura vai
tocar.

## Regras de forma

- Blocos de código abaixo de ~20 linhas. Se precisar de mais, resuma e aponte.
- Prosa curta. Sem headers decorativos, sem encher linguiça.
- Português claro, direto, sem jargão gratuito.

## Honestidade sobre limites (obrigatório)

Termine com uma seção **"Pontos a confirmar"** listando o que a análise estática
não resolve. Consulte `confidence_note` e o `precision_tier` do dossiê:

- Se `tier1`/`tier0`: avise que as arestas de impacto são aproximadas.
- Marque explicitamente onde pode haver dispatch dinâmico, reflexão, injeção de
  dependência (DI) ou chamadas entre serviços que o grafo estático não pega.
- Se algum campo do dossiê veio vazio, diga — não invente para preencher.

Feche com **uma pergunta objetiva** ao desenvolvedor, para abrir a discussão
antes da proposta. Ex.: "Confirma que o cálculo de desconto vive só em
`PricingService`, ou há uma regra duplicada no front que eu não localizei?"

## Anti-exemplo (não faça)

> "O sistema de pricing opera através de uma arquitetura em camadas que
> orquestra a lógica de negócio com um mecanismo de resolução de descontos e
> gerenciamento de estado."

Isso não diz nada. Compare com:

> "O desconto é calculado em um único lugar: `PricingService.applyDiscount()`
> (`pricing/service.cs:88`). Ele lê a regra de `DiscountRule` e é chamado por 3
> pontos — checkout, preview de carrinho e a API de cotação. O caso do bug está
> na linha 94, onde descontos empilhados não são limitados ao teto de 40%
> (introduzido no PR #201, que não previa empilhamento)."
