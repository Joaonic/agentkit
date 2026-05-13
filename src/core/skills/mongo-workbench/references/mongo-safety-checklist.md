# MongoDB — Safety checklist (operação)

Use antes de executar mudanças em **produção** ou dados sensíveis. Adapte à política da organização.

## Planejamento

- [ ] **Backup** ou snapshot recente compatível com tempo de recuperação aceitável.
- [ ] Mudança testada em **staging** com volume e índice representativos (não só 10 documentos).
- [ ] **Janela** comunicada se houver rebuild de índice, migração massiva ou compactação.

## Escrita e migração

- [ ] **Filtro obrigatório** em `updateMany` / `deleteMany` — revisar em par; nunca update sem query em produção interativa.
- [ ] **Batch control:** tamanho de lote, `sleep`/throttle entre lotes, **idempotência** (mesmo lote reexecutado não corrompe).
- [ ] **Reshaping** de documentos (rename massivo, mudança de tipo): estimar rewrites e impacto em réplicas; preferir **dual-write** ou **expand-contract** quando possível.
- [ ] **BulkWrite** com ordenação e `ordered: false` entendida — implicações em erro parcial.

## Índices

- [ ] Criar índice em horário de menor carga quando o manual indicar impacto relevante.
- [ ] Verificar espaço em disco para build temporário.
- [ ] **Rollback:** como dropar índice novo se a regressão aparecer.

## Aggregation destrutiva

- [ ] `$out` / `$merge` apontam para **coleção correta** (namespace, ambiente).
- [ ] Não sobrescrever produção sem prefixo de staging ou feature flag de destino.

## Transações

- [ ] Timeout e retry policy definidos na aplicação.
- [ ] Evitar I/O externo lento **dentro** da transação.

## Segurança e dados

- [ ] **Least privilege** em roles (read vs readWrite vs dbAdmin).
- [ ] Não colar **secrets** em tickets ou logs; rotação se vazou.
- [ ] **TLS** e lista de IPs conforme padrão do projeto.

## Observabilidade

- [ ] Métricas: op latency, queue length, replication lag antes/depois.
- [ ] Logs estruturados com **correlation id** para batches longos.

## Documentação viva

- Conferir comportamento exato (locks, `createIndex`, transações) na **documentação da versão** do cluster, não em posts genéricos.
