# kibana (logging do OpenShift — Elasticsearch via proxy)
- **Auth:** sessão SSO Nexxera via openshift-auth-proxy (cookie ~1h, renovado sozinho por `lib.sh`)
- **Env vars:** `SSO_NEXXERA_LOGIN`, `SSO_NEXXERA_PASS`
- **Endpoints:** Kibana `https://kibana.cloudint.nexxera.com` · ES via proxy: `…/elasticsearch/<path>`
- **Docs:** Elasticsearch 2.4 (cluster `logging-es`, stack EFK do OpenShift): <https://www.elastic.co/guide/en/elasticsearch/reference/2.4/index.html>

> **Não há endpoint/credencial direto do Elasticsearch** — o acesso é só pela sessão do
> Kibana. O plugin de segurança do OpenShift filtra por projeto: `_all`/`_search` global
> dão **403**; só funcionam os índices `project.<namespace>.*` a que seu SSO tem acesso.
> APIs de cluster (`_cluster/health`, `_cat/*`) também dão **403** (sem permissão de cluster).

## Como usar (helper que garante a sessão)
```bash
set -a; source ~/.config/claude-creds/secrets.env; set +a   # carrega SSO_NEXXERA_*
cd services/kibana

# logs recentes de um projeto
./es.sh 'project.cadun-dev.*/_search?size=5&sort=@timestamp:desc&_source=@timestamp,kubernetes.pod_name,message'

# busca por texto + janela de tempo (query_string)
./es.sh 'project.edi-qa.*/_search?size=20&sort=@timestamp:desc&q=message:ERROR'
```

Programaticamente (em qualquer script), dá pra usar as funções:
```bash
source services/kibana/lib.sh
kibana_ensure                                   # garante o cookie (re-loga se preciso)
kibana_es 'project.nix-dev.*/_count'            # GET simples
kibana_es '<idx>/_search' -H 'Content-Type: application/json' -d '{"size":1,"query":{"match_all":{}}}'  # POST com corpo
```

## Projetos disponíveis (index-patterns do seu Kibana)
`cadun-{dev,qa}`, `commander-{dev,qa}`, `edi{,-dev,-qa,-qae,-tst}`, `nix-{dev,qa,tst}`,
`portal-relacionamento-tst`, `skyline-manager-qa`, `skylineweb-view-{dev,qa}`,
`sso-nix-int`, `team-mercantil-tst`. (Liste atualizado com
`./es.sh '.kibana/index-pattern/_search?size=50&_source=false'`.)
