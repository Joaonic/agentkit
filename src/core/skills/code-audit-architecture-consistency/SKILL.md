---
name: code-audit-architecture-consistency
description: Auditar arquitetura, fronteiras hexagonais (Java/Spring), contratos e clients tipados (web), duplicação, oportunidades de design patterns e aderência às rules YourProject (tenant, segurança, MapStruct, Flyway, TDD, observabilidade).
---

# Auditoria de Código — Arquitetura e Consistência

## Visão Geral

Esta skill guia o agente a fazer auditorias de código neste repositório, verificando se a implementação está em bom shape, alinhada com:

- Regras em `.cursor/rules/` (hexagonal Java, Spring layering, Flyway/Testcontainers, tenant isolation, TDD, UX quando aplicável).
- `AGENTS.md`, `docs/governance/cursor/workflow.md` e `workflow/*.md`.
- Convenções do monorepo: submódulos com `AGENTS.md` local devem ser lidos quando o escopo os tocar (`40-submodule-governance.mdc`).

O foco é **consistência arquitetural**, **pouca duplicação relevante (DRY)** e **aderência a padrões já definidos**, não inventar regras novas.

## Quando Usar

Use esta skill quando:

- O usuário pedir **auditoria de código**, **code review estrutural** ou avaliação de **shape/qualidade geral**.
- For revisar um PR, branch ou feature grande e quiser checar **aderência às regras do projeto**.
- Suspeitar de **duplicação**, **violação de ports/adapters**, ou **clients HTTP inconsistentes** (ex.: fetch manual vs cliente gerado quando o projeto padroniza OpenAPI).
- Quiser avaliar se uma nova parte do código segue **TDD obrigatório** e **fronteiras hexagonais** (backend + web conforme rules).

Não use esta skill para:

- Debug pontual de um bug específico (prefira a skill de debugging/sistematic-debugging).
- Perguntas puramente conceituais sem código concreto.

## Preparação da Auditoria

Antes de iniciar a auditoria:

1. **Defina o escopo** com clareza:
   - Arquivos ou diretórios específicos.
   - Um PR ou conjunto de commits.
   - Uma feature (ex.: "convites multi-tenant" ou "exportação de relatório").

2. **Carregar rules relevantes** (consultar ficheiros em `.cursor/rules/` — exemplos frequentes neste monorepo):
   - `00-governance.mdc`, `05-docs-canonical-source.mdc`
   - `10-java-hexagonal.mdc`, `12-springboot-layering.mdc`
   - `13-dto-domain-design.mdc`, `14-mapstruct-mapping-quality.mdc`
   - `15-database-flyway-testcontainers.mdc`, `16-postgresql-sql-guidelines.mdc`
   - `18-tenant-isolation.mdc`, `22-data-security.mdc`, `23-observability.mdc`
   - `04-tdd-mandatory.mdc`, `08-ux-mandatory.mdc`
   - `20-web-nextjs.mdc`, `21-web-react.mdc`
   - `29-mcp-and-devex.mdc` quando integrações/MCP estiverem em scope

3. **Identifique o tipo de código** auditado:
   - Backend Java (`apps/<serviço>/`, `libraries/**`) — Spring Boot, hexagonal, ports/adapters, MapStruct, Flyway.
   - Frontend (`web/<app>/`, outros frontends) — React/Next.js, Yarn; seguir estrutura **do subprojeto** (ler `README` local).
   - Infra (`infra/**`, `deploy/**`) quando o escopo incluir manifests/pipelines.

## Dimensões de Revisão

**Nota:** Após dimensões técnicas, aplicar **`ux-review`** quando houver alterações user-facing (`08-ux-mandatory.mdc`). Ver dimensão 8.

### 1. Arquitetura hexagonal (backend) e modularidade (web)

Verifique:

- **Backend (Java/Spring)**:
  - Domínio e casos de uso sem dependências de framework/infrastructure (ver `10-java-hexagonal.mdc`).
  - Ports em `core/port/out` (ou equivalente do serviço); adapters em `infrastructure`; superfície REST em `api` ou integrações externas em `adapters/in` conforme baseline do repo.
  - Use cases obtêm dependências via interfaces, não implementações concretas.

- **Frontend (`web/**`)**:
  - Respeitar convenções do subprojeto (pastas, camadas, design system).
  - Componentes/páginas finos; lógica de negócio não deve migrar para UI quando já existe contrato no backend.

Marque problema quando:

- Casos de uso ou domínio importam JPA entities, clients HTTP “crus”, ou SDKs externos sem adapter.
- Mistura de responsabilidades entre `api`, `adapters/in` e `infrastructure`.

### 2. Contratos HTTP, OpenAPI e MapStruct

- **Frontend**: se o projeto usa cliente gerado a partir de OpenAPI (ou wrapper interno), evitar `fetch` paralelo ao mesmo recurso sem justificativa; excepções: APIs de terceiros fora do contrato interno.
- **Backend**: integrações externas devem estar atrás de adapters; evitar HTTP espalhado em controllers/use cases.
- **MapStruct**: verificar mappers completos e explícitos (`14-mapstruct-mapping-quality.mdc`); DTO vs domínio conforme `13-dto-domain-design.mdc`.

### 3. Tipos de domínio e enums (Java)

Com base em `13-dto-domain-design.mdc`, `11-java-clean-code.mdc` e convenções do pacote de domínio:

- Value objects/enums Java para estados e tipos estáveis do domínio.
- Evitar strings mágicas em condicionais quando já existe tipo enumerado ou VO no core.

Marque como problema quando:

- `if ("ACTIVE".equals(status))` espalhado em várias camadas em vez de enum `Status.ACTIVE` ou método no VO.
- DTOs de API revelam strings brutas que deveriam estar encapsuladas no domínio.

### 4. DRY e Duplicação de Código

Foque em **duplicações significativas**, não micro‑repetições:

- Várias funções/classes com lógica quase idêntica para:
  - Parse/validação de payloads.
  - Mapeamento entre modelos similares (DTOs, view models).
  - Orquestração de workflows iguais em serviços diferentes.

- Padrões que já existem em outro lugar (helpers, utilities, mappers) sendo reimplementados de forma parecida.

Ao apontar duplicação:

- Prefira mostrar **onde** já existe uma solução padrão que poderia ser reutilizada ou generalizada.
- Respeite a regra de **escopo estrito**: não proponha refactors gigantes sem o usuário pedir; sugira caminhos de consolidação como sugestão separada.

### 5. TDD, Testes e Cobertura

Com base em `04-tdd-mandatory.mdc`, `docs/governance/cursor/workflow.md` e `workflow/02-implementation.md`:

- Verifique se novas funcionalidades/correções têm:
  - **Testes adicionados ou atualizados** (unitários/integration, conforme camada).
  - Testes que realmente capturam o comportamento de negócio e edge cases relevantes.

- Sinais de violação de TDD:
  - Implementação grande sem testes correspondentes.
  - Testes superficiais que não cobririam bugs óbvios no código atual.

Classifique:

- **Crítico**: mudança sem testes onde o domínio é sensível (auth, billing, tenant, dados pessoais).
- **Importante**: falta de testes em código novo não crítico, mas com lógica relevante.
- **Menor**: pequenos gaps que podem ser endereçados depois.

### 6. Oportunidades de Design Patterns

Avalie se o código atual poderia ser melhorado aplicando algum design pattern. Use as skills em `.cursor/skills/design-pattern-*/` como referência.

Verifique especialmente:

- **Conditionals para comportamento** — múltiplos `if/switch` escolhendo algoritmo/comportamento → **Strategy** ou **Factory Method**.
- **Integrações ou APIs incompatíveis** — chamadas diretas a serviços externos com interface diferente → **Adapter**.
- **Orquestração de workflow/pipeline** — encadeamento de passos ou handlers → **Chain of Responsibility**, **Template Method**.
- **Estados e transições** — máquinas de estados complexas → **State** (domínio) ou abstração equivalente no frontend quando aplicável.
- **Objetos complexos com muitos parâmetros** — construtores longos ou telescoping → **Builder**.
- **Comportamento adicional sem modificar classe** — extensão de responsabilidades → **Decorator**.
- **Subsistemas complexos** — muitos imports/dependências em uma camada → **Facade**.
- **Famílias de objetos relacionados** — criação de variações de produtos → **Abstract Factory**, **Factory Method**.
- **Encapsulamento de ações** — requisições enfileiráveis, undo/redo, jobs → **Command**.
- **Acoplamento entre muitos componentes** — comunicação direta entre várias partes → **Mediator**.

Ao sugerir um padrão:

- Indique **qual padrão** e **onde** no código (arquivo, classe, trecho).
- Descreva **brevemente** como o padrão se aplica (sem implementar).
- Classifique como **🟢 Sugestão** ou **🟡 Importante** se a falta do padrão causar violação de OCP, SRP ou dificultar testes/manutenção.

Não force padrões desnecessários: só sugira quando houver ganho real (legibilidade, testabilidade, extensibilidade). Respeite o escopo estrito.

### 7. Multi‑Tenant, Segurança de Dados e Observabilidade

Use esta dimensão quando o código:

- Toca rotas/handlers que recebem dados de tenants/usuários.
- Acessa banco ou serviços externos com identificação de tenant.
- Lida com logs, métricas, tracing ou LLMs.

Verifique:

- **Tenant isolation**:
  - Todas as queries e operações escopadas por `tenant_id`.
  - Nenhum acesso global onde deveria haver filtro por tenant.

- **Data security**:
  - Tokens, secrets, IDs internos e PII não aparecem em logs.
  - Dados enviados a LLMs passam por view models seguros, sem IDs brutos.

- **Observability**:
  - Uso de `correlation_id`, traces e logs estruturados quando aplicável.

### 8. Experiência do Usuário (UX)

**Obrigatório após code review técnico.** Use a skill `ux-review` ou agent `ux-reviewer` para validar UX.

Quando o código toca interfaces, componentes, páginas ou fluxos em **`web/**`** (ou outro frontend):

Verifique:

- **Simplicidade extrema**:
  - Linguagem clara, sem jargões técnicos ou siglas sem explicação.
  - Botões e ações com labels claros ("Salvar" não "Submit").
  - Zero conhecimento técnico necessário para usar.

- **Feedback e estados**:
  - Estados de loading visíveis.
  - Mensagens de erro úteis (explicam problema e solução, sem stack traces).
  - Confirmações adequadas para ações destrutivas.

- **Prevenção de erros**:
  - Validação em tempo real em formulários.
  - Campos obrigatórios claramente indicados.
  - Guias contextuais (tooltips, hints) quando necessário.

- **Acessibilidade**:
  - Navegação por teclado funcional.
  - Contraste adequado (WCAG AA mínimo).
  - Labels e ARIA para leitores de tela.
  - Tamanhos de toque adequados em mobile (≥44x44px).

- **Fluxos intuitivos**:
  - Menos passos possível.
  - Progresso visível em processos multi-passo.
  - Navegação clara (voltar, cancelar, avançar).

- **Nunca expor ao usuário**:
  - Códigos técnicos, IDs internos, stack traces.
  - Mensagens de erro com detalhes técnicos.
  - Termos como "tenant_id", "correlation_id", etc.

**Após code review técnico, sempre aplicar revisão de UX quando aplicável.** Ver `08-ux-mandatory.mdc`.

## Workflow de Auditoria

Siga estes passos ao aplicar a skill:

1. **Definir Escopo**
   - Liste explicitamente quais arquivos, diretórios ou PR/commits serão auditados.

2. **Classificar Contexto**
   - Backend (`apps/**`, serviços Java) vs frontend (`web/**`) vs bibliotecas (`libraries/**`).
   - Identifique se envolve integrações externas (OAuth/Keycloak, gateways, mensageria, LLMs, parceiros) ou apenas lógica interna.

3. **Leitura de Alto Nível**
   - Passe rapidamente pelos arquivos para entender:
     - Responsabilidades principais.
     - Principais dependências/imports.
     - Fluxo de dados entre camadas.

4. **Aplicar Dimensões de Revisão**
   - Para cada dimensão acima (Arquitetura, Contratos HTTP/MapStruct, Tipos de domínio/enums, DRY, TDD, Design Patterns, Segurança/Obs, UX):
     - Procure violações ou riscos.
     - Colete 1–3 exemplos mais representativos (não liste tudo exaustivamente, foque em padrões).
   - **Obrigatório quando aplicável (`08-ux-mandatory.mdc`):** se o MR toca `web/**` ou UI de outro frontend no escopo, aplicar revisão de UX (dimensão 8), por exemplo via skill `ux-review`.

5. **Agrupar por Severidade**

Classifique achados em:

- **🔴 Crítico** — quebra de regra central (hexagonal, enums, TDD, multi‑tenant, segurança, UX).
- **🟡 Importante** — dívida técnica relevante ou inconsistência que aumenta risco/manutenção, ou problemas de UX que dificultam uso.
- **🟢 Sugestão** — melhoria de legibilidade/DRY/organização sem impacto imediato grave, ou melhorias de UX que tornariam mais intuitivo.

6. **Respeitar Escopo Estrito**

- Ao propor mudanças, limite‑se ao que é necessário para:
  - Corrigir violações graves das regras do projeto.
  - Manter o código compilando, rodando e passando em testes.
- Refactors amplos, reorganização de pastas, ou mudanças de design devem ir para a seção de **Sugestões**, não serem aplicados automaticamente.

## Formato de Saída Recomendado

Ao responder ao usuário, use este template adaptado:

```markdown
### Visão geral

- **Escopo auditado**: [arquivos/feature/PR]
- **Resumo**: [2–4 frases sobre shape geral, pontos fortes e riscos]

### Achados 🔴 Críticos

- **[Título curto]**
  - **Contexto**: [onde ocorre, arquivos/camadas envolvidas]
  - **Regra violada**: [ex.: `10-java-hexagonal.mdc`, `13-dto-domain-design.mdc`, `04-tdd-mandatory.mdc`]
  - **Detalhe**: [descrição objetiva do problema]
  - **Sugestão de correção mínima**: [ação focada, sem refactor amplo]

### Achados 🟡 Importantes

- **[Título curto]**
  - **Contexto**: [...]
  - **Risco**: [manutenibilidade, consistência, etc.]
  - **Sugestão**: [melhoria razoável dentro do escopo]

### Achados 🟢 Sugestões

- **[Título curto]**
  - **Contexto**: [...]
  - **Benefício**: [legibilidade, DRY, padrão arquitetural, design pattern aplicável]
  - **Patch sugerido**: [opcional; apenas como sugestão, não aplicado]

- **Design patterns sugeridos** (quando aplicável):
  - Indicar padrão (ex.: Strategy, Adapter), local no código e ganho esperado; referenciar skill `design-pattern-*` correspondente.
```

## Relatório persistente (opcional)

Use quando o usuário pedir **arquivo** além do relatório na conversa.

- **Path sugerido:** `docs/implementation/not_implemented/<domínio>/YYYY-MM-DD-code-audit-<slug>.md` — substitua `<domínio>` por uma pasta coerente (ex.: `general`, `integrations`); ou use path/nome acordado com o usuário.
- **Conteúdo mínimo:** visão geral; achados 🔴/🟡/🟢 por área (backend, frontend, libraries, integrações quando aplicável); recomendações priorizadas — alinhado ao template acima.
- **Execução:** no output, pode-se primeiro propor o esqueleto; delegar criação/edição ao agent `docs` quando fizer sentido.

## Erros Comuns a Evitar ao Usar Esta Skill

- **Inventar regras novas** não presentes nas `.cursor/rules/` ou docs oficiais do projeto.
- **Forçar grandes refactors** sem o usuário pedir, quebrando a regra de escopo estrito.
- **Confundir duplicação aceitável** (pequenos snippets) com duplicação estrutural realmente problemática.
- **Criticar uso manual de HTTP no frontend** quando se trata de integração externa que não passa pela API própria.
- **Ignorar TDD** ao sugerir mudanças: quaisquer correções estruturais devem vir acompanhadas de plano de testes.

Use esta skill como checklist mental para manter as revisões consistentes com o estilo e as regras já existentes no repositório.
