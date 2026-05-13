---
name: mongo-workbench
description: >-
  Models MongoDB collections, embed vs reference tradeoffs, indexes, queries,
  aggregation pipelines, transactions, and safe operations. Use when designing
  or reviewing document schemas, compound indexes, aggregations, sharding
  strategy, schema validation, bulk writes, or driver-specific patterns.
---

# MongoDB Workbench

## Descoberta obrigatória (até 5 perguntas)

Antes de propor modelo, índices ou pipelines definitivos, esclareça o que faltar sobre **workload** e **ambiente**. Se o usuário já tiver dado contexto suficiente, confirme em uma linha e siga.

1. **Workload principal** — OLTP operacional, catálogo/leitura dominante, eventos/logs, analytics sobre o mesmo cluster, ou mistura (e qual domina).
2. **Padrão de leitura e escrita** — queries mais frequentes (filtros, ordenação, projeção), taxa relativa de insert/update/delete, upserts, writes em lote, necessidade de leituras fortemente consistentes vs eventualmente consistentes.
3. **Consistência transacional** — operações que exigem ACID multi-documento (ou multi-coleção) na mesma replica set; ou se consistência pode ser alcançada com modelo de documento único e idempotência.
4. **Volume, crescimento e hotspots** — ordem de grandeza de documentos e coleções, crescimento esperado, chaves de partição candidatas, risco de hot shard ou hot document (ex.: contador em um único doc).
5. **Linguagem e driver** — runtime da aplicação (ex.: Node, JVM, .NET, Go, Python) e **driver MongoDB** usado; não fixar versão do servidor ou do driver nas respostas — orientar a consultar a documentação oficial da **versão em uso no ambiente** (veja abaixo).

## Documentação e versão

- **Não fixe versão** de servidor MongoDB, driver ou shell em rules genéricas: peça ou infira a versão do ambiente e use a documentação oficial correspondente (MongoDB Manual para a release relevante).
- Para APIs que mudam entre releases (transações, aggregation stages, operadores), **confirme na documentação da versão alvo** antes de recomendar sintaxe exata.
- Priorize **mongodb.com/docs** (e notas de release) sobre blogs desatualizados.

## Obrigações do agente (checklist de comportamento)

1. **Começar pelo workload e pelos principais access patterns** — listar consultas e writes críticos (SLA, frequência) antes de desenhar coleções.
2. **Decidir explicitamente entre embedding e referencing** — para cada relação 1–N ou N–N, documentar decisão com **justificativa** (tamanho do subdocumento, taxa de atualização, necessidade de query independente, limite de crescimento).
3. **Evitar** documentos inflados, **arrays sem limite de crescimento** documentado (ou padrão bucket/paginação), e **proliferação desnecessária** de coleções (cada coleção tem custo operacional e de schema mental).
4. **Índices compostos** com ordem de campos alinhada ao padrão de consulta; aplicar a guideline **ESR** (Equality → Sort → Range) na ordenação dos campos — ver [references/mongo-indexing.md](references/mongo-indexing.md).
5. **Revisar cardinalidade, seletividade e custo de manutenção** de cada índice proposto (writes, RAM, rebuild em migrações).
6. **Diferenciar** consultas operacionais pontuais, **aggregation** para relatórios/transformação, e workloads **analíticos** pesados (considerar cluster separado, `$out`/`$merge`, read preferences, ou ferramenta OLAP se aplicável).
7. **Transações multi-documento** apenas quando **realmente necessárias**; explicar **custo** (latência, retries, limites, interação com sharding) — ver [references/mongo-aggregation-and-transactions.md](references/mongo-aggregation-and-transactions.md).
8. **Validação de schema** (`$jsonSchema` / collMod): propor quando houver benefício claro (contrato de escrita, evolução controlada), com plano de rollout e compatibilidade com documentos legados.
9. **Alertar riscos** de: atualizações em massa sem filtros/limite; reshaping grande de documentos em produção; migrações **sem controle de batch** (throttle, idempotência, observabilidade).

## Formato obrigatório de resposta

Toda resposta substantiva (modelagem, review de coleção, índices, pipeline, estratégia de growth) deve incluir estas seções, nesta ordem:

| Seção                             | Conteúdo                                                                                           |
| --------------------------------- | -------------------------------------------------------------------------------------------------- |
| **Workload alvo**                 | Domínio, padrões de acesso assumidos ou confirmados, SLAs relevantes.                              |
| **Modelo sugerido**               | Coleções, chaves `_id`, relações, tamanho típico de documento quando possível.                     |
| **Decisão embed vs reference**    | Tabela ou lista por relação: embed, reference, ou híbrido — com **justificativa**.                 |
| **Índices**                       | Simples/compostos, parciais ou TTL se aplicável; ordem dos campos e vínculo com ESR e queries.     |
| **Exemplos de documento**         | 1–2 documentos representativos (campos principais, sem dados sensíveis reais).                     |
| **Queries ou pipeline completos** | `find` com filtros/projeção, updates, ou pipeline de aggregation **completo** e comentado.         |
| **Riscos e evolução futura**      | Hotspots, limites de array, sharding futuro, migrações, validação de schema, degradação sob carga. |

## Workflows

### 1. Modelar pedidos e itens

Seguir [references/mongo-schema-design.md](references/mongo-schema-design.md) (padrão pedido + linhas). Passos: listar leituras (“meus pedidos”, “detalhe do pedido”, “atualizar status da linha”); decidir embed de linhas vs coleção `order_items`; definir índices por `userId + createdAt`, `status`, etc.; mencionar idempotência em writes de checkout.

### 2. Modelar catálogo

Produto como documento vs variantes; referência a categorias; embed de atributos de busca vs normalização; índices de texto ou facetas; cache de leitura e invalidação.

### 3. Revisar coleção problemática

Usar [references/mongo-review-rubric.md](references/mongo-review-rubric.md): tamanho médio/máximo, padrões de update, índices redundantes, `explain` mental ou real, anti-padrões (documento gigante, array ilimitado).

### 4. Criar índices para query conhecida

Mapear predicado de igualdade, sort e range; construir composto com ESR; evitar índice redundante; documentar impacto em writes — [references/mongo-indexing.md](references/mongo-indexing.md).

### 5. Revisar aggregation pipeline

Ordem dos stages (`$match` cedo, projeção cedo), uso de índices, `$lookup` e cardinalidade, memória e `allowDiskUse`, alternativas — [references/mongo-aggregation-and-transactions.md](references/mongo-aggregation-and-transactions.md).

### 6. Projetar estratégia de growth e partitioning lógico

Shard key candidata (cardinalidade, distribuição, queries alinhadas); anti-hotspot; quando preferir coleções por período/tenant vs shard; TTL e arquivamento — cruzar schema design e indexing.

## Referências (progressive disclosure)

- [references/mongo-schema-design.md](references/mongo-schema-design.md) — embed vs reference, pedidos, catálogo, limites.
- [references/mongo-indexing.md](references/mongo-indexing.md) — compostos, ESR, parciais, cardinalidade.
- [references/mongo-aggregation-and-transactions.md](references/mongo-aggregation-and-transactions.md) — pipelines, `$lookup`, transações e custo.
- [references/mongo-safety-checklist.md](references/mongo-safety-checklist.md) — operações seguras em produção.
- [references/mongo-review-rubric.md](references/mongo-review-rubric.md) — revisão sistemática de coleção/schema.

## Integração com o repositório

Se o projeto usar outro banco como fonte da verdade, posicione MongoDB como **adaptador** adequado ao caso (ex.: cache, catálogo, eventos); não alterar regras de negócio do domínio principal sem pedido explícito.
