# kibana (logging do OpenShift — Elasticsearch via proxy, multi-ambiente)
- **Auth:** detectada por host — OAuth proxy (login SSO, cookie ~1h) **ou** X-Pack (basic/apikey dedicada)
- **Env vars:** `KIBANA_BASE_URL_<ENV>` (ex.: `_DEV`, `_PRD`) · `SSO_NEXXERA_LOGIN`/`SSO_NEXXERA_PASS` (envs OAuth) · por env X-Pack: `KIBANA_<ENV>_APIKEY` ou `KIBANA_<ENV>_USER`/`KIBANA_<ENV>_PASS`
- **Docs:** Elasticsearch 2.4 (stack EFK do OpenShift): <https://www.elastic.co/guide/en/elasticsearch/reference/2.4/index.html>

> **Não há endpoint/credencial direto do Elasticsearch** — o acesso é só pela sessão do
> Kibana de cada ambiente. O plugin de segurança filtra por projeto: `_all`/`_cluster`/
> `_cat` dão 403; só funcionam os índices `project.<namespace>.*` a que você tem acesso.
>
> **Ambientes têm auth diferente.** `DEV` (cloudint) usa o OAuth proxy do OpenShift →
> login com o SSO. `PRD` usa X-Pack Security → exige credencial **dedicada** (não é a do
> SSO). Sem a credencial do ambiente, ele falha o healthcheck (pendente).

## Como usar
```bash
set -a; source ~/.config/claude-creds/secrets.env; set +a
cd services/kibana

./es.sh DEV 'project.cadun-dev.*/_search?size=5&sort=@timestamp:desc&_source=@timestamp,kubernetes.pod_name,message'
./es.sh PRD '_search?size=1'        # quando o PRD tiver credencial
```

Programaticamente:
```bash
source services/kibana/lib.sh
kibana_envs                                   # lista ambientes (DEV PRD ...)
kibana_curl DEV 'project.nix-dev.*/_count'    # GET; resolve a auth sozinho
kibana_curl DEV '<idx>/_search' -H 'Content-Type: application/json' -d '{"size":1,"query":{"match_all":{}}}'
```

## Adicionar credencial do PRD (X-Pack)
No Bitwarden, crie **uma** das opções (key = nome exato):
`KIBANA_PRD_APIKEY` (API key do ES) **ou** `KIBANA_PRD_USER` + `KIBANA_PRD_PASS`.
Depois `/atualizar` (ou `./bootstrap.sh && ./healthcheck.sh`). O `lib.sh` detecta o
X-Pack e passa a usar essa credencial automaticamente.

## Projetos (index-patterns do ambiente DEV)
`cadun-{dev,qa}`, `commander-{dev,qa}`, `edi{,-dev,-qa,-qae,-tst}`, `nix-{dev,qa,tst}`,
`portal-relacionamento-tst`, `skyline-manager-qa`, `skylineweb-view-{dev,qa}`,
`sso-nix-int`, `team-mercantil-tst`. (Atualize com
`./es.sh DEV '.kibana/index-pattern/_search?size=50&_source=false'`.)
