---
name: tdd-workflow
description: OBRIGATÓRIO para comportamento novo ou correções relevantes. Test-first na stack tocada (JUnit/Testcontainers no Java; testes do frontend no subprojeto), alinhado a workflow e rules YourProject.
---

# TDD Workflow (Test-Driven Development)

## Quando usar (sempre)

- **Mudança de comportamento** (feature nova, correção de bug com regressão) — ver `04-tdd-mandatory.mdc` e `docs/governance/cursor/workflow/00-overview.md` (test-first).
- Quando existe um **alvo verificável** (testes) para iterar até passar.

## Antes do primeiro teste

1. Cumprir **investigação mínima** — rule `01-investigation-before-implementation.mdc`; objetivos/non-objectivos; módulos e contratos impactados; evitar duplicar use cases/adapters/UI já existentes.
2. Se o escopo tocar **`apps/*`, `web/*`, `libraries/*`, `infra/*`**: ler **`AGENTS.md`** e README do subprojeto (quando existirem) — comandos e camadas corretas (`40-submodule-governance.mdc`).
3. Ordem de fases em execução guiada: **`docs/governance/cursor/workflow/02-implementation.md`** (investigation → TDD prep → implementation loop → …).

## Fluxo TDD (disciplina)

1. **Escrever ou estender testes primeiro** — cenários e asserts claros; nomes que documentem comportamento.
2. **Executar a suíte relevante e confirmar falha** — não adicionar implementação “para fazer passar” antes de ver o vermelho (exceto infra mínima impossível de testar sem stubs já aceites no projeto).
3. **Implementar o mínimo** para verde — sem alterar o contrato dos testes salvo erro de especificação já acordado com o utilizador.
4. **Refatorar** com testes verdes (opcional mas recomendado).
5. **Repetir** até cobrir acceptance criteria.

## Regras

- **Não usar mocks** que substituam comportamento que ainda não existe de forma a falsificar verde — o primeiro objetivo é falha legítima.
- **Não mudar testes durante implementação** só para “facilitar” — se o teste estiver errado, corrigir com **explícito acordo** sobre especificação.
- **Rodar testes** após cada iteração significativa.
- **Backend**: integração com persistência realista → preferir **Testcontainers + PostgreSQL** onde o projeto já o faz (`15-database-flyway-testcontainers.mdc`); não usar H2 para substituir semântica PostgreSQL em integração.
## Proibições absolutas — zero bypass, zero débito

O agente **NUNCA** pode:

- **Enfraquecer testes para fazer passar.** Proibido: remover assertions, alargar matchers (`any()` onde antes era específico), substituir integração real por mock só para evitar falha, trocar PostgreSQL/Testcontainers por H2 ou in-memory, aumentar timeouts como "solução".
- **Usar `@Disabled` / `@Ignore` / `.skip()` / `xit()`** sem justificativa documentada e issue aberta de tracking referenciada no código. Teste desactivado sem issue = **BLOQUEIO**.
- **Usar APIs deprecated.** Sempre usar a alternativa actual (validar via MCP Context7 ou docs oficiais). Se não existir substituto, reportar ao utilizador — não usar o deprecated "por enquanto".
- **Introduzir warnings.** Qualquer warning novo (compiler, lint, deprecation) introduzido pelo código ou testes é **BLOQUEANTE**. Se o ficheiro tocado já tinha warnings, corrigi-los (boy-scout rule).
- **Fazer bypass de validação, build ou lint.** Proibido: `-DskipTests` em builds finais, `--no-verify` em commits/push, `@SuppressWarnings` sem justificativa, `eslint-disable` sem motivo real, `// @ts-ignore` sem issue.
- **Criar stubs/TODOs** sem issue aberta e referenciada (`// TODO(#N): ...`), no mesmo milestone, em path não atingível em produção. Sem os 3 critérios: **BLOQUEIO**.
- **Usar gambiarras ou workarounds temporários** sem issue de tracking. Proibido: hardcoded values que deviam ser config, `Thread.sleep()` / `setTimeout()` como solução de timing, catch genérico que engole excepções, casts inseguros, reflexão para contornar encapsulamento.
- **Copiar testes de outro contexto** sem adaptar. Testes devem validar o comportamento real do código — não colar assertions de outro módulo que "parecem funcionar".
## Stacks (comandos típicos)

- **Java (`apps/*`, `libraries/*`)**: na raiz do `pom.xml` do módulo — `./mvnw test` ou `./mvnw verify` conforme README local.
- **Frontend (`web/*`)**: `yarn test`, `yarn lint`, scripts definidos no `package.json` do app.

## Smoke test obrigatório (rule `31-application-context-smoke-test.mdc`)

Ao trabalhar em **qualquer `apps/*`** Java:

1. **Antes de começar**, verificar que `ApplicationContextSmokeTest.java` existe com `@SpringBootTest` + Testcontainers. Se não existir ou for falso (plain JUnit sem contexto Spring) → **criar** antes de implementar.
2. **Após implementação**, rodar `./mvnw test -Dtest="ApplicationContextSmokeTest"` e confirmar que o contexto completo inicia.
3. Se falhar → **corrigir a aplicação**, NÃO o teste. O contexto deve iniciar com todos os beans reais.

## Testes integrados e E2E — contexto completo obrigatório

Testes que se propõem a validar integração ou E2E **devem** usar `@SpringBootTest` sem `classes=` para iniciar o contexto **COMPLETO** com Testcontainers.

**PROIBIDO** em testes integrados/E2E:
- `@SpringBootTest(classes = {...})` — contexto parcial não é integração
- `@ContextConfiguration(classes = ...)` para limitar contexto
- `@Import({...})` em `@SpringBootTest` para compor contexto manualmente
- `@TestConfiguration` que substitui beans de produção por no-op para "fazer o contexto subir"
- Qualquer trick para evitar que o contexto completo carregue

**PERMITIDO** em slice tests (e SÓ em slice tests):
- `@WebMvcTest(controllers = ...)` + `@Import(...)` — correcto para testar controller isolado
- `@DataJpaTest` — correcto para testar repositório isolado

Use também a skill **`run-tests`** para relatório de evidências.

## Exemplo de prompt (Java)

```
Escreva um teste JUnit 5 para UserInvitationPort que reproduz convite duplicado no mesmo tenant.
Use o mesmo estilo de @Nested/fixtures que em <classe de referência>.
Não implemente o fix no use case ainda — quero ver o teste falhar primeiro.
```

Depois:

```
Implemente o mínimo no use case para o teste passar. Não enfraqueça o teste.
```

## Referências

- Rules: `04-tdd-mandatory.mdc`, `01-investigation-before-implementation.mdc`, `10-java-hexagonal.mdc`, `15-database-flyway-testcontainers.mdc`
- Workflow: `docs/governance/cursor/workflow.md`, `workflow/00-overview.md`, `workflow/02-implementation.md`
- Skills: `run-tests`, `implement-plan`; superpower **`superpowers:test-driven-development`** quando aplicável ao fluxo da sessão
