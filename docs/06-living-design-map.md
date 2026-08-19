# 06 — Mapa de design vivo

## Por que existe

O passo mais caro e mais propenso a erro do pipeline é **localizar a fatia
certa**. Errar aqui contamina tudo depois. Um mapa de design vivo funciona como
um *prior*: faz o localizador pular direto para o módulo certo, dando as três
coisas de uma vez — mais rápido, mais preciso, mais objetivo.

Ele também é o terceiro insumo da explicação (ao lado dos fatos determinísticos
e do LLM), dando ao modelo a intenção de design que nenhuma ferramenta estática
infere: por que os limites de módulo são esses, quais as costuras entre serviços,
quais invariantes existem.

## Como não apodrecer

Doc à mão apodrece (o "monstro de markdown"). Regra:

- **Gerar/atualizar a camada estrutural automaticamente e de rotina**: árvore de
  diretórios principais, responsabilidades de módulo, entry points, arestas de
  dependência — tudo derivável de tree-sitter/ast-grep/SCIP/grafos.
- **Curar à mão só a camada de intenção**: o "porquê", que é pequeno e estável.
- Um job de CI regenera o estrutural, faz diff contra o commitado e **abre PR
  quando a estrutura derivou**. A deriva vira sinal, não mentira silenciosa.

## Forma

Básica e hierárquica: um mapa de topo (app inteira, diretórios principais,
costuras) + mini-mapas opcionais por módulo. O tool lê o topo para achar o
módulo, o mini-mapa para orientação fina, e só então roda a análise escopada.
Exaustivo = apodrece e custa caro; básico = vive.

## Localização sugerida

`docs/design-map.md` no repo-alvo (ou `ARCHITECTURE.md`, ou `openspec/specs/`).
O `detect_capabilities.sh` procura nesses caminhos.

## Trust-but-verify

Um mapa errado engana mais que a ausência dele. A camada determinística deve
**validar as afirmações do mapa contra a realidade** e sinalizar deriva. O mapa
nunca é lei — é ponto de partida verificável.

Ver [decisions/0004-living-design-map.md](decisions/0004-living-design-map.md).
