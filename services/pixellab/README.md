# pixellab
- **Auth:** header `Authorization: Bearer $PIXELLAB_API_KEY` (token da página da conta)
- **Env vars:** `PIXELLAB_API_KEY`
- **Base URL:** `https://api.pixellab.ai/v2` (pública/fixa, não é segredo)
- **Docs:** llms.txt: <https://api.pixellab.ai/v2/llms.txt> · interativa: <https://api.pixellab.ai/v2/docs> · OpenAPI: <https://api.pixellab.ai/v2/openapi.json>

> Antes de qualquer curl numa sessão já aberta:
> `set -a; source ~/.config/claude-creds/secrets.env; set +a`
> Gera pixel art para jogos (personagens 4/8 direções, animações, tilesets,
> tiles isométricos, inpaint, rotação, estilo). A **maioria das gerações é
> assíncrona**: o POST devolve um job id que se consulta até ficar pronto.

## Leitura
```bash
B="https://api.pixellab.ai/v2"; H="Authorization: Bearer $PIXELLAB_API_KEY"

curl -s -H "$H" "$B/balance"                        # saldo de créditos (health check)
curl -s -H "$H" "$B/characters"                     # personagens do usuário
curl -s -H "$H" "$B/characters/<id>"                # detalhes de um personagem
curl -s -H "$H" "$B/tilesets"                       # tilesets gerados
curl -s -H "$H" "$B/objects"                        # objetos de mapa
curl -s -H "$H" "$B/background-jobs/<job_id>"       # status de um job assíncrono
curl -s -H "$H" -o char.zip "$B/characters/<id>/zip"  # exporta personagem (ZIP)
```

## Escrita (⚠️ consome créditos da conta — confirme antes)
```bash
# gerar imagem pixel art (pixflux) — síncrono, retorna a imagem em base64
curl -s -X POST -H "$H" -H "Content-Type: application/json" "$B/create-image-pixflux" \
  -d '{"description":"cute dragon","image_size":{"width":64,"height":64}}'

# criar personagem com 8 direções — assíncrono, retorna job/character id
curl -s -X POST -H "$H" -H "Content-Type: application/json" \
  "$B/create-character-with-8-directions" -d '{"description":"knight in armor"}'

# depois, poll até ficar pronto:
curl -s -H "$H" "$B/characters/<character_id>"

# deletar personagem/objeto (⚠️ apaga tudo associado)
curl -s -X DELETE -H "$H" "$B/characters/<id>"
```
