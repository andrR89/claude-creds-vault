# gemini (Google Generative Language API)
- **Auth:** header `x-goog-api-key: <key>` (evita a key na URL)
- **Env vars:** `MY_GEMINI_API_KEY` (pessoal) · `NEXXERA_GEMINI_API_KEY` (empresa) — escolha qual usar conforme a tarefa
- **Base URL:** `https://generativelanguage.googleapis.com/v1beta` (pública/fixa, não é segredo)
- **Docs:** API reference: <https://ai.google.dev/api/rest> · modelos: <https://ai.google.dev/gemini-api/docs/models>

> Antes de qualquer curl numa sessão já aberta:
> `set -a; source ~/.config/claude-creds/secrets.env; set +a`
> Modelos úteis: `gemini-2.5-flash` (rápido/barato), `gemini-2.5-pro` (qualidade),
> `gemini-flash-latest` / `gemini-pro-latest` (sempre o mais novo).

## Leitura / uso
```bash
B="https://generativelanguage.googleapis.com/v1beta"; K="$MY_GEMINI_API_KEY"

# modelos disponíveis para a key (filtra os que geram texto)
curl -s -H "x-goog-api-key: $K" "$B/models"

# prompt simples (texto → texto)
curl -s -H "x-goog-api-key: $K" -H "Content-Type: application/json" \
  "$B/models/gemini-2.5-flash:generateContent" \
  -d '{"contents":[{"parts":[{"text":"Resuma em 3 bullets: <texto>"}]}]}'

# com instrução de sistema + controle de geração
curl -s -H "x-goog-api-key: $K" -H "Content-Type: application/json" \
  "$B/models/gemini-2.5-flash:generateContent" -d '{
    "systemInstruction":{"parts":[{"text":"Você é um revisor de código conciso."}]},
    "contents":[{"parts":[{"text":"<prompt>"}]}],
    "generationConfig":{"temperature":0.2,"maxOutputTokens":800}
  }'
```

A resposta vem em `candidates[0].content.parts[0].text`. Para usar a key da empresa,
troque `K="$MY_GEMINI_API_KEY"` por `K="$NEXXERA_GEMINI_API_KEY"`.
