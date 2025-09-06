#!/usr/bin/env bash
set -euo pipefail

# ========= CONFIG PADRÃO (pode sobrescrever por flags) =========
LOCAL_DIR="${HOME}/Documents/CanopusAI/AgentAI_POC"
REPO_NAME=""          # se vazio, usa basename do LOCAL_DIR
OWNER=""              # seu usuário GitHub (ou organização). Se vazio, usa GH_USER
VISIBILITY="private"  # "private" ou "public"
DESCRIPTION="Repo inicial criado via script"
# ===============================================================

usage() {
  cat <<EOF
Uso: $(basename "$0") [opções]
  --dir PATH            Diretório local (padrão: ${LOCAL_DIR})
  --repo NAME           Nome do repositório no GitHub (padrão: basename do diretório)
  --owner NAME          Dono do repositório (se for org, passe o nome da org; senão seu usuário)
  --visibility VALUE    private|public (padrão: ${VISIBILITY})
  --desc TEXT           Descrição (padrão: "${DESCRIPTION}")

Variáveis necessárias:
  GH_USER   -> seu usuário GitHub (ex: mbenedicto99)
  GH_TOKEN  -> seu Personal Access Token (com escopo repo)

Exemplos:
  GH_USER=seuuser GH_TOKEN=seutoken \\
    $(basename "$0") --dir "${HOME}/Documents/CanopusAI/AgentAI_POC" --visibility private
EOF
  exit 1
}

# ---- Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) LOCAL_DIR="$2"; shift 2 ;;
    --repo) REPO_NAME="$2"; shift 2 ;;
    --owner) OWNER="$2"; shift 2 ;;
    --visibility) VISIBILITY="$2"; shift 2 ;;
    --desc) DESCRIPTION="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Opção desconhecida: $1"; usage ;;
  esac
done

# ---- Checagens básicas
command -v git >/dev/null || { echo "git não encontrado. Instale: sudo apt update && sudo apt install -y git"; exit 1; }
command -v curl >/dev/null || { echo "curl não encontrado. Instale: sudo apt update && sudo apt install -y curl"; exit 1; }

if [[ -z "${GH_USER:-}" ]]; then
  read -rp "Digite seu usuário GitHub (GH_USER): " GH_USER
fi

if [[ -z "${GH_TOKEN:-}" ]]; then
  read -rsp "Digite seu GitHub Personal Access Token (GH_TOKEN): " GH_TOKEN; echo
fi

if [[ ! -d "$LOCAL_DIR" ]]; then
  echo "Diretório local não existe: $LOCAL_DIR"; exit 1
fi

cd "$LOCAL_DIR"

# Deriva REPO_NAME se vazio
if [[ -z "${REPO_NAME}" ]]; then
  REPO_NAME="$(basename "$LOCAL_DIR")"
fi

# Dono do repositório
if [[ -z "${OWNER}" ]]; then
  OWNER="${GH_USER}"
fi

echo "==> Diretório local:   $LOCAL_DIR"
echo "==> Repositório:       ${OWNER}/${REPO_NAME}"
echo "==> Visibilidade:      ${VISIBILITY}"
echo "==> Descrição:         ${DESCRIPTION}"
echo

# ---- Inicializa Git se necessário
if [[ ! -d .git ]]; then
  echo "==> git init"
  git init
fi

# .gitignore básico (idempotente)
{
  echo "__pycache__/"
  echo ".venv/"
  echo "*.pyc"
  echo ".chroma/"
  echo ".env"
  echo ".DS_Store"
} | sort -u >> .gitignore || true

git add -A
if ! git diff --cached --quiet; then
  git commit -m "Commit 001"
fi

# Garante branch main
git branch -M main

# ---- Cria o repositório remoto
CREATE_OK=0
if command -v gh >/dev/null 2>&1; then
  echo "==> Usando GitHub CLI (gh) para criar o repositório..."
  # autentica via token (não interativo)
  echo "${GH_TOKEN}" | gh auth login --with-token >/dev/null 2>&1 || true
  if gh auth status >/dev/null 2>&1; then
    if [[ "${OWNER}" == "${GH_USER}" ]]; then
      gh repo create "${REPO_NAME}" --"${VISIBILITY}" --description "${DESCRIPTION}" --confirm >/dev/null 2>&1 || true
    else
      gh repo create "${OWNER}/${REPO_NAME}" --"${VISIBILITY}" --description "${DESCRIPTION}" --confirm >/dev/null 2>&1 || true
    fi
    CREATE_OK=1
  else
    echo "Aviso: falha ao autenticar no gh; tentando via API cURL..."
  fi
fi

if [[ $CREATE_OK -eq 0 ]]; then
  echo "==> Criando via API do GitHub (cURL)..."
  API_URL="https://api.github.com"
  if [[ "${OWNER}" == "${GH_USER}" ]]; then
    # cria em /user/repos
    STATUS=$(curl -sS -o /tmp/resp.json -w "%{http_code}" \
      -H "Authorization: token ${GH_TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      -X POST "${API_URL}/user/repos" \
      -d "$(printf '{"name":"%s","description":"%s","private":%s}' \
           "${REPO_NAME}" "${DESCRIPTION}" "$([[ ${VISIBILITY} == "private" ]] && echo true || echo false)")")
  else
    # cria na organização
    STATUS=$(curl -sS -o /tmp/resp.json -w "%{http_code}" \
      -H "Authorization: token ${GH_TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      -X POST "${API_URL}/orgs/${OWNER}/repos" \
      -d "$(printf '{"name":"%s","description":"%s","private":%s}' \
           "${REPO_NAME}" "${DESCRIPTION}" "$([[ ${VISIBILITY} == "private" ]] && echo true || echo false)")")
  fi

  if [[ "$STATUS" != "201" && "$STATUS" != "422" ]]; then
    echo "Falha ao criar repositório (HTTP $STATUS). Resposta:"
    cat /tmp/resp.json
    exit 1
  fi
  if [[ "$STATUS" == "422" ]]; then
    echo "Aviso: Repositório já existe no GitHub. Seguindo adiante..."
  else
    echo "==> Repositório criado com sucesso."
  fi
fi

# ---- Configura remoto e push
REMOTE_URL="https://github.com/${OWNER}/${REPO_NAME}.git"

if git remote | grep -q "^origin$"; then
  git remote set-url origin "${REMOTE_URL}"
else
  git remote add origin "${REMOTE_URL}"
fi

echo "==> Fazendo primeiro push..."
# Para evitar prompt, usamos a URL com credenciais SOMENTE no primeiro push e depois removemos.
SECURE_REMOTE="https://${GH_USER}:${GH_TOKEN}@github.com/${OWNER}/${REPO_NAME}.git"
git push -u "${SECURE_REMOTE}" main

# trocamos para a URL limpa (sem token)
git remote set-url origin "${REMOTE_URL}"

echo
echo "✅ Pronto! Repositório remoto: https://github.com/${OWNER}/${REPO_NAME}"
echo "   Branch: main (rastreamento configurado)."
echo
echo "Dica: considere revogar o token se for temporário, e/ou usar 'gh auth login' no futuro."

