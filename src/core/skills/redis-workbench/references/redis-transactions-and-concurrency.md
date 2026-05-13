# Transactions and concurrency (reference)

**Fonte canônica:** [Transactions](https://redis.io/docs/latest/develop/interact/transactions/) e documentação de **WATCH**, **MULTI**, **EXEC**, **DISCARD**.

## MULTI / EXEC

- **MULTI** inicia fila de comandos; **EXEC** executa em sequência **atômica** (sem intercalação de outros clientes entre os comandos enfileirados).
- **Não é** rollback automático se um comando falhar após outros na mesma EXEC — validar comportamento de erro na versão e no cliente.
- Uso típico: várias escritas que precisam aparecer juntas.

## WATCH (optimistic locking)

- **WATCH** chave(s): se alguma chave observada mudar antes de **EXEC**, a transação é abortada (EXEC retorna condição vazia / nil conforme cliente).
- Padrão: `WATCH key` → `GET` / lógica na app → `MULTI` → `SET` / operações → `EXEC`; em falha, retry com backoff.
- **Cluster:** operações **multi-key** só se todas as chaves estiverem no **mesmo hash slot**; caso contrário, redesign ou operações separadas com compensação na aplicação.

## Lua / functions (server-side)

- Scripts podem reduzir round-trips e garantir atomicidade **no nó** que executa o script.
- Riscos: script longo bloqueia o núcleo single-threaded do Redis (impacto em latência).
- Ver doc atual para **Redis Functions** vs EVAL / deprecações.

## Alternativas quando transação simples não basta

- **Redlock** (locks distribuídos): controverso; exige entendimento de falhas de relógio e nós; muitas vezes melhor usar fila/idempotência.
- **Out-of-band:** idempotency keys, versionamento em DB, sagas na aplicação.

## Checklist

- [ ] Precisa atomicidade de várias chaves no mesmo slot (cluster)?
- [ ] Race entre leitura e escrita → **WATCH** ou script curto?
- [ ] Script é curto e sem loops grandes?
- [ ] Cliente trata abort de EXEC e faz retry seguro?
