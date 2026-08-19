# 01 — Problema e objetivos

## O problema

Ao implementar uma mudança, os agentes de código geram explicações que:

- não entram nos detalhes de código que importam;
- param no "o quê" e não explicam o "porquê";
- dão salada de buzzwords sem insight prático;
- ou detalham tudo uniformemente, afogando o que é crítico.

O resultado: o desenvolvedor não consegue discutir a solução com confiança antes
de ela ser implementada.

## Objetivos

- **Objetiva e concisa**: visão geral curta, sem encher linguiça.
- **Detalhe condicional**: mergulha no código só onde é crítico
  (mudanças/implementações que exigem atenção), classificando cada elemento como
  trivial / significativo / crítico.
- **Multi-formato**: markdown, diagramas (Mermaid), trechos de código —
  escolhidos pelo tipo de informação, não fixos.
- **Rápida**: processamento rápido mesmo em bases grandes.
- **Barata**: mínimo de tokens de LLM (só a síntese final).
- **Escopada**: explica a funcionalidade em questão, não a aplicação inteira.
- **Poliglota**: .NET, Java, Kotlin, Go, Python, Angular, React.
- **Honesta**: nunca finge completude; marca o que a análise estática não pega.

## Critério de sucesso

O desenvolvedor lê a explicação, entende a implementação atual da fatia, e
consegue comentar/ajustar a direção **antes** de qualquer proposta — e o agente
reusa esse mesmo entendimento na fase 2.
