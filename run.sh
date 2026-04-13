#!/bin/bash
#===============================================================================
# FastNodeUbuntu — One-line runner
# Usage: curl -fsSL https://raw.githubusercontent.com/begugla0/FastNodeUbuntu/main/run.sh | bash
#===============================================================================

set -euo pipefail

REPO_GIT_URL="${REPO_GIT_URL:-https://github.com/begugla0/FastNodeUbuntu.git}"
TEMP_DIR="/tmp/FastNodeUbuntu-$$"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }

cleanup() { info "Очистка..."; rm -rf "${TEMP_DIR}"; }
trap cleanup EXIT

if ! command -v git &>/dev/null; then
    warn "git не найден — устанавливаем..."
    apt-get update -y && apt-get install -y git
fi

info "Клонирование ${REPO_GIT_URL}..."
export GIT_TERMINAL_PROMPT=0
git clone --depth 1 "${REPO_GIT_URL}" "${TEMP_DIR}"

# Устанавливаем права исполнения явно (GitHub API не сохраняет chmod +x)
chmod +x "${TEMP_DIR}/main.sh"
find "${TEMP_DIR}/modules" -name '*.sh' -exec chmod +x {} \;

rm -rf "${TEMP_DIR}/.git"

success "Репозиторий готов — запуск main.sh..."
cd "${TEMP_DIR}" && bash main.sh
