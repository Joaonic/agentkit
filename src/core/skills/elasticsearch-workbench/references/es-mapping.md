# Elasticsearch — Mapping e templates

Consulte a documentação oficial da **versão exata** do cluster (Elasticsearch ou OpenSearch) para nomes de parâmetros e limites.

## Princípios

- **Produção:** mapping **explícito** para todos os campos conhecidos.
- **Dynamic:** usar `dynamic: strict` (falha ao receber campo novo) ou `false` (ignora desconhecidos) quando o esquema for contrato estável; `dynamic: true` apenas em prototipagem ou com **dynamic_templates** muito explícitos.
- **Mudança incompatível:** alterar tipo de campo, muitas propriedades analíticas ou analyzer em campo já indexado costuma exigir **novo índice + reindex**; planejar **alias** para cutover.

## Tipos — quando usar

| Tipo / padrão                                      | Uso típico                                                              | Notas                                                                           |
| -------------------------------------------------- | ----------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| `text`                                             | Corpo pesquisável, match, highlighting                                  | Subcampo `.keyword` para sort/aggs/filtro exato se necessário                   |
| `keyword`                                          | IDs, enums, facetas, sort, aggs                                         | `ignore_above` para strings longas; cuidado com cardinalidade                   |
| Numéricos (`long`, `double`, `scaled_float`, etc.) | Métricas, preços, contagens                                             | `scaled_float` para decimais com escala fixa                                    |
| `date`                                             | Timestamps                                                              | Formato `strict_date_optional_time` ou `epoch_millis`; timezone na query        |
| `boolean`                                          | Flags                                                                   |                                                                                 |
| `object`                                           | JSON aninhado simples                                                   | Sem array de objetos independentes                                              |
| `nested`                                           | Array de objetos onde cada item deve ser agregado/filtrado isoladamente | Custo de query maior — usar só quando necessário                                |
| `dense_vector` / campos de vetor                   | Similaridade semântica                                                  | Dimensão fixa, requisitos de versão; combinar com query vector/kNN conforme doc |

## Revisão campo a campo (checklist)

- [ ] É filtro/sort/agregação? → preferir `keyword` ou numérico com `doc_values`.
- [ ] É full-text? → `text` + multi-field `keyword` se precisar de “raw”.
- [ ] String longa e irrelevante para aggs? → `ignore_above`, desabilitar `fielddata`.
- [ ] Evitar **mapping explosion** (muitos campos dinâmicos de chaves variáveis).

## Index templates

- **Component templates** + **index template** (padrão moderno Elastic) para padronizar settings + mappings.
- Ordem de precedência: consultar doc da versão (priority, composed_of).
- Nome sugerido: prefixo estável + sufixo de versão (`myapp-logs@0001`).

## Workflow: desenho de índice novo

1. Listar entidades e campos com tipo de query (filter, full-text, range, nested).
2. Definir `dynamic` e `dynamic_templates` (se houver JSON semi-estruturado).
3. Escrever `properties` completos; marcar campos só de ingestão como `index: false` se não forem buscados.
4. Definir **alias** write + read; template apontando para padrão de nome.
5. Validar com documento representativo + query de smoke (match + aggs esperadas).

## Workflow: revisão de mapping existente

1. Exportar mapping atual (`GET index/_mapping`).
2. Comparar com requisitos; classificar mudanças em **compatível** (novo campo, novos properties opcionais) vs **incompatível**.
3. Para incompatível: planejar índice novo, reindex, swap de alias, rollback.
4. Verificar tamanho do mapping (campos) e impacto em cluster state.

## Workflow: catálogo de produtos

- **ID / SKU:** `keyword`.
- **Título / descrição:** `text` + `.keyword` opcional para sort exato.
- **Facetas** (marca, categoria): `keyword`; normalizar casing na ingestão se necessário.
- **Preço / estoque:** tipos numéricos adequados; ranges com `double`/`long`.
- **Atributos variáveis:** preferir `flattened` (quando disponível na versão) vs explosão de `object` dinâmico; **nested** só para listas que precisam de aggs independentes (ex.: variantes com preço por SKU).
- **Evitar** aggs em campo `text` puro; usar subcampo `keyword`.
