# Redis key design (reference)

## Convenções

- **Padrão sugerido:** `{namespace}:{tenant|env}:{entity}:{id}[:{facet}]`
- **Separador:** `:` é convenção comum; evite espaços e caracteres que compliquem shell/logs.
- **Ambiente:** `dev`/`stg`/`prod` no prefixo ou instância separada (preferível isolar produção).
- **Versionamento:** sufixo `:v2` ou campo interno quando schema do valor mudar e conviver caches antigos.

## TTL

- **Cache:** TTL alinhado à tolerância de dados velhos; renovar em leitura se “sliding session”.
- **Sem TTL:** apenas com justificativa (ex.: fila controlada por consumo, ou dado pequeno estável).
- **Persistência:** TTL não substitui política RDB/AOF; eviction pode remover chaves antes de backup se mal configurado.

## Invalidação

- **TTL-only:** simples; risco de janela stale.
- **Event-driven:** `DEL` / `UNLINK` (preferível para grandes estruturas quando disponível) em update na fonte de verdade.
- **Version stamp na chave:** novo sufixo evita corrida com writes antigos.
- **Pub/Sub:** notificar outros serviços; não garante entrega (não é fila durável).

## Redis Cluster e hash tags

- Chaves que **devem** estar no mesmo slot para transação multi-key ou operações relacionadas: use **hash tag** `{name}` na mesma posição das chaves, ex.: `cache:{tenant1}:user:1`, `cache:{tenant1}:user:1:meta`.
- Abuso de hash tags estreitos (`{user:1}` para tudo) recria hot slot — balancear.

## Cardinalidade e namespaces

- Estimar chaves ativas por prefixo; ferramentas de inspeção devem usar **SCAN**, não **KEYS**.
- Evitar listar “todas as chaves” em produção.

## Segurança de nomes

- Não embutir PII em chaves se logs/métricas expõem nomes de chave.
- Tokens em valores: criptografia em repouso é responsabilidade do deployment (TLS, ACLs Redis).
