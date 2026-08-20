# 08 — Compatibilidade entre agentes

Alvo primário: **Claude Code**. Depois: **Cursor** e **Devin CLI**.

## Claude Code (implementado)

Skills são descobertas em `~/.claude/skills/<nome>/SKILL.md` (pessoais) ou
`.claude/skills/` (por projeto). Como este repositório vive em uma pasta própria
dentro de `~/.claude/`, o `install.sh` cria um symlink da skill para o caminho de
descoberta:

```
~/.claude/skills/how-it-works
  -> ~/.claude/claude-feature-explainer/skills/how-it-works
```

Os scripts em `scripts/` são bash puro e independem do agente.

## Cursor (planejado)

Cursor usa comandos/regras próprios. O plano é gerar um wrapper que aponte para
os mesmos scripts e o mesmo `synthesis-prompt.md`, mudando só o formato do
arquivo de invocação. A lógica determinística é reaproveitada 1:1.

## Devin CLI (planejado)

Mesma estratégia: a inteligência está nos scripts + no prompt de síntese, que são
agnósticos. Só a "casca" de invocação muda por ferramenta.

## Via OpenSpec

O OpenSpec já abstrai a invocação entre agentes (mesmo intent `/opsx:*`,
grafias diferentes por ferramenta). Expor esta skill como um passo pré-`propose`
no schema do OpenSpec dá compatibilidade cross-tool "de graça".

## Princípio de portabilidade

A inteligência vive nos **scripts determinísticos** + no **prompt de síntese**
(agnósticos). Só a casca de invocação muda por ferramenta. Nunca acople lógica
de investigação ao formato de um agente específico.
