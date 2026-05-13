# MongoDB — Review rubric (coleção / schema)

Pontue mentalmente ou explícito; priorize itens que afetam **escala** e **corrupção lógica**.

## A. Alinhamento ao workload (peso alto)

- [ ] Access patterns principais estão documentados e **suportados** pelo modelo atual?
- [ ] Alguma query crítica força **COLLSCAN** ou sort em memória por falta de índice?
- [ ] Leitura vs escrita balanceada com o índice proposto?

## B. Forma do documento

- [ ] Tamanho médio e pico do BSON são razoáveis para o working set?
- [ ] Arrays têm **limite de crescimento** ou estratégia (cap, archive, bucket)?
- [ ] Campos mutáveis grandes estão embedados onde causam **rewrite** frequente do documento inteiro?

## C. Embed vs reference

- [ ] Cada relação 1–N / N–N tem decisão **explícita** e justificada?
- [ ] Duplicação de dados é **intencional** (read optimization) e com política de atualização?

## D. Índices

- [ ] Ordem dos campos segue **ESR** para a query canônica?
- [ ] Índices **redundantes** ou quase redundantes?
- [ ] **Partial / TTL** considerados onde reduzem superfície?
- [ ] Multikey em array ilimitado?

## E. Aggregation e relatórios

- [ ] Pipelines pesados rodam fora do **caminho crítico** ou com isolamento (secondary, batch)?
- [ ] `$lookup` com cardinalidade controlada e índices nas chaves?

## F. Transações e consistência

- [ ] Uso de transação é **mínimo** necessário?
- [ ] Alternativas (single doc, idempotência, outbox) foram consideradas?

## G. Validação e evolução

- [ ] Schema validation ajudaria sem travar deploys?
- [ ] Plano de **migração** em batches com rollback?

## H. Operação e segurança

- [ ] Shard key (se sharded) evita hotspot?
- [ ] Roles e dados sensíveis (PII) tratados conforme política?

## Saída sugerida da revisão

Resumir: **severidade** (baixa/média/alta), **achados** por letra acima, **ações** priorizadas (quick win vs projeto), e **riscos** se nada for feito.
