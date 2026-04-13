#!/bin/bash
#===============================================================================
# Module 04: SSH Key Setup
# Ubuntu 24 compatible
#===============================================================================

module_ssh_key() {
    info "Настройка SSH ключей..."

    read -p "Введите имя пользователя для SSH ключа (по умолчанию: root): " ssh_user
    [[ -z "${ssh_user}" ]] && ssh_user="root"

    if ! id "${ssh_user}" >/dev/null 2>&1; then
        warn "Пользователь ${ssh_user} не существует"
        return 1
    fi

    local home_dir
    home_dir=$(getent passwd "${ssh_user}" | cut -d: -f6)
    [[ -z "${home_dir}" ]] && { warn "Домашняя директория не найдена"; return 1; }

    local ssh_dir="${home_dir}/.ssh"
    local auth_keys="${ssh_dir}/authorized_keys"

    mkdir -p "${ssh_dir}"
    chmod 700 "${ssh_dir}"
    chown "${ssh_user}:${ssh_user}" "${ssh_dir}"

    > "${auth_keys}"

    if [[ -n "${SSH_PUBLIC_KEY}" ]]; then
        info "Используется SSH ключ из конфигурации"
        echo -e "${SSH_PUBLIC_KEY}" >> "${auth_keys}"
    else
        echo ""
        echo "Вставьте SSH публичный ключ (Enter дважды для завершения):"
        echo "=========================================="
        while IFS= read -r line; do
            [[ -z "${line}" ]] && break
            echo "${line}" >> "${auth_keys}"
        done
    fi

    [[ ! -s "${auth_keys}" ]] && { warn "SSH ключ не добавлен!"; return 1; }

    chmod 600 "${auth_keys}"
    chown "${ssh_user}:${ssh_user}" "${auth_keys}"

    command -v restorecon &>/dev/null && restorecon -R "${ssh_dir}" 2>/dev/null || true

    success "SSH ключ(и) добавлен(ы) для: ${ssh_user}"
}

module_ssh_key
