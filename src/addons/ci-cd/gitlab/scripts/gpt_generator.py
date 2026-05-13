#!/usr/bin/env python3
"""
gpt_generator.py  –  Gere texto ou resuma conteúdo via OpenAI Chat-Completions
Contrato CLI preservado:
    python3 gpt_generator.py <system_message> <user_prompt> <api_key> <model> --content <content_file>
Changelog 1.0.18:
* Novo dicionário COMPLETION_LIMIT para limitar max_tokens (32 768 para GPT-4.1,
  4 096 para 4-o e “turbo”, default 4 096).
* Cálculo de max_answer_tok = min(COMPLETION_LIMIT[model], espaço disponível).
* Demais melhorias de 1.0.17 mantidas.
"""

from __future__ import annotations

import argparse
import logging
import os
import re
import time
from typing import List, Optional

import requests
import tiktoken

# --------------------------------------------------#
# Configuração                                      #
# --------------------------------------------------#

LOG_FILE = "gpt_generator.log"
MAX_RETRIES = 6
RETRY_BACKOFF_SEC = 2  # back-off exponencial inicial

# Janela total (context window) por modelo
CONTEXT_WINDOW = {
    "gpt-4.1": 1_000_000,
    "gpt-4.1-mini": 1_000_000,
    "gpt-4.1-nano": 1_000_000,
    "gpt-4o": 128_000,
    "gpt-4o-mini": 128_000,
    "gpt-4": 128_000,
    "gpt-4-turbo": 128_000,
    "gpt-3.5-turbo": 128_000,
}

# Limite de tokens **de resposta** (“completion tokens”)
COMPLETION_LIMIT = {
    "gpt-4.1": 32_768,
    "gpt-4.1-mini": 32_768,
    "gpt-4.1-nano": 32_768,
    "gpt-4o": 4_096,
    "gpt-4o-mini": 4_096,
    "gpt-4": 4_096,
    "gpt-4-turbo": 4_096,
    "gpt-3.5-turbo": 4_096,
}
DEFAULT_COMPLETION_LIMIT = 4_096

# Tokenizadores fallback
MODEL_TO_ENCODING_FALLBACK = {
    "gpt-4.1": "o200k_base",
    "gpt-4.1-mini": "o200k_base",
    "gpt-4.1-nano": "o200k_base",
    "gpt-4o": "o200k_base",
    "gpt-4o-mini": "o200k_base",
}

# --------------------------------------------------#
# Logging                                           #
# --------------------------------------------------#

logging.basicConfig(
    handlers=[logging.FileHandler(LOG_FILE), logging.StreamHandler()],
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)

# --------------------------------------------------#
# Token helpers                                     #
# --------------------------------------------------#


def _get_tokenizer(model: str) -> "tiktoken.Encoding":
    try:
        return tiktoken.encoding_for_model(model)
    except KeyError:
        enc_name = MODEL_TO_ENCODING_FALLBACK.get(model, "cl100k_base")
        logger.debug("Tokenizer desconhecido (%s); usando %s.", model, enc_name)
        return tiktoken.get_encoding(enc_name)


def count_tokens(text: str, model: str) -> int:
    return len(_get_tokenizer(model).encode(text))


# --------------------------------------------------#
# Chunk helpers                                     #
# --------------------------------------------------#


def _split_large_block(block: str, enc: "tiktoken.Encoding", max_toks: int) -> List[str]:
    lines, out, cur, cur_tok = block.splitlines(keepends=True), [], "", 0
    for ln in lines:
        lt = len(enc.encode(ln))
        if cur_tok + lt <= max_toks:
            cur += ln
            cur_tok += lt
        else:
            if cur:
                out.append(cur.rstrip())
            cur, cur_tok = ln, lt
    if cur:
        out.append(cur.rstrip())
    return out


def split_text_into_chunks(text: str, model: str, max_tokens: int) -> List[str]:
    enc = _get_tokenizer(model)
    patt_delim = r"(====.*?====\n(?:.|\n)*?)(?=====|$)"
    patt_diff = r"(@@.*?@@\n(?:.|\n)*?)(?=@@|$)"
    patt = patt_diff if re.search(patt_diff, text) else patt_delim
    blocks = re.findall(patt, text)

    chunks, cur, cur_tok = [], "", 0
    for blk in blocks:
        bt = len(enc.encode(blk))
        if cur_tok + bt <= max_tokens:
            cur += blk
            cur_tok += bt
        else:
            if cur:
                chunks.append(cur.rstrip())
            if bt > max_tokens:
                chunks.extend(_split_large_block(blk, enc, max_tokens))
                cur, cur_tok = "", 0
            else:
                cur, cur_tok = blk, bt
    if cur:
        chunks.append(cur.rstrip())
    return chunks


# --------------------------------------------------#
# OpenAI API helper                                 #
# --------------------------------------------------#


def _call_openai(
    sys_msg: str,
    usr_msg: str,
    api_key: str,
    model: str,
    max_tokens: Optional[int] = None,
) -> str:
    url = "https://api.openai.com/v1/chat/completions"
    headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}
    payload = {
        "model": model,
        "messages": [{"role": "system", "content": sys_msg}, {"role": "user", "content": usr_msg}],
    }
    if max_tokens is not None:
        payload["max_tokens"] = max_tokens

    retry, wait = 0, RETRY_BACKOFF_SEC
    while True:
        rsp = requests.post(url, headers=headers, json=payload, timeout=90)
        if rsp.status_code == 200:
            return rsp.json()["choices"][0]["message"]["content"]
        if rsp.status_code in (429, 502, 503, 504) and retry < MAX_RETRIES:
            logger.warning(
                "OpenAI %d %s – retry #%d em %ds",
                rsp.status_code,
                rsp.reason,
                retry + 1,
                wait,
            )
            time.sleep(wait)
            retry += 1
            wait *= 2
            continue
        logger.error("OpenAI erro %d: %s", rsp.status_code, rsp.text)
        rsp.raise_for_status()


# --------------------------------------------------#
# Summaries                                         #
# --------------------------------------------------#


def summarize_chunk(chunk: str, api_key: str, model: str) -> str:
    sys = "Você é especialista em gerar documentação técnica a partir de código-fonte."
    usr = (
        "Resuma mantendo fluxo de código, regras de negócio, contratos de API, "
        "campos utilizados e versões de linguagem.\n\n"
        f"{chunk}"
    )
    return _call_openai(sys, usr, api_key, model, max_tokens=2_000)


def summarize_content(content: str, api_key: str, model: str) -> str:
    ctx = CONTEXT_WINDOW.get(model, 128_000)
    chunks = split_text_into_chunks(content, model, int(ctx * 0.95))
    logger.info("Resumindo %d chunks…", len(chunks))
    return "\n".join(summarize_chunk(c, api_key, model) for c in chunks)


# --------------------------------------------------#
# Geração principal                                 #
# --------------------------------------------------#


def generate_text_via_gpt(
    system_message: str,
    user_prompt: str,
    api_key: str,
    model: str,
    content_file: Optional[str] = None,
) -> Optional[str]:
    tok = _get_tokenizer(model)
    base_tok = len(tok.encode(system_message)) + len(tok.encode(user_prompt))
    ctx = CONTEXT_WINDOW.get(model, 128_000)
    spare = ctx - base_tok

    if content_file:
        if not os.path.isfile(content_file):
            logger.error("Arquivo %s não encontrado.", content_file)
            return None
        with open(content_file, "r", encoding="utf-8") as fh:
            content = fh.read()

        c_tok = len(tok.encode(content))
        logger.info("Base: %d tok • Conteúdo: %d tok • Limite: %d", base_tok, c_tok, ctx)

        if c_tok <= spare * 0.95:
            user_prompt = f"{user_prompt}\n\n{content}"
        else:
            summary = summarize_content(content, api_key, model)
            user_prompt = f"{user_prompt}\n\nResumo:\n{summary}"

    # ---------------- Limite de completion ----------------#
    comp_limit = COMPLETION_LIMIT.get(model, DEFAULT_COMPLETION_LIMIT)
    max_answer_tok = min(comp_limit, int((ctx - len(tok.encode(user_prompt))) * 0.9))
    # Garante ao menos 32 tokens de resposta
    max_answer_tok = max(32, max_answer_tok)

    return _call_openai(system_message, user_prompt, api_key, model, max_tokens=max_answer_tok)


# --------------------------------------------------#
# CLI - contrato preservado                         #
# --------------------------------------------------#


def _cli() -> None:
    logger.info("🚀 Iniciando gpt_generator")
    p = argparse.ArgumentParser(description="Gerar texto via OpenAI Chat-Completions.")
    p.add_argument("system_message", help="Mensagem de sistema")
    p.add_argument("user_prompt", help="Prompt do usuário")
    p.add_argument("api_key", help="Chave da API do OpenAI")
    p.add_argument("model", nargs="?", default="gpt-4.1-mini", help="Modelo (default: gpt-4.1-mini)")
    p.add_argument("--content", help="Arquivo de conteúdo a resumir/analisar")
    args = p.parse_args()

    try:
        out = generate_text_via_gpt(
            args.system_message, args.user_prompt, args.api_key, args.model, args.content
        )
        if out:
            print(out)
        else:
            logger.info("Nenhum resultado gerado.")
    except Exception as exc:  # noqa: BLE001
        logger.exception("Falha: %s", exc)
        raise SystemExit(1) from exc


if __name__ == "__main__":
    _cli()
