# CLAUDE.md

Leia **[AGENTS.md](AGENTS.md)** primeiro. Ele explica o que é este repositório,
o princípio que governa o desenho, onde está cada coisa, e — importante — a
lista de armadilhas que já custaram caro e não devem ser reintroduzidas.

Atalhos para o que se mexe com mais frequência:

| Você quer... | Vá em |
|---|---|
| mudar o que o modelo faz ao ser invocado | `skills/how-it-works/SKILL.md` |
| mudar como a explicação é escrita | `skills/how-it-works/references/synthesis-prompt.md` |
| mudar a coleta determinística | `skills/how-it-works/scripts/` |
| adicionar ou ajustar teste | `skills/how-it-works/evals/` |
| entender uma decisão de desenho | `docs/decisions/` |

Duas regras que valem sempre neste repositório:

**Coletar antes, raciocinar depois.** Os scripts levantam os fatos; o modelo só
julga e redige. Não inverta.

**Rode em bash 3.2.** O macOS entrega essa versão. `declare -A`, `xargs -r` e
afins quebram. `bash -n` em todos os scripts é o mínimo antes de commitar.
