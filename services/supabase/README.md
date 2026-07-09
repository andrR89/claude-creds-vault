# supabase
- **Auth:** header `Authorization: Bearer $SUPABASE_ACCESS_TOKEN` (personal access token da Management API)
- **Env vars:** `SUPABASE_ACCESS_TOKEN`
- **Base URL:** `https://api.supabase.com/v1` (pública/fixa, não é segredo)
- **Docs:** API reference: <https://supabase.com/docs/reference/api/introduction> · tokens: <https://supabase.com/dashboard/account/tokens>

> Antes de qualquer curl numa sessão já aberta:
> `set -a; source ~/.config/claude-creds/secrets.env; set +a`
> Hierarquia: **organization → project** (cada project tem `ref`, ex. `abcdefghijklmnop`).
> O token é da **Management API** (gerencia orgs/projetos) — não é a anon/service key
> de um projeto; essas podem ser lidas via `/projects/<ref>/api-keys` abaixo.

## Leitura
```bash
B="https://api.supabase.com/v1"; H="Authorization: Bearer $SUPABASE_ACCESS_TOKEN"

curl -s -H "$H" "$B/organizations"                     # organizações (health check)
curl -s -H "$H" "$B/projects"                          # todos os projetos (pega o ref)
curl -s -H "$H" "$B/projects/<ref>"                    # detalhes de um projeto
curl -s -H "$H" "$B/projects/<ref>/api-keys"           # anon/service keys do projeto (⚠️ segredos — não imprimir)
curl -s -H "$H" "$B/projects/<ref>/functions"          # edge functions
curl -s -H "$H" "$B/projects/<ref>/secrets"            # secrets de edge functions (⚠️ segredos)
curl -s -H "$H" "$B/projects/<ref>/config/database/postgres"   # config do Postgres
```

## SQL (leitura via Management API)
```bash
# roda SQL no banco do projeto (⚠️ também executa DML/DDL — trate como escrita se não for SELECT)
curl -s -X POST -H "$H" -H "Content-Type: application/json" \
  "$B/projects/<ref>/database/query" -d '{"query":"select * from pg_tables limit 5"}'
```

## Escrita (⚠️ altera dados reais — confirme antes)
```bash
# criar projeto
curl -s -X POST -H "$H" -H "Content-Type: application/json" "$B/projects" \
  -d '{"organization_id":"<org_id>","name":"meu-projeto","region":"sa-east-1","db_pass":"<senha-forte>"}'

# pausar / restaurar projeto
curl -s -X POST -H "$H" "$B/projects/<ref>/pause"
curl -s -X POST -H "$H" "$B/projects/<ref>/restore"

# criar/atualizar secrets de edge functions
curl -s -X POST -H "$H" -H "Content-Type: application/json" \
  "$B/projects/<ref>/secrets" -d '[{"name":"MINHA_VAR","value":"..."}]'
```
