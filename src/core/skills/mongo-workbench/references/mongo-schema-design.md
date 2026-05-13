# MongoDB — Schema design (embed vs reference)

## Princípio orientador

Modelar para os **access patterns** confirmados, não para um diagrama ER “puro”. Cada decisão deve responder: _qual query ou write esta forma otimiza?_

## Embedding (subdocumentos ou arrays)

**Bom quando:**

- Dados são lidos e atualizados **em conjunto** com o documento pai com alta frequência.
- Cardinalidade é **limitada e acotada** (ex.: poucas dezenas de linhas de pedido, endereços limitados).
- Não há necessidade forte de consultar/atualizar o filho **independentemente** do pai em escala.
- Consistência lógica “um write” é desejável (um round-trip).

**Evitar quando:**

- O array ou subdocumento pode **crescer sem teto** (logs, eventos, comentários ilimitados) — usar coleção separada, bucketing, ou paginação por documento.
- O mesmo subdocumento seria **duplicado** em muitos pais com atualizações frequentes (normalizar com reference).
- Tamanho do documento se aproxima de limites operacionais (BSON ~16MB) ou causa pressão de memória em working set.

## Referencing (ObjectId / chave natural)

**Bom quando:**

- Entidade tem **ciclo de vida próprio** e queries do tipo “todos os X onde …” independentes do pai.
- **Muitos-para-muitos** com metadados na relação (coleção de junção ou array de ids com cuidado).
- Atualizações frequentes no filho sem reescrever o pai inteiro.
- Reuso do mesmo documento por muitos pais sem duplicar payload grande.

**Custo:** joins lógicos via `$lookup` ou múltiplas idas ao banco; consistência eventual entre coleções salvo transação.

## Padrões frequentes

### Pedido + itens

- **Embed linhas** no pedido: simples, leitura de detalhe em um `find`; ruim se linhas forem atualizadas concorrentemente em massa ou número de linhas for muito alto.
- **Coleção `order_items`** com `orderId`: melhor para relatórios por SKU, atualização granular, índices por produto; detalhe do pedido exige segundo query ou `$lookup`.
- **Híbrido:** cabeçalho + resumo embed; detalhe extenso em outra coleção.

### Catálogo

- **Produto único** com variantes como sub-array se poucas variantes e leitura sempre “produto completo”.
- **Variante como documento** se buscas por SKU/EAN dominam ou variantes são muitas.
- **Categorias:** árvore por referência + materialized path ou array de ancestrais para navegação; evitar árvore profunda com updates em cascata no mesmo documento gigante.

## Anti-padrões

- Documento “Deus” agregando entidades não relacionadas só para evitar coleções.
- Arrays append-only sem política de arquivo/TTL/cap.
- Duplicar grandes blobs mutáveis (imagem, texto legal) em centenas de documentos.

## Validação de schema

Considerar `$jsonSchema` quando:

- Equipes múltiplas escrevem na mesma coleção.
- Evolução de campos precisa ser **contratual** (required, enums, tipos).

Planejar: validação em modo `moderate`/`strict` conforme versão; compatibilidade com documentos legados; deploy em etapas.

## Leitura adicional (consultar versão do ambiente)

No MongoDB Manual da sua release: **Data Modeling**, **Document Growth**, **Atomicity of Operations**.
