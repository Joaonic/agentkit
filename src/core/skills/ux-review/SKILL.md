---
name: ux-review
description: Review user experience and usability after code review. Ensures features are intuitive for the least technical users. Use proactively after code review, during planning, and before finalizing implementations.
---

# UX Review — Experiência do Usuário

## Visão Geral

Esta skill guia o agente a revisar a experiência do usuário após code review, garantindo que funcionalidades sejam **intuitivas para o usuário mais leigo possível**, sem conhecimento técnico.

**Princípio fundamental:** Assuma que o usuário final é o mais inexperiente possível. Tudo deve ser **óbvio, simples e autoexplicativo**.

## Quando Usar

Use esta skill quando:

- **Após code review** — verificar se a funcionalidade tem a melhor UX possível.
- **Durante planejamento** — considerar UX desde o início do design.
- **Antes de finalizar implementação** — validar que a experiência está otimizada.
- **Ao criar planos** — incluir tasks de UX no planejamento.
- **Ao revisar interfaces** — componentes, páginas, fluxos de usuário.

## Princípios de UX

### 1. Simplicidade Extrema

- **Zero conhecimento técnico necessário** — usuário não precisa entender conceitos técnicos.
- **Linguagem clara** — evite jargões, termos técnicos, siglas sem explicação.
- **Ações óbvias** — botões e links devem deixar claro o que acontecerá ao clicar.

### 2. Feedback Imediato

- **Confirmações visuais** — mostrar que ações foram recebidas (loading, sucesso, erro).
- **Mensagens de erro claras** — explicar o problema e como resolver, sem códigos técnicos.
- **Estados visíveis** — usuário sempre sabe onde está e o que pode fazer.

### 3. Prevenção de Erros

- **Validação em tempo real** — mostrar problemas antes de submeter.
- **Confirmações para ações destrutivas** — evitar ações irreversíveis por acidente.
- **Guia contextual** — tooltips, hints, exemplos quando necessário.

### 4. Acessibilidade e Inclusão

- **Navegação por teclado** — todas as ações devem ser acessíveis sem mouse.
- **Contraste adequado** — texto legível em qualquer condição.
- **Tamanhos de toque** — botões grandes o suficiente para mobile.
- **Leitores de tela** — labels e ARIA adequados.

### 5. Fluxos Intuitivos

- **Menos cliques possível** — reduzir passos desnecessários.
- **Progresso visível** — mostrar etapas em processos multi-passo.
- **Navegação clara** — usuário sempre sabe como voltar ou avançar.
- **Padrões familiares** — seguir convenções conhecidas (ex.: botão de salvar à direita).

## Checklist de Revisão UX

### Interface e Visual

- [ ] **Linguagem clara** — textos sem jargões técnicos, explicativos.
- [ ] **Hierarquia visual** — elementos importantes destacados.
- [ ] **Espaçamento adequado** — não sobrecarregado, respiração visual.
- [ ] **Cores consistentes** — semântica de cores respeitada (verde=sucesso, vermelho=erro).
- [ ] **Responsividade** — funciona bem em mobile, tablet e desktop.

### Interação

- [ ] **Botões com labels claros** — "Salvar" não "Submit", "Cancelar" não "Abort".
- [ ] **Estados de loading** — usuário sabe que algo está processando.
- [ ] **Mensagens de erro úteis** — explicam problema e solução, sem stack traces.
- [ ] **Confirmações adequadas** — para ações destrutivas ou irreversíveis.
- [ ] **Validação em tempo real** — feedback imediato em formulários.

### Fluxo e Navegação

- [ ] **Caminho claro** — usuário sabe o que fazer em cada etapa.
- [ ] **Progresso visível** — em processos multi-passo, mostrar onde está.
- [ ] **Navegação intuitiva** — fácil voltar, cancelar ou avançar.
- [ ] **Menos passos possível** — reduzir fricção desnecessária.
- [ ] **Onboarding** — primeira vez deve ser guiada ou autoexplicativa.

### Acessibilidade

- [ ] **Navegação por teclado** — Tab, Enter, Esc funcionam corretamente.
- [ ] **Contraste adequado** — texto legível (WCAG AA mínimo).
- [ ] **Tamanhos de toque** — botões ≥44x44px em mobile.
- [ ] **Labels e ARIA** — leitores de tela conseguem navegar.
- [ ] **Foco visível** — indicador claro de elemento focado.

### Mensagens e Feedback

- [ ] **Mensagens de sucesso** — confirmam ação concluída claramente.
- [ ] **Mensagens de erro** — explicam problema e como resolver.
- [ ] **Tooltips e hints** — ajudam quando conceito pode não ser óbvio.
- [ ] **Exemplos** — quando útil, mostrar exemplos de entrada válida.
- [ ] **Sem códigos técnicos** — nunca mostrar IDs internos, stack traces ao usuário.

## Workflow de Revisão UX

### 1. Contexto

- Entender a funcionalidade sendo revisada.
- Identificar o usuário-alvo (merchant, cliente final, admin).
- Revisar fluxo completo, não apenas componentes isolados.

### 2. Análise por Princípios

Para cada princípio (Simplicidade, Feedback, Prevenção, Acessibilidade, Fluxos):

- Verificar se está sendo respeitado.
- Identificar gaps ou melhorias.
- Priorizar por impacto no usuário.

### 3. Teste Mental de Usuário Leigo

Perguntar:

- **"Um usuário sem conhecimento técnico conseguiria usar isso?"**
- **"O que acontece se o usuário errar?"**
- **"O usuário sabe o que fazer a seguir?"**
- **"Há alguma informação técnica exposta ao usuário?"**

### 4. Identificar Problemas

**POLÍTICA DE ZERO TOLERÂNCIA:** Todo problema de UX encontrado em ficheiros dentro do escopo da issue ou tocados pelo PR é **BLOQUEANTE**. Não existe "sugestão não-bloqueante" — se está em scope, deve ser resolvido antes de aprovar.

Classificar problemas encontrados por severidade (todos são bloqueantes):

- **🔴 Crítico** — impede uso ou causa confusão grave. Resolver imediatamente.
- **🟡 Importante** — dificulta uso ou reduz satisfação. Resolver antes de aprovar.
- **🟠 Melhoria** — tornaria mais intuitivo. Resolver antes de aprovar se em scope.

### 5. Propor Soluções

Para cada problema:

- Explicar o problema do ponto de vista do usuário.
- Sugerir solução específica e implementável.
- Priorizar por impacto e esforço.

## Formato de Saída

Ao revisar UX, use este template:

```markdown
### Revisão UX — [Nome da Funcionalidade]

**Contexto:** [breve descrição do que foi revisado]

#### 🔴 Problemas Críticos

- **[Título do problema]**
  - **Impacto:** [como afeta o usuário leigo]
  - **Onde:** [componente/página/fluxo]
  - **Solução sugerida:** [mudança específica]

#### 🟡 Melhorias Importantes

- **[Título]**
  - **Impacto:** [...]
  - **Solução sugerida:** [...]

#### 🟠 Melhorias adicionais (bloqueantes se em scope)

- **[Título]**
  - **Benefício:** [...]
  - **Solução sugerida:** [...]

#### Checklist de Princípios

- ✅ Simplicidade — [status]
- ✅ Feedback — [status]
- ✅ Prevenção de Erros — [status]
- ✅ Acessibilidade — [status]
- ✅ Fluxos Intuitivos — [status]
```

## Integração com Code Review

Esta skill deve ser aplicada **após** code review técnico:

1. **Code review técnico** — arquitetura, testes, segurança, performance.
2. **UX review** — experiência do usuário, usabilidade, acessibilidade.

Ambos são obrigatórios antes de considerar uma funcionalidade completa.

**Todo problema de UX identificado é BLOQUEANTE** — não aprovar com ressalvas ou sugestões pendentes.

## Pesquisa com MCP e docs do projeto (obrigatório)

Antes de validar padrões de UI/UX:

- **Context7:** usar o servidor MCP configurado no projeto (`resolve-library-id` / docs de biblioteca) para React, Next.js, Radix, shadcn, MUI, etc., quando aplicável ao código revisto.
- **Docs locais:** ler README e guidelines do frontend **dentro do submódulo** (`web/<app>/`) quando existirem — cada app pode ter stack própria.
- Integrações específicas (Shopify, Stripe, …): só exigir validação MCP extra se essa integração estiver **em scope** e o MCP estiver listado em `.cursor/mcp.json`.

Se o código usar APIs ou patterns obsoletos face à documentação consultada, tratar como **BLOQUEANTE**.

## Exemplos de Problemas Comuns

### ❌ Ruim

- Botão "Submit" sem contexto.
- Erro: "Error 500: Database connection failed".
- Campo obrigatório sem indicação visual.
- Processo de 10 passos sem progresso visível.
- Mensagem: "Invalid tenant_id format".

### ✅ Bom

- Botão "Salvar configurações" com ícone de salvar.
- Erro: "Não foi possível conectar. Verifique sua internet e tente novamente."
- Campo obrigatório com asterisco e label "Obrigatório".
- Processo de 3 passos com indicador "Passo 1 de 3".
- Mensagem: "Por favor, verifique os dados informados e tente novamente."

## Lembretes

- **Sempre pensar no usuário mais leigo** — assumir zero conhecimento técnico.
- **Linguagem clara** — evitar jargões, siglas, termos técnicos.
- **Feedback constante** — usuário sempre sabe o que está acontecendo.
- **Prevenir erros** — melhor que corrigir depois.
- **Acessibilidade não é opcional** — todos devem conseguir usar.

Esta skill deve ser aplicada **proativamente** em todo planejamento e implementação, não apenas como checklist final.
