#!/usr/bin/env bash
# detect_capabilities.sh
# Detecta o que o ambiente oferece e decide o nivel de precisao alcancavel.
# Saida: JSON no stdout com as capacidades. Nao constroi nada, so inspeciona.
#
# Uso: ./detect_capabilities.sh [caminho_do_repo]

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/lib/common.sh"

ROOT="${1:-$(repo_root)}"
cd "$ROOT" || { echo '{"error":"repo inacessivel"}'; exit 1; }

log "detectando capacidades em: $ROOT"

# --- linguagens presentes (por extensao) ------------------------------------
# Lista "lang:ext,ext" em vez de array associativo: `declare -A` exige bash 4+
# e o macOS ainda entrega bash 3.2 (Linux e Git Bash trazem 4+, mas o script
# precisa rodar nos tres). Sem isto, este bloco falha e "languages" sai vazio.
LANG_EXTS="csharp:cs java:java kotlin:kt,kts go:go python:py typescript:ts,tsx javascript:js,jsx"
langs=""
_oifs="$IFS"
for entry in $LANG_EXTS; do
  lang="${entry%%:*}"; exts="${entry#*:}"
  IFS=','
  for ext in $exts; do
    IFS="$_oifs"
    if git ls-files "*.${ext}" 2>/dev/null | head -1 | grep -q . ; then
      langs="$langs $lang"; break
    fi
    IFS=','
  done
  IFS="$_oifs"
done
IFS="$_oifs"

# --- ferramentas da camada estrutural ---------------------------------------
AG="$(astgrep_bin)"
has_astgrep=false; [ -n "$AG" ] && has_astgrep=true
has_ripgrep=false; have rg && has_ripgrep=true
has_gh=false;      have gh && has_gh=true
has_scip_cli=false; have scip && has_scip_cli=true

# --- indice SCIP em cache? --------------------------------------------------
# Procuramos por um index.scip ja construido (o passo caro do caminho frio).
scip_index=""
for cand in index.scip .scip/index.scip build/index.scip .cache/scip/index.scip; do
  if [ -f "$cand" ]; then scip_index="$cand"; break; fi
done
has_scip_index=false; [ -n "$scip_index" ] && has_scip_index=true

# frescor do indice: comparamos o commit gravado (se houver) com HEAD.
scip_fresh="unknown"
if [ -n "$scip_index" ] && have scip; then
  head_commit="$(git rev-parse HEAD 2>/dev/null)"
  # heuristica leve: mtime do indice novo o suficiente vs ultimo commit.
  idx_mtime=$(stat -c %Y "$scip_index" 2>/dev/null || stat -f %m "$scip_index" 2>/dev/null || echo 0)
  head_mtime=$(git log -1 --format=%ct 2>/dev/null || echo 0)
  if [ "$idx_mtime" -ge "$head_mtime" ]; then scip_fresh="fresh"; else scip_fresh="stale"; fi
fi

# --- mapa de design vivo? ---------------------------------------------------
design_map=""
for cand in docs/design-map.md ARCHITECTURE.md docs/architecture.md openspec/specs/README.md .claude/design-map.md; do
  if [ -f "$cand" ]; then design_map="$cand"; break; fi
done
has_design_map=false; [ -n "$design_map" ] && has_design_map=true

# --- o repo aparenta ser construivel? (heuristica, nao build de fato) --------
buildable=false
for marker in "*.sln" "*.csproj" pom.xml build.gradle build.gradle.kts go.mod \
              pyproject.toml setup.py tsconfig.json package.json; do
  if git ls-files "$marker" 2>/dev/null | head -1 | grep -q . ; then buildable=true; break; fi
done

# --- nivel de precisao resultante -------------------------------------------
# tier2 = referencias precisas (SCIP fresco). tier1 = estrutural (ast-grep).
# tier0 = so texto/git (ripgrep). Escolhemos o teto disponivel.
tier="tier1"
if $has_scip_index && [ "$scip_fresh" = "fresh" ] && $has_scip_cli; then
  tier="tier2"
elif ! $has_astgrep; then
  tier="tier0"
fi

# --- o que falta para subir de tier -----------------------------------------
# Reportar so "tier0" nao ajuda ninguem: quem le nao sabe que da para melhorar
# nem como. A skill NAO instala nada — instalar e decisao do dono da maquina, o
# gerenciador varia por sistema, e a degradacao graciosa e escolha de desenho,
# nao defeito a contornar. Ela informa; a pessoa decide.
upgrade=""
if [ "$tier" = "tier0" ]; then
  upgrade="Sem ast-grep: as arestas de impacto sao casamento de texto. Instalando-o, a skill passa a casar por tipo de no do tree-sitter (definicao vs chamada vs referencia). Instale com: brew install ast-grep | npm i -g @ast-grep/cli | cargo install ast-grep"
elif [ "$tier" = "tier1" ]; then
  upgrade="Sem indice SCIP: as arestas sao estruturais mas locais. Um indice construido no caminho frio (CI) daria find-references reais. Ver docs/05-performance.md."
fi

# --- emite JSON --------------------------------------------------------------
join() { local IFS=,; echo "$*"; }
langs_json="["; first=true
for l in $langs; do
  $first || langs_json+=","; langs_json+="\"$l\""; first=false
done
langs_json+="]"

cat << JSON
{
  "root": "$(json_escape "$ROOT")",
  "languages": $langs_json,
  "tools": {
    "ast_grep": $has_astgrep,
    "ripgrep": $has_ripgrep,
    "scip_cli": $has_scip_cli,
    "gh": $has_gh
  },
  "scip_index": { "present": $has_scip_index, "path": "$(json_escape "$scip_index")", "freshness": "$scip_fresh" },
  "design_map": { "present": $has_design_map, "path": "$(json_escape "$design_map")" },
  "buildable": $buildable,
  "precision_tier": "$tier",
  "upgrade_hint": "$(json_escape "$upgrade")"
}
JSON

log "tier de precisao: $tier | linguagens: ${langs:-nenhuma}"
