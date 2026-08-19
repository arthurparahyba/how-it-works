# Checagens de validação — o que é determinístico e o que não é

A fase 2 gera opções com julgamento (LLM), mas cerca a proposta com validação
determinística. Entenda o que cada checagem pega — e o que ela não pega.

## validate_proposal.sh

Confere as **afirmações da proposta sobre o código**:

| Resultado | Significado | Ação |
|---|---|---|
| `verified` | símbolo/arquivo existente foi encontrado | ok |
| `missing` | a proposta cita algo existente que **não existe** | corrigir: alucinação ou suposição errada |
| `new_ok` | algo novo que ainda não existe | ok para criar |
| `collision` | a proposta cria algo que **já existe** | corrigir: renomear ou reusar o existente |

`verdict: needs_fix` bloqueia o avanço para o plano final. Isto elimina o erro
clássico de propor chamadas a APIs inexistentes.

Limite honesto: a checagem de definição é boa, mas não perfeita para símbolos
resolvidos dinamicamente (reflexão, DI). Um `missing` pode, raramente, ser um
símbolo real injetado em runtime — nesse caso, marque como confirmado à mão e
registre a exceção.

## proposal_impact.sh

Mostra o **raio de impacto real** dos pontos tocados: dependentes (o que pode
quebrar) e testes que cobrem os arquivos. Serve para o dev não ser surpreendido.

Mesma limitação da fase 1: dispatch dinâmico, reflexão, DI e fronteiras entre
serviços não aparecem. O plano deve sinalizar essas lacunas explicitamente.

## openspec validate

Se o CLI do OpenSpec existir, `emit_openspec_change.sh` roda
`openspec validate <id> --strict`, conferindo o pacote contra o schema do
projeto (estrutura de proposal/design/tasks/specs). É a checagem de forma; as
duas acima são a checagem de conteúdo.

## Ordem recomendada

1. `validate_proposal.sh` → corrigir alucinações/colisões.
2. `proposal_impact.sh` → trazer impacto e testes para o plano.
3. Elaborar plano e tarefas.
4. `emit_openspec_change.sh` → materializar + `openspec validate`.
