# fal.ai (geração de imagem/mídia)
- **Auth:** header `Authorization: Key $FAL_AI_API_KEY`
- **Env vars:** `FAL_AI_API_KEY`
- **Base URL:** `https://fal.run/<model-id>` (síncrono) · fila: `https://queue.fal.run/<model-id>`
- **Docs:** modelos: <https://fal.ai/models> · API: <https://docs.fal.ai/>

> ⚠️ **Cada geração custa** (billing próprio do fal.ai, sem free tier). Confirme antes de gerar.
> Antes de usar numa sessão aberta: `set -a; source ~/.config/claude-creds/secrets.env; set +a`
> Modelos de imagem úteis: `fal-ai/flux/schnell` (rápido/barato), `fal-ai/flux/dev` (qualidade),
> `fal-ai/flux-pro` (máxima qualidade).

## Gerar imagem (síncrono)
```bash
curl -s -X POST "https://fal.run/fal-ai/flux/dev" \
  -H "Authorization: Key $FAL_AI_API_KEY" -H "Content-Type: application/json" \
  -d '{"prompt":"<descrição em inglês funciona melhor>","image_size":"landscape_4_3","num_images":1}'
# resposta: { "images": [ { "url": "https://v3.fal.media/...", "width":..., "height":... } ], ... }
# baixar: curl -s -o saida.png "<url retornada>"
```

`image_size`: `square_hd`, `square`, `portrait_4_3`, `portrait_16_9`, `landscape_4_3`,
`landscape_16_9`. Parâmetros extras dependem do modelo (ver a página do modelo nos docs).

## Validar a key sem gerar (sem custo)
```bash
curl -s -o /dev/null -w '%{http_code}\n' -H "Authorization: Key $FAL_AI_API_KEY" \
  "https://fal.run/fal-ai/flux/schnell"   # 405 = auth ok, 401 = key inválida
```
