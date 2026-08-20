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
NEG_RE='n[aã]o (existe|h[aá]|possui|tem|e |é |usa|passa)|inexistente|ausente|nenhum[a]?|sem (camada|servi[cç]o)'
hasnt() {
  local achado
  achado="$(grep -viE -- "$NEG_RE" "$OUT" 2>/dev/null | grep -oiE -- "$2" | sort -u | head -3 | tr '\n' ' ')"
  if [ -n "$achado" ]; then
    printf '  [FALHA] %s  <- citou: %s\n' "$1" "$achado"; FAIL=$((FAIL+1))
  else
    printf '  [ok]    %s\n' "$1"; PASS=$((PASS+1))
  fi
}

echo "caso: $CASE"
echo "saida: $OUT"
echo

case "$CASE" in
  petclinic-busca-owner)
    has   "ancora em arquivo:linha"                    '[A-Za-z0-9_/.-]+\.(java|sql|html|properties):[0-9]+'
    has   "cita o ponto de entrada processFindForm"    'processFindForm'
    has   "explica que a busca e por prefixo"          'StartingWith|prefixo'
    has   "cita o pageSize cravado"                    'pageSize|PageRequest|tamanho de p[aá]gina'
    has   "cita o schema SQL como origem do comportamento" 'schema\.sql|VARCHAR_IGNORECASE'
    has   "distingue os bancos (h2 vs postgres)"       '(h2|H2).*(postgres|Postgres)|(postgres|Postgres).*(h2|H2)'
    has   "usa a proveniencia para explicar um porque" 'bb37aad|c7ee170|2589|whitespace|espa[cç]o em branco'
    has   "sinaliza resolucao em runtime (Spring Data/DI)" 'runtime|Spring Data|derivada do nome|proxy'
    has   "tem a secao Pontos a confirmar"             '^#+.*Pontos a confirmar'
    has   "termina com pergunta objetiva"              '\?'
    hasnt "nao inventa implementacao do repositorio"   'OwnerRepositoryImpl|OwnerServiceImpl|OwnerService\b'
    hasnt "nao afirma case-insensitive sem qualificar" 'sempre (e|é) (case-)?insens[ií]vel'
    ;;
  petclinic-cancelar-visita-inexistente)
    has   "afirma explicitamente que nao existe hoje"  'n[aã]o existe|inexistente|n[aã]o h[aá] (nenhum|funcionalidade|endpoint|fluxo)'
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
    has   "identifica o fallback para a busca textual"  '(fallback|cai de volta|volta para|recorre a|degrada).{0,80}(GetItemsByName|textual)|GetItemsByName.{0,60}(fallback|silencios)'
    has   "diz que o fallback e silencioso"             'silencios|sem (avisar|sinalizar|indicar)|nao (avisa|sinaliza|indica|informa)'
    has   "liga IsEnabled ao gerador de embedding"      'IsEnabled.{0,120}(_?embeddingGenerator|IEmbeddingGenerator)|(_?embeddingGenerator|IEmbeddingGenerator).{0,120}IsEnabled'
    has   "liga o comportamento a config + DI"          '(OllamaEnabled|textEmbeddingModel)'
    has   "cita o registro condicional no DI"           '(DI|inje[cç][aã]o de depend|AddScoped|AddEmbeddingGenerator|registr)'
    has   "cita a distancia de cosseno / pgvector"      'CosineDistance|cosseno|pgvector|Vector'
    has   "sinaliza o DI como limite da analise"        '(DI|inje[cç][aã]o|runtime|configura[cç][aã]o).{0,160}(n[aã]o (aparece|e vis[ií]vel|enxerga)|limite|est[aá]tic)|est[aá]tic.{0,160}(DI|inje[cç][aã]o)'
    has   "tem a secao Pontos a confirmar"              '^#+.*Pontos a confirmar'
    has   "termina com pergunta objetiva"               '\?'
    hasnt "nao afirma que a busca semantica sempre ocorre" 'sempre (usa|faz|executa|realiza) (a )?busca sem[aâ]ntica'
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
