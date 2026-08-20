#!/usr/bin/env bash
# collect_config.sh
# Coleta a camada de CONFIGURACAO/SCHEMA da fatia: schemas SQL, migrations,
# properties/yaml/json/xml de configuracao.
#
# Por que este campo existe: em Spring/Java e .NET metade do comportamento vive
# FORA do codigo — o tipo e a collation de uma coluna, o profile ativo, um
# feature flag, um binding de rota. No petclinic, a busca de owners so e
# insensivel a maiusculas porque `db/h2/schema.sql` declara VARCHAR_IGNORECASE;
# no Postgres a mesma coluna e TEXT e a busca vira sensivel. Nenhum arquivo .java
# diz isso. Sem esta coleta o dossie gera explicacoes corretas e cegas.
#
# Uso: ./collect_config.sh "termo1|termo2" [simbolo]

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/lib/common.sh"

TERMS="${1:?informe os termos de busca}"
SYMBOL="${2:-}"
MAX_HITS=20
MAX_LOW=6      # amostra de config de baixo valor (i18n, seeds)
MAX_FILES=400

cd "$(repo_root)" || exit 1

CONFIG_RE='\.(sql|properties|ya?ml|json|toml|ini|conf|cfg|env|xml|tf|gradle)$'
NOISE_RE='(^|/)(node_modules|target|build|dist|bin|obj|vendor|\.venv)/|(package|yarn|pnpm)-lock|\.min\.'

CONFIG_FILES="$(git ls-files 2>/dev/null \
  | grep -iE "$CONFIG_RE" | grep -viE "$NOISE_RE" | head -n "$MAX_FILES")"

if [ -z "$CONFIG_FILES" ]; then
  warn "nenhum arquivo de configuracao/schema localizado"
  exit 0
fi

# Variantes de nomenclatura: config quase nunca usa a mesma convencao do codigo.
# `lastName` no Java e `last_name` no SQL, `last-name` no YAML, `LAST_NAME` no
# .env. Buscar so o termo original faz a coleta falhar silenciosamente.
variants_of() {
  local t="$1" snake
  snake="$(printf '%s' "$t" | sed 's/\([a-z0-9]\)\([A-Z]\)/\1_\2/g' | tr 'A-Z' 'a-z')"
  printf '%s\n' "$t" "$snake" \
    "$(printf '%s' "$snake" | tr '_' '-')" \
    "$(printf '%s' "$snake" | tr -d '_')"
}

ALL_TERMS=""
_oifs="$IFS"; IFS='|'
for t in $TERMS; do
  [ -z "$t" ] && continue
  IFS="$_oifs"
  ALL_TERMS="$ALL_TERMS
$(variants_of "$t")"
  IFS='|'
done
IFS="$_oifs"
[ -n "$SYMBOL" ] && ALL_TERMS="$ALL_TERMS
$(variants_of "$SYMBOL")"

# alternancia unica, termos com >=3 chars (evita casar ruido)
PATTERN="$(printf '%s\n' "$ALL_TERMS" | grep -v '^$' | awk 'length($0) >= 3' \
           | sort -u | tr '\n' '|' | sed 's/|$//')"
[ -z "$PATTERN" ] && exit 0

# Nem todo arquivo de config vale o mesmo. Schema, migration e config de app
# definem COMPORTAMENTO; bundle de i18n e seed de dados sao quase sempre ruido
# nesta fatia. Sem ranquear, 10 linhas de `messages_*.properties` consomem o cap
# e empurram para fora a linha do schema que decide o caso.
HIGH_RE='(schema|migration|changelog|liquibase|flyway|application|appsettings|\.env|(^|/)config)'
LOW_RE='(data|seed|fixture)\.(sql|json|ya?ml)$|(^|/)(messages|i18n|locales?|translations?)(/|_|\.)'

hits_for() {   # $1 = lista de arquivos, $2 = max linhas por arquivo
  printf '%s\n' "$1" | while IFS= read -r f; do
    [ -f "$f" ] || continue
    # grep com arquivo nomeado nao le o stdin: seguro dentro do laco.
    grep -inE -- "$PATTERN" "$f" 2>/dev/null | head -"$2" | sed "s#^#${f}:#"
  done
}

HIGH_FILES="$(printf '%s\n' "$CONFIG_FILES" | grep -iE "$HIGH_RE" | grep -viE "$LOW_RE")"
LOW_FILES="$(printf '%s\n' "$CONFIG_FILES" | grep -viE "$HIGH_RE")"

echo "### Schema / config que define comportamento (prioritario)"
[ -n "$HIGH_FILES" ] && hits_for "$HIGH_FILES" 4 | head -n "$MAX_HITS"

LOW_HITS="$( [ -n "$LOW_FILES" ] && hits_for "$LOW_FILES" 1 )"
if [ -n "$LOW_HITS" ]; then
  n_low="$(printf '%s\n' "$LOW_HITS" | grep -c .)"
  echo
  echo "### Outros arquivos de config que citam a fatia (i18n, seeds — amostra de $n_low)"
  printf '%s\n' "$LOW_HITS" | head -n "$MAX_LOW"
fi

# Config de aplicacao entra SEMPRE, casando termo ou nao. Ela raramente cita o
# nome do campo que voce buscou, mas e quem decide QUAL das variantes esta
# ativa. No petclinic, `application.properties` nao contem "lastName" nem
# "last_name" — contem `database=h2`, que e o que torna acionavel a divergencia
# de collation entre os tres schema.sql. Sem isto o dossie mostra tres
# comportamentos possiveis e nao diz qual vale.
APP_CFG="$(printf '%s\n' "$CONFIG_FILES" \
  | grep -iE '(^|/)(application|appsettings|settings|config|bootstrap)[^/]*\.(properties|ya?ml|json|toml)$|(^|/)\.env' \
  | head -5)"
if [ -n "$APP_CFG" ]; then
  echo
  echo "### Config de aplicacao (sempre incluida — diz qual ambiente/profile esta ativo)"
  printf '%s\n' "$APP_CFG" | while IFS= read -r f; do
    [ -f "$f" ] || continue
    # linhas com conteudo: sem comentario, sem vazia. Estes arquivos sao curtos.
    grep -vE '^[[:space:]]*([#!;]|//|$)' "$f" 2>/dev/null | head -10 | sed "s#^#${f}:#"
  done | head -25
fi

# Os arquivos de schema/migration merecem ser listados mesmo sem casar termo:
# a ausencia de match pode significar convencao de nome diferente, nao ausencia
# de relevancia. O LLM decide se vale abrir.
echo
echo "### Schemas e migrations do projeto (contexto, podem nao ter casado termo)"
printf '%s\n' "$CONFIG_FILES" \
  | grep -iE '\.sql$|(^|/)(migrations?|schema|db)/' | head -15

warn "Config/schema e evidencia de COMPORTAMENTO: tipo de coluna, collation, profile"
warn "ativo e feature flag mudam o que o codigo faz sem que o codigo mude."
exit 0
