# <serviço>
- **Auth:** <basic | header token | bearer>
- **Env vars:** `SVC_BASE_URL`, `SVC_TOKEN`
- **Docs:** <link da doc oficial da API> · <link da página de autenticação>

## Receitas de curl (para o Claude usar)
```bash
curl -s -H "Authorization: Bearer $SVC_TOKEN" "$SVC_BASE_URL/api/..."
```
