#!/usr/bin/env node
/**
 * Gera texto de changelog via OpenAI (gpt-5.4-nano, reasoning medium, sem temperature).
 * Quando o diff/conteúdo excede o limite, resume em chunks e acumula os resumos antes de gerar o changelog (espelho do pipeline think-growth).
 * Uso: node generate-changelog.mjs <version> [diff_file]
 * Lê OPENAI_API_KEY do ambiente. Se diff_file omitido, lê diff do stdin.
 */
import fs from 'node:fs';

const MODEL = 'gpt-5.4-nano';
const OPENAI_URL = 'https://api.openai.com/v1/chat/completions';

/** Chars acima disso: resumir em chunks e acumular antes de gerar changelog (~100k tokens ≈ 400k chars, uso conservador). */
const MAX_DIRECT_INPUT_CHARS = 280_000;
/** Tamanho máximo por chunk ao resumir (cabe em contexto e deixa margem). */
const SUMMARIZE_CHUNK_CHARS = 80_000;

const systemMessageChangelog = `You are a helpful assistant that generates Changelogs based on code changes. Follow these guidelines:
- Changelogs are for humans, not machines.
- Group the same types of changes together.
- Precede each group with ### and a corresponding heading.
- Use the following categories:
  - Added: for new features.
  - Changed: for changes in existing functionality.
  - Deprecated: for soon-to-be removed features.
  - Removed: for now removed features.
  - Fixed: for any bug fixes.
  - Security: in case of vulnerabilities.
- Do not include unnecessary information or treat this as the full document.
- Output only the changelog body (no markdown code fence, no "##" title — that will be added by the pipeline).`;

const systemMessageSummarize =
  'Você é especialista em gerar documentação técnica a partir de código-fonte.';
const userPromptSummarize =
  'Resuma mantendo fluxo de código, regras de negócio, contratos de API, campos utilizados e versões de linguagem.';

async function callOpenai(apiKey, messages, options = {}) {
  const body = {
    model: MODEL,
    messages,
    max_completion_tokens: options.maxCompletionTokens ?? 4096,
    reasoning_effort: options.reasoningEffort ?? 'medium',
  };
  const res = await fetch(OPENAI_URL, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`OpenAI API error: ${res.status} ${err}`);
  }
  const data = await res.json();
  const content = data.choices?.[0]?.message?.content?.trim();
  if (content == null || content === '') {
    throw new Error('Empty response from OpenAI');
  }
  return content;
}

/**
 * Divide texto em chunks por tamanho, respeitando quebras de linha.
 */
function splitIntoChunks(text, maxChunkChars) {
  const chunks = [];
  const lines = text.split(/\r?\n/);
  let current = '';
  let currentLen = 0;
  for (const line of lines) {
    const lineWithNewline = line + '\n';
    const addLen = lineWithNewline.length;
    if (currentLen + addLen > maxChunkChars && currentLen > 0) {
      chunks.push(current);
      current = '';
      currentLen = 0;
    }
    current += lineWithNewline;
    currentLen += lineWithNewline.length;
  }
  if (current.length > 0) chunks.push(current);
  return chunks;
}

/**
 * Resume um chunk via API e retorna o texto do resumo.
 */
async function summarizeChunk(apiKey, chunk) {
  return callOpenai(
    apiKey,
    [
      { role: 'system', content: systemMessageSummarize },
      { role: 'user', content: `${userPromptSummarize}\n\n${chunk}` },
    ],
    { maxCompletionTokens: 2048, reasoningEffort: 'low' },
  );
}

/**
 * Resume conteúdo grande em chunks e acumula os resumos (espelho do gpt_generator.summarize_content).
 */
async function summarizeContent(apiKey, content) {
  const chunks = splitIntoChunks(content, SUMMARIZE_CHUNK_CHARS);
  const summaries = [];
  for (let i = 0; i < chunks.length; i++) {
    summaries.push(await summarizeChunk(apiKey, chunks[i]));
  }
  return summaries.join('\n\n');
}

async function main() {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) {
    console.error('OPENAI_API_KEY is required');
    process.exit(1);
  }

  const version = process.argv[2];
  if (!version) {
    console.error('Usage: node generate-changelog.mjs <version> [diff_file]');
    process.exit(1);
  }

  let diffContent;
  if (process.argv[3]) {
    diffContent = fs.readFileSync(process.argv[3], 'utf8');
  } else {
    diffContent = fs.readFileSync(0, 'utf8');
  }

  if (diffContent.length > MAX_DIRECT_INPUT_CHARS) {
    const numChunks = splitIntoChunks(diffContent, SUMMARIZE_CHUNK_CHARS).length;
    console.error(`Conteúdo grande (${diffContent.length} chars). Resumindo ${numChunks} chunks e acumulando…`);
    const summary = await summarizeContent(apiKey, diffContent);
    diffContent = `Resumo das mudanças (conteúdo original muito grande):\n\n${summary}`;
  }

  const userPrompt = `Generate a changelog for version ${version} based on the following code changes. Output only the changelog body, no \`\`\`markdown fence and no "## [version]" line.\n\n${diffContent}`;

  const content = await callOpenai(
    apiKey,
    [
      { role: 'system', content: systemMessageChangelog },
      { role: 'user', content: userPrompt },
    ],
    { maxCompletionTokens: 4096, reasoningEffort: 'medium' },
  );

  console.log(content);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
