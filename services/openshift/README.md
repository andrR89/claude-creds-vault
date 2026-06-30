# openshift (clusters — logs, pods, deployments via API do k8s)
- **Auth:** SSO Nexxera. Dois estilos por cluster (detectado pela env var):
  - `OKD_<ENV>_CONSOLE_URL` → console OKD4 (proxy k8s em `/api/kubernetes`), login SSO → cookie ~ sessão
  - `OKD_<ENV>_API_URL` → API direta (OpenShift 3.x), login SSO challenge → **token Bearer** (expira)
- **Env vars:** `OKD_<ENV>_CONSOLE_URL` ou `OKD_<ENV>_API_URL` · `SSO_NEXXERA_LOGIN`/`SSO_NEXXERA_PASS`
- **Docs:** Kubernetes API: <https://kubernetes.io/docs/reference/kubernetes-api/> · OpenShift REST (3.x): <https://docs.openshift.com/container-platform/3.11/rest_api/index.html>

> ⚠️ Acesso filtrado pelos seus papéis no cluster — você só vê os namespaces/projetos a
> que tem permissão. **Só leitura por padrão**; escrita (escalar, deletar, patch) só com
> confirmação do usuário.

## Como usar
```bash
set -a; source ~/.config/claude-creds/secrets.env; set +a
cd services/openshift

# log de um pod
./logs.sh INT <namespace> <pod> 50

# API genérica (path SEM barra inicial)
./k8s.sh PRD 'oapi/v1/projects'                                   # projetos (OS3)
./k8s.sh INT 'api/v1/namespaces/portal-relacionamento-dev/pods'   # pods de um namespace
./k8s.sh INT 'apis/apps/v1/namespaces/<ns>/deployments'          # deployments
./k8s.sh INT 'api/v1/namespaces/<ns>/events?sortBy=.lastTimestamp' # events
```

Programaticamente:
```bash
source services/openshift/lib.sh
okd_envs                                   # lista clusters (INT PRD ...)
okd_logs INT <ns> <pod> 100                # últimas 100 linhas
okd_k8s  PRD 'api/v1/namespaces/<ns>/pods' # GET cru
```

## Diferença dos estilos (path do k8s é o mesmo, o prefixo muda)
- **console**: o helper prefixa com `/api/kubernetes/` automaticamente; auth por cookie.
- **api (OS3)**: chama o host direto; auth por header `Authorization: Bearer`. O token é
  renovado sozinho quando expira (novo desafio SSO).

## Adicionar um cluster
Crie no Bitwarden **uma** env (key = nome exato), conforme o tipo:
`OKD_<ENV>_CONSOLE_URL` (OKD4) **ou** `OKD_<ENV>_API_URL` (OS 3.x). Depois `/atualizar`.
As URLs dos clusters ficam no Bitwarden (ex.: `OKD_INT_CONSOLE_URL`, `OKD_PRD_API_URL`) —
nunca hardcoded aqui.
