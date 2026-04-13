#!/bin/bash
#===============================================================================
# Module 06: SWAP — 2GB, swappiness=80
# Ubuntu 24 compatible (btrfs fallback)
#===============================================================================

module_swap_setup() {
    info "Настройка SWAP (${SWAP_SIZE}, swappiness=${SWAP_SWAPPINESS})..."

    local swap_exists swap_size
    swap_exists=$(swapon --show --noheadings | wc -l)
    swap_size=$(free -m | awk '/Swap:/ {print $2}')

    info "Текущий SWAP: ${swap_size} MB (разделов: ${swap_exists})"

    if [[ ${swap_exists} -gt 0 ]] && [[ ${swap_size} -gt 512 ]]; then
        success "SWAP уже настроен (${swap_size} MB)"
        return 0
    fi

    if [[ -f "${SWAP_FILE}" ]]; then
        swapoff "${SWAP_FILE}" 2>/dev/null || true
        rm -f "${SWAP_FILE}"
    fi

    info "Создание ${SWAP_SIZE} swap-файла..."

    if df --output=fstype "$(dirname "${SWAP_FILE}")" 2>/dev/null | grep -q btrfs; then
        info "Файловая система btrfs — используем dd"
        dd if=/dev/zero of="${SWAP_FILE}" bs=1M count=2048 status=progress
    else
        fallocate -l "${SWAP_SIZE}" "${SWAP_FILE}"
    fi

    chmod 600 "${SWAP_FILE}"
    mkswap "${SWAP_FILE}"
    swapon "${SWAP_FILE}"

    grep -q "${SWAP_FILE}" /etc/fstab || \
        echo "${SWAP_FILE} none swap sw 0 0" >> /etc/fstab

    local swappiness_conf="/etc/sysctl.d/99-swap.conf"
    echo "vm.swappiness=${SWAP_SWAPPINESS}" > "${swappiness_conf}"
    sysctl -p "${swappiness_conf}" &>/dev/null

    local new_swap
    new_swap=$(free -m | awk '/Swap:/ {print $2}')
    success "SWAP создан: ${new_swap} MB | swappiness=${SWAP_SWAPPINESS}"
}

module_swap_setup
