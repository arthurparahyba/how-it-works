---
name: how-it-works
description: >-
  Investiga e explica como uma funcionalidade especifica esta implementada HOJE,
  antes de propor qualquer mudanca. Use esta skill sempre que o usuario for
  corrigir um bug, implementar uma feature, refatorar ou melhorar algo e precisar
  entender o codigo existente com clareza — especialmente antes de rodar
  "openspec propose" ou de escrever uma proposta. Tambem use quando pedirem
  "explique como funciona X", "entenda esse fluxo antes de mexer", "levante o que
  ja existe sobre Y", ou qualquer estudo de codigo escopado a uma mudanca. NAO
  documenta o repositorio inteiro — foca so na fatia relevante e produz uma
  explicacao discutivel (markdown + diagrama + trechos de codigo) para o
  desenvolvedor revisar e ajustar. Funciona em .NET, Java, Kotlin, Go, Python,
  Angular e React.
---

# How It Works

Esta skill executa a **fase 1** de um fluxo de duas fases: primeiro entender
*como e hoje* (esta skill), depois definir *o que fazer* (a proposta, que
alimenta o `openspec propose`). O objetivo aqui e produzir, de forma **rapida e
barata em tokens**, uma explicacao clara e no nivel de detalhe certo sobre a
implementacao atual da funcionalidade que sera alterada — para o desenvolvedor
discutir e ajustar *antes* de qualquer proposta existir.

O principio central: **ferramentas deterministicas coletam os fatos; o LLM so
julga e redige.** Fatos (estrutura, referencias, historico) nao devem passar
pelo modelo — devem ser coletados por scripts e entregues ja mastigados. Isso
corta tokens, acelera e evita alucinacao. O LLM entra uma unica vez, no fim.

## Quando NAO usar

- Para documentar o repositorio inteiro (esta skill e escopada a uma fatia).
- Para gerar a proposta de implementacao (isso e a fase 2 / `openspec propose`).
- Quando o usuario so quer uma resposta factual rapida sobre uma linha de codigo.

## O caminho normal — tres passos

Na grande maioria dos casos a skill inteira sao **tres** movimentos:

1. Derivar os termos de busca a partir do pedido (julgamento leve seu).
2. Rodar **`scripts/build_dossier.sh`** — um comando so, que faz toda a coleta.
3. Ler `references/synthesis-prompt.md` e escrever a explicacao.

O passo 3 e a **unica** chamada de raciocinio. Nunca inverta a ordem: coletar
antes, raciocinar depois.

**Agrupe o que e independente.** Ler o `synthesis-prompt.md` e rodar o
`build_dossier.sh` nao dependem um do outro — dispare os dois na mesma resposta.
Cada ida e volta separada reprocessa todo o contexto acumulado, e e ai que o
tempo de execucao vai, nao nos scripts (medido: ~5s de script contra ~218s de
modelo numa execucao real).

**Nao rode os scripts avulsos por padrao.** O `build_dossier.sh` ja executa
`detect_capabilities`, `locate_slice`, `expand_impact`, `collect_config` e
`enrich_provenance` por dentro. Roda-los antes e depois chamar o orquestrador
paga tudo duas vezes. Os passos detalhados abaixo existem para **refino**:
quando o dossie vier ruim e voce precisar ajustar um estagio isolado.

## Os estagios, para quando precisar refinar

### Passo 0 — Ler o mapa de design vivo, se existir

Antes de tudo, procure um mapa de design do projeto (o `detect_capabilities.sh`
reporta o caminho em `design_map.path`). Locais comuns:
`docs/design-map.md`, `ARCHITECTURE.md`, `openspec/specs/`.

Se existir, **leia-o primeiro**. Ele diz quais modulos existem, suas
responsabilidades e as costuras entre eles. Use-o como *prior*: ele aponta em
quais subdiretorios buscar, evitando varrer o repo inteiro. Se nao existir, o
pipeline funciona mesmo assim (so um pouco mais amplo na localizacao) — e ao
final sugira ao usuario criar um. (O racional completo esta em
`references/tiers-and-degradation.md`; **nao e leitura necessaria** para
executar a skill.)

### Passo 1 — Detectar capacidades

```bash
scripts/detect_capabilities.sh
```

Retorna JSON com: linguagens presentes, ferramentas disponiveis (ast-grep,
ripgrep, scip, gh), se ha indice SCIP em cache e se esta fresco, se ha mapa de
design, e o **`precision_tier`** resultante:

- `tier2` — indice SCIP fresco: referencias **precisas** (find-references reais).
- `tier1` — so ast-grep: arestas **estruturais aproximadas** (bom o suficiente).
- `tier0` — so texto/git: **ruidoso**, ultimo recurso.

Deixe o tier guiar quanta confianca atribuir ao raio de impacto adiante.

### Passo 2 — Traduzir a mudanca em termos de busca

A partir da descricao do usuario ("corrigir o bug no calculo de desconto"),
derive **termos de busca** (nomes provaveis de funcao/classe/rota/simbolo) e, se
o mapa de design deu pistas, os **modulos** a escopar. Isto e um julgamento leve
seu — nao uma chamada pesada. Prefira identificadores concretos a palavras
genericas.

### Passo 3 — Localizar a fatia

```bash
scripts/locate_slice.sh "termo1|termo2" modulo1 modulo2
```

Retorna as **sementes** (arquivo:linha:trecho). Se vier vazio, alargue os termos
ou remova o escopo de modulo e rode de novo. Se vier grande demais (>40 hits),
estreite. O objetivo e um punhado de arquivos-semente, nao uma lista enorme.

### Passo 4 — Expandir o raio de impacto (limitado)

Para o simbolo central da fatia:

```bash
scripts/expand_impact.sh "NomeDoSimbolo" 1 "<caminho_do_indice_scip_ou_vazio>"
```

Expande **1 salto** (chamadores + chamados), ranqueado, com cap no top-N. Use 2
saltos **apenas** se a mudanca for critica ou o raio for ambiguo — 2 saltos
custam caro e crescem rapido. Em `tier2` as arestas sao precisas; em `tier1`,
aproximadas; sempre trate como incompletas onde houver dispatch dinamico,
reflexao, injecao de dependencia (comum em .NET/Spring) ou chamadas entre
servicos.

### Passo 4b — Coletar a camada de configuracao/schema

```bash
scripts/collect_config.sh "termos|de|busca" "SimboloCentral"
```

Metade do comportamento de um sistema Spring/.NET **nao esta no codigo**: o tipo
e a collation de uma coluna, o profile ativo, um feature flag, um binding de
rota. Uma explicacao que olha so `.java`/`.cs` sai correta e cega.

O script converte a nomenclatura entre camadas (`lastName` no codigo vira
`last_name` no SQL, `last-name` no YAML, `LAST_NAME` no `.env`) — sem isso a
busca falha em silencio — e ranqueia: schema/migration/config de app primeiro,
i18n e seeds so como amostra. O `build_dossier.sh` ja o executa; o campo sai em
`config_b64`.

### Passo 5 — Montar o dossie

Em vez de rodar os passos 1–4 na mao, prefira o orquestrador, que faz tudo e
emite o **FeatureDossier** compacto (JSON) de uma vez:

```bash
scripts/build_dossier.sh "descricao da mudanca" "termos|de|busca" "SimboloCentral" modulo1 modulo2
```

Sai em **markdown**, legivel com um unico `cat`. Leia-o inteiro de uma vez.

Se uma secao vier marcada **VAZIO**, ela traz junto o motivo provavel — trate
isso como sinal, nao como resultado. Em especial: *Raio de impacto* vazio quase
sempre significa que o simbolo central esta errado, nao que ninguem depende
dele. O nome real costuma estar nas *Ocorrencias*, logo acima.

Para o handoff da fase 2, que precisa de estrutura, gere tambem a versao JSON:

```bash
scripts/build_dossier.sh --json "descricao" "termos" "Simbolo" modulos... \
  > openspec/changes/<id>/current-state.dossier.json
```

Nao leia o JSON para sintetizar: ele carrega os blocos em base64, o que faz
voce pagar duas vezes pelo mesmo conteudo (medido: 6.884 tokens em JSON contra
3.114 em markdown). (O schema esta em `references/dossier-schema.md`; **nao e
leitura necessaria** para executar a skill.)

**Regra de economia (e seu limite).** O dossie e o sinal denso: nao varra o repo
atras de mais contexto, nao leia arquivo que ele nao apontou. Mas ele entrega
*linhas isoladas*, e o template exige trecho real para as pecas **criticas** —
entao abrir os poucos arquivos que o dossie ja apontou como criticos e parte do
trabalho, nao desperdicio. O que desperdica e ler o que ele nao apontou.

### Passo 6 — Sintetizar a explicacao (unica chamada do LLM)

Agora, e so agora, raciocine. Leia `references/synthesis-prompt.md` — **um
arquivo, uma leitura** — e siga-o a risca. Ele traz a filosofia (visao geral
antes do detalhe, "porque" e nao so "o que", ancorado no codigo real, detalhe de
codigo **condicional** a criticidade) e, no fim, o formato de saida.

Regra de profundidade condicional (o que resolve "explicacoes rasas"): para cada
elemento tocado, classifique como **trivial / significativo / critico**. Trivial
= uma linha. Critico = mostre o trecho de codigo real e explique o efeito
colateral. Nunca detalhe uniformemente tudo; nunca pare no "o que" para o que e
critico.

### Passo 7 — Conferir as ancoras (obrigatorio, antes de entregar)

```bash
scripts/check_anchors.sh <arquivo-da-explicacao>
```

Voce afirmou dezenas de vezes "isto esta em `arquivo:linha`". Confira antes de
entregar — um `sed -n '343p'` responde com certeza, nao ha por que voce se
auto-auditar.

A ancora e a promessa de que o leitor pode verificar. Uma errada nao estraga uma
frase, estraga o documento: quem confere uma, nao acha, e passa a desconfiar de
todas — inclusive das certas.

A saida vem em tres niveis:

- **ANCORAS QUEBRADAS** — arquivo inexistente, linha alem do fim, linha em
  branco. Sem duvida possivel: **corrija**. O script diz qual e a declaracao
  seguinte, entao o conserto costuma ser trocar um numero.
- **A CONFERIR** — o nome que voce citou nao aparece perto daquela linha. Pode
  ser legitimo (a ancora aponta um bloco, nao uma declaracao) ou pode ser erro.
  **Olhe cada um.** O que nao vale e ignorar sem olhar.
- **MAPA DAS ANCORAS** — cada ancora e o metodo que a contem. Leia comparando
  com o que voce escreveu: se o mapa diz `UpdateItem()` e o seu texto diz
  "quando o item e criado", os numeros estao trocados. Foi assim que um erro
  real passou por todas as outras checagens.

## Formatos de saida

Escolha o formato pelo **tipo de informacao**, nao um fixo:

- Relacao entre componentes / fluxo → **diagrama Mermaid** (o call graph do
  dossie vira `graph TD`).
- Mudanca pontual critica → **trecho de codigo** anotado (ancore em arquivo:linha).
- Sequencia de passos / estado atual → **prosa curta + lista**.

A explicacao e um artefato para o humano revisar. Termine sempre com a secao
"Pontos a confirmar" (as lacunas que a analise estatica nao resolve) e uma
pergunta objetiva ao desenvolvedor.

## Handoff para a fase 2 / OpenSpec

Depois que o desenvolvedor comentar/ajustar, o dossie + a explicacao validada
sao o insumo da proposta. Salve-os em um local estavel do pacote de mudanca
(ex.: `openspec/changes/<id>/current-state.md`) para que o `openspec propose`
parta de um entendimento ja fundamentado, em vez de disparar as cegas. Veja
`references/tiers-and-degradation.md` e a pasta `docs/` do repositorio para o
racional completo.

## Lembrete de custo e honestidade

- Trabalho frio (build de indice SCIP, refresh do mapa) roda **fora** desta
  skill — em CI/background. Aqui so se **le** cache. Nunca construa indice no
  caminho quente.
- O dossie nunca finge completude. Se um campo veio vazio ou o tier e baixo,
  diga isso na explicacao. Um mapa/aresta errado engana mais que a ausencia.
