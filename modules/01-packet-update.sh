#!/bin/bash
# ==============================================================================
# Module 01: Обновление пакетов системы
# Поддержка: Ubuntu 22.04 LTS / Ubuntu 24.04 LTS
# ==============================================================================

# Fallback-функции для запуска модуля напрямую
if ! declare -f info > /dev/null 2>&1; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    CYAN='\033[0;36m'; NC='\033[0m'
    info()    { echo -e "${CYAN} ℹ ${*}${NC}"; }
    warn()    { echo -e "${YELLOW} ⚠ ${*}${NC}"; }
    success() { echo -e "${GREEN} ✓ ${*}${NC}"; }
    error()   { echo -e "${RED} ✗ ${*}${NC}"; exit 1; }
fi

# Загрузка конфига при standalone-запуске
if [[ -z "${REQUIRED_PACKAGES[*]:-}" ]]; then
    _BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    [[ -f "${_BASE_DIR}/config/settings.conf" ]] && source "${_BASE_DIR}/config/settings.conf"
fi

module_packet_update() {
    info "Обновление системных пакетов..."

    # Проверка ОС
    if ! grep -qi "ubuntu" /etc/os-release 2>/dev/null; then
        warn "Скрипт оптимизирован для Ubuntu, продолжаем..."
    fi

    local ver
    ver=$(grep VERSION_ID /etc/os-release 2>/dev/null | cut -d'"' -f2)
    info "Версия Ubuntu: ${ver}"

    # Отключаем интерактивные запросы apt
    export DEBIAN_FRONTEND=noninteractive

    # Обновляем списки пакетов
    info "Обновление списков пакетов..."
    apt-get update -y || { warn "apt-get update завершился с ошибкой, продолжаем..."; }

    # Обновляем установленные пакеты без смены версии ОС
    info "Обновление установленных пакетов..."
    apt-get upgrade -y \
        -o Dpkg::Options::="--force-confold" \
        -o Dpkg::Options::="--force-confdef"

    # Full-upgrade: обновляет зависимости, убирает устаревшие
    info "Full-upgrade (зависимости)..."
    apt-get full-upgrade -y \
        -o Dpkg::Options::="--force-confold" \
        -o Dpkg::Options::="--force-confdef"

    # Устанавливаем необходимые пакеты из конфига
    if [[ ${#REQUIRED_PACKAGES[@]} -gt 0 ]]; then
        info "Установка базовых пакетов: ${REQUIRED_PACKAGES[*]}"
        apt-get install -y "${REQUIRED_PACKAGES[@]}" \
            -o Dpkg::Options::="--force-confold" \
            -o Dpkg::Options::="--force-confdef"
    fi

    # Очистка кэша пакетов
    info "Очистка кэша..."
    apt-get autoremove -y
    apt-get autoclean -y

    success "Система обновлена (Ubuntu ${ver})"
}

module_packet_update
