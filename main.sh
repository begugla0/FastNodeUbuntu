#!/bin/bash
#===============================================================================
# FastNodeUbuntu — Ubuntu 24 Server Automation Script
# Version: 1.0.1
#===============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="${SCRIPT_DIR}/modules"
CONFIG_DIR="${SCRIPT_DIR}/config"
LOGS_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOGS_DIR}/setup_$(date +%Y%m%d_%H%M%S).log"

if [[ -f "${CONFIG_DIR}/settings.conf" ]]; then
    source "${CONFIG_DIR}/settings.conf"
else
    echo -e "${RED}[ERROR] Конфиг не найден: ${CONFIG_DIR}/settings.conf${NC}"
    exit 1
fi

#-------------------------------------------------------------------------------
# Logging
#-------------------------------------------------------------------------------
log() {
    local level="$1"; shift
    local msg="$*"
    local ts; ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${ts}] [${level}] ${msg}" >> "${LOG_FILE}"
}

info()    { log "INFO"    "$@"; echo -e "${CYAN}  ℹ  $*${NC}"; }
warn()    { log "WARN"    "$@"; echo -e "${YELLOW}  ⚠  $*${NC}"; }
error()   { log "ERROR"   "$@"; echo -e "${RED}  ✗  $*${NC}"; }
success() { log "SUCCESS" "$@"; echo -e "${GREEN}  ✓  $*${NC}"; }

#-------------------------------------------------------------------------------
# Checks
#-------------------------------------------------------------------------------
check_root() {
    [[ $EUID -ne 0 ]] && { error "Запустите скрипт от root"; exit 1; }
}

check_ubuntu() {
    if ! grep -qi "ubuntu" /etc/os-release 2>/dev/null; then
        error "Этот скрипт предназначен для Ubuntu"
        exit 1
    fi
    local ver
    ver=$(grep VERSION_ID /etc/os-release | cut -d'"' -f2)
    info "Обнаружена Ubuntu ${ver}"
}

create_dirs() {
    mkdir -p "${LOGS_DIR}"
}

#-------------------------------------------------------------------------------
# Module runner
#-------------------------------------------------------------------------------
run_module() {
    local module="$1"
    local path="${MODULES_DIR}/${module}"
    if [[ -f "${path}" ]]; then
        info "━━ Модуль: ${module} ━━"
        # shellcheck source=/dev/null
        source "${path}"
        success "Модуль ${module} — готово"
    else
        warn "Модуль не найден: ${module}"
        return 1
    fi
}

#-------------------------------------------------------------------------------
# Menu
#-------------------------------------------------------------------------------
show_menu() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   FastNodeUbuntu — Ubuntu 24 Setup     ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${CYAN}2${NC})  Настройка локали (ru_RU.UTF-8)"
    echo -e "  ${CYAN}3${NC})  Синхронизация времени (МСК)"
    echo -e "  ${CYAN}4${NC})  Настройка SSH ключа"
    echo -e "  ${CYAN}5${NC})  Hardening SSH (порт 2225)"
    echo -e "  ${CYAN}6${NC})  Настройка SWAP (2GB)"
    echo -e "  ${CYAN}7${NC})  Установка пакетов"
    echo ""
    echo -e "  ${GREEN}111${NC}) Выполнить ВСЕ модули"
    echo -e "  ${RED}222${NC}) Выход"
    echo ""
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------
main() {
    check_root
    check_ubuntu
    create_dirs

    info "FastNodeUbuntu запущен"
    info "Ядро: $(uname -r)"

    if [[ "${INTERACTIVE_MODE:-true}" == "false" ]]; then
        info "Автоматический режим — запуск всех модулей"
        for mod in $(ls -1 "${MODULES_DIR}"/*.sh 2>/dev/null | sort); do
            run_module "$(basename "${mod}")"
        done
    else
        show_menu
        local choice=""
        # Читаем всегда из /dev/tty — работает даже при curl | bash
        while true; do
            read -p "Выберите номер: " choice </dev/tty
            case "${choice}" in
                2|3|4|5|6|7|111|222) break ;;
                *) echo -e "${RED}Неверный выбор. Введите номер из списка.${NC}" ;;
            esac
        done

        case "${choice}" in
            2)   run_module "02-locale-setup.sh"   ;;
            3)   run_module "03-time-sync.sh"       ;;
            4)   run_module "04-ssh-key.sh"         ;;
            5)   run_module "05-ssh-hardening.sh"   ;;
            6)   run_module "06-swap-setup.sh"      ;;
            7)   run_module "07-packages.sh"        ;;
            111)
                info "Запуск всех модулей..."
                for mod in $(ls -1 "${MODULES_DIR}"/*.sh 2>/dev/null | sort); do
                    run_module "$(basename "${mod}")"
                done
                ;;
            222) info "Выход"; exit 0 ;;
        esac
    fi

    success "Настройка завершена!"
    info "Лог: ${LOG_FILE}"
}

main "$@"
