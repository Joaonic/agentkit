# Elasticsearch — Checklist de segurança operacional

Operações incorretas podem causar **perda de dados**, **downtime** ou **instabilidade prolongada**. Sempre citar estes riscos nas respostas da skill.

## Reindex

- **Disco:** duplica dados até concluir; garantir margem ou usar reindex remoto/throttle.
- **Tempo:** jobs longos; falha no meio pode deixar índices intermediários — planejar nomes e limpeza.
- **Versão:** mapping de origem/destino compatível; testar em subconjunto.
- **Alias:** cutover só após validação de contagem/amostragem.

## Forcemerge

- Pode **aumentar I/O** e **bloquear** recursos; em alguns cenários reduz flexibilidade de segmentos.
- Em índices **gerenciados por ILM**, forcemerge automático pode ser perigoso se mal configurado.
- Nunca prometer “sempre melhora latência” — medir antes/depois.

## Mappings grandes

- **Cluster state** cresce com número de campos e índices; propagação lenta.
- **Mapping explosion** (muitos campos dinâmicos) pode derrubar o cluster.
- Mitigar com `dynamic: strict`, limites de tamanho de string, templates disciplinados.

## Instabilidade de cluster

- **Split-brain / master issues** (conforme topologia e versão): seguir práticas de quorum e nós master-eligible.
- **Recovery storm** após restart de muitos nós simultaneamente.
- **Disk watermark:** read-only flood stage bloqueia índices.
- **GC / heap pressure:** queries pesadas + aggs + fielddata podem causar cascata.

## Backups

- Snapshots (repository configurado) antes de reindex massivo, upgrade major ou mudanças de ILM destrutivas.

## Comunicação ao usuário

Ao propor qualquer operação destrutiva ou pesada, a resposta deve listar:

1. O que pode falhar.
2. Como reverter (quando possível).
3. Pré-requisitos (snapshot, janela, capacidade).
