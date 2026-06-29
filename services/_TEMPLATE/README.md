# <serviço>
- **Auth:** <basic | header token | bearer>
- **Env vars:** `SVC_BASE_URL`, `SVC_TOKEN`

## Receitas de curl (para o Claude usar)
```bash
curl -s -H "Authorization: Bearer $SVC_TOKEN" "$SVC_BASE_URL/api/..."
```
