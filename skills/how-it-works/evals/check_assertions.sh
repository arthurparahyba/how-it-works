#!/usr/bin/env bash
# check_assertions.sh
# Verifica as asserções PROGRAMÁTICAS de um caso contra uma explicação já
# produzida. Só o que é objetivamente verificável entra aqui — "a visão geral é
# útil?" precisa de julgamento e fica para o agente juiz (campo `rubrica`).
#
# Uso: ./check_assertions.sh <nome-do-caso> <arquivo-da-explicacao>
# Saída: uma linha por asserção + resumo. Código 0 se todas passarem.

set -o pipefail
CASE="${1:?informe o nome do caso (ver evals.json)}"
OUT="${2:?informe o arquivo com a explicacao gerada}"
[ -f "$OUT" ] || { echo "arquivo nao encontrado: $OUT"; exit 2; }

PASS=0; FAIL=0

# Nota de portabilidade: os regexes evitam classes de caractere acentuadas do
# tipo [aã] ou [cç]. Combinadas com `-i`, elas multiplicam as alternativas e o
# ugrep (grep padrão em algumas máquinas) recusa o padrão inteiro com
# "exceeds complexity limits" — falhando em silêncio, como se a asserção não
# tivesse casado. Um `.` simples cobre a letra com e sem acento e não explode.

# has <descricao> <regex>       -> a explicacao PRECISA casar
# hasnt <descricao> <regex>     -> a explicacao NAO PODE casar (anti-alucinacao)
has() {
  if grep -qiE -- "$2" "$OUT" 2>/dev/null; then
    printf '  [ok]    %s\n' "$1"; PASS=$((PASS+1))
  else
    printf '  [FALHA] %s\n' "$1"; FAIL=$((FAIL+1))
  fi
}
# Uma explicacao BOA frequentemente cita o simbolo inexistente para dizer que
# ele NAO existe ("nao ha OwnerService, a busca fala direto com o repositorio").
# Um `grep` ingenuo reprova isso — foi o que aconteceu na primeira versao deste
# arquivo. Por isso as linhas com negacao sao descartadas antes do teste: so
# resta alucinacao de verdade, o simbolo citado como se existisse.
NEG_RE='n.o (existe|h.|possui|tem|e |é |usa|passa)|inexistente|ausente|nenhum[a]?|sem (camada|servi.o)'
# has2: exige que UMA MESMA LINHA case os dois padrões. Substitui o truque de
# `A.{0,400}B` num regex só, que com `-i` e UTF-8 estoura o limite de
# complexidade do ugrep — e o pior é que ele falha em silêncio, contando como
# asserção não-casada em vez de erro. Dois greps encadeados são triviais para
# qualquer implementação.
has2() {
  if grep -iE -- "$2" "$OUT" 2>/dev/null | grep -qiE -- "$3" 2>/dev/null; then
    printf '  [ok]    %s\n' "$1"; PASS=$((PASS+1))
  else
    printf '  [FALHA] %s\n' "$1"; FAIL=$((FAIL+1))
  fi
}

hasnt() {
  local achado
  achado="$(grep -viE -- "$NEG_RE" "$OUT" 2>/dev/null | grep -oiE -- "$2" | sort -u | head -3 | tr '\n' ' ')"
  if [ -n "$achado" ]; then
    printf '  [FALHA] %s  <- citou: %s\n' "$1" "$achado"; FAIL=$((FAIL+1))
  else
    printf '  [ok]    %s\n' "$1"; PASS=$((PASS+1))
  fi
}

# ---------------------------------------------------------------------------
# Checagens de FORMA — valem para todo caso, porque são sobre disciplina de
# escrita, não sobre o conteúdo de um repositório específico.
# ---------------------------------------------------------------------------
form_checks() {
  local n_crit n_lines creep

  # Teto de 3 peças críticas. Sem teto, tudo vira crítico e a hierarquia some.
  n_crit="$(grep -cE '^#{3,} *Cr[ií]tic[ao]' "$OUT" 2>/dev/null | tr -dc '0-9')"
  if [ "${n_crit:-0}" -le 3 ]; then
    printf '  [ok]    no maximo 3 pecas criticas (tem %s)\n' "$n_crit"; PASS=$((PASS+1))
  else
    printf '  [FALHA] %s pecas criticas — o teto e 3; rebaixe a mais fraca\n' "$n_crit"; FAIL=$((FAIL+1))
  fi

  # Orçamento de tamanho. Não é limite rígido; é sinal de que passou do ponto.
  n_lines="$(grep -c '' "$OUT" 2>/dev/null | tr -dc '0-9')"
  if [ "${n_lines:-0}" -le 150 ]; then
    printf '  [ok]    tamanho dentro do orcamento (%s linhas)\n' "$n_lines"; PASS=$((PASS+1))
  else
    printf '  [FALHA] %s linhas — orcamento e ~120, teto 150\n' "$n_lines"; FAIL=$((FAIL+1))
  fi

  # Escorregar para proposta. Só o corpo conta: a pergunta final PODE nomear
  # direções, desde que em forma de pergunta. Corta o texto no marcador dela.
  creep="$(sed '/^\*\*Pergunta para voc.\*\*/,$d' "$OUT" 2>/dev/null \
           | grep -icE 'basta (adicionar|trocar|criar)|o alvo mais (barato|direto)|a melhoria mais (direta|barata)|seria melhor|recomendo|sugiro que' | tr -dc '0-9')"
  if [ "${creep:-0}" -eq 0 ]; then
    printf '  [ok]    descreve o presente, nao propoe solucao\n'; PASS=$((PASS+1))
  else
    printf '  [FALHA] %s frase(s) propondo solucao fora da pergunta final (fase 2)\n' "$creep"; FAIL=$((FAIL+1))
  fi
}

echo "caso: $CASE"
echo "saida: $OUT"
echo
form_checks

case "$CASE" in
  petclinic-busca-owner)
    has   "ancora em arquivo:linha"                    '[A-Za-z0-9_/.-]+\.(java|sql|html|properties):[0-9]+'
    has   "cita o ponto de entrada processFindForm"    'processFindForm'
    has   "explica que a busca e por prefixo"          'StartingWith|prefixo'
    has   "cita o pageSize cravado"                    'pageSize|PageRequest|tamanho de p.gina'
    has   "cita o schema SQL como origem do comportamento" 'schema\.sql|VARCHAR_IGNORECASE'
    has   "distingue os bancos (h2 vs postgres)"       '(h2|H2).*(postgres|Postgres)|(postgres|Postgres).*(h2|H2)'
    has   "usa a proveniencia para explicar um porque" 'bb37aad|c7ee170|2589|whitespace|espa.o em branco'
    has   "sinaliza resolucao em runtime (Spring Data/DI)" 'runtime|Spring Data|derivada do nome|proxy'
    has   "tem a secao Pontos a confirmar"             '^#+.*Pontos a confirmar'
    has   "termina com pergunta objetiva"              '\?'
    hasnt "nao inventa implementacao do repositorio"   'OwnerRepositoryImpl|OwnerServiceImpl|OwnerService\b'
    hasnt "nao afirma case-insensitive sem qualificar" 'sempre (e|é) (case-)?insens.vel'
    ;;
  petclinic-cancelar-visita-inexistente)
    has   "afirma explicitamente que nao existe hoje"  'n.o existe|inexistente|n.o h. (nenhum|funcionalidade|endpoint|fluxo)'
    has   "descreve o que existe (criacao de visita)"  'visits/new|processNewVisitForm|initNewVisitForm'
    has   "cita a colecao de visitas em Pet"           'Pet\.java|addVisit|OneToMany|visits'
    has   "tem a secao Pontos a confirmar"             '^#+.*Pontos a confirmar'
    # Distinguir "afirma que X existe" de "propõe onde X deveria ficar" é
    # justamente o que grep não faz bem — e num caso negativo a segunda forma é
    # o comportamento DESEJADO ("o simétrico Owner.cancelVisit é o lugar
    # coerente para a regra"). Programaticamente só se pega o caso inequívoco:
    # o símbolo inexistente ancorado em arquivo:linha, que é afirmação de que
    # ele está lá. O resto vai para a rubrica, que precisa de julgamento.
    hasnt "nao ancora simbolo inexistente em arquivo:linha" \
          '(deleteVisit|cancelVisit|removeVisit|VisitService|VisitRepository)[^.]{0,80}\.(java|kt|cs):[0-9]+|[A-Za-z]+\.(java|kt|cs):[0-9]+[^.]{0,80}(deleteVisit|cancelVisit|removeVisit|VisitService)'
    ;;
  eshop-busca-semantica)
    has   "ancora em arquivo:linha"                     '[A-Za-z0-9_/.-]+\.(cs|json):[0-9]+'
    has   "cita o endpoint da busca semantica"          'withsemanticrelevance'
    has   "cita o metodo GetItemsBySemanticRelevance"   'GetItemsBySemanticRelevance'
    # Testa o CONCEITO, nao o vocabulario: uma explicacao boa pode dizer "busca
    # comum por nome" em vez de "fallback textual". A primeira versao desta
    # assercao exigia a palavra `fallback` e reprovava a versao sem jargao.
    has2  "identifica a queda para a busca comum por nome" \
          'GetItemsByName|busca (comum|textual|por nome)' \
          'fallback|cai de volta|volta para|recorre|degrada|vira|faz|silencios|comum|nome'
    has   "diz que o fallback e silencioso"             'silencios|sem (avisar|sinalizar|indicar)|nao (avisa|sinaliza|indica|informa)'
    has   "liga IsEnabled ao gerador de embedding"      'IsEnabled.{0,120}(_?embeddingGenerator|IEmbeddingGenerator)|(_?embeddingGenerator|IEmbeddingGenerator).{0,120}IsEnabled'
    has   "liga o comportamento a config + DI"          '(OllamaEnabled|textEmbeddingModel)'
    has   "cita o registro condicional no DI"           '(DI|inje..o de depend|AddScoped|AddEmbeddingGenerator|registr)'
    has   "cita a distancia de cosseno / pgvector"      'CosineDistance|cosseno|pgvector|Vector'
    has2  "sinaliza o DI como limite da analise" \
          'DI|inje..o de depend|runtime' \
          'n.o (aparece|mostra|enxerga|e vis.vel)|limite|est.tic|precisa rodar|s. .{0,15}runtime'
    has   "tem a secao Pontos a confirmar"              '^#+.*Pontos a confirmar'
    has   "termina com pergunta objetiva"               '\?'
    hasnt "nao afirma que a busca semantica sempre ocorre" 'sempre (usa|faz|executa|realiza) (a )?busca sem.ntica'
    hasnt "nao inventa simbolo inexistente"             'CatalogSearchService|SemanticSearchService|ISemanticSearch|EmbeddingService\b'
    ;;
  *)
    echo "caso desconhecido: $CASE"; exit 2 ;;
esac

echo
TOTAL=$((PASS+FAIL))
echo "resultado: $PASS/$TOTAL asserções programáticas"
[ "$FAIL" -eq 0 ] || echo "(a rubrica subjetiva do evals.json ainda precisa do agente juiz)"
[ "$FAIL" -eq 0 ]
