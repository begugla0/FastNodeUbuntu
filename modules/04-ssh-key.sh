#!/bin/bash
#===============================================================================
# Module 04: SSH Key Setup
# Ubuntu 24 compatible
#===============================================================================

module_ssh_key() {
    info "Настройка SSH ключей..."

    printf "Введите имя пользователя для SSH ключа (по умолчанию: root): "
    read -r ssh_user </dev/tty
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

    if [[ -n "${SSH_PUBLIC_KEY:-}" ]]; then
        info "Используется SSH ключ из settings.conf"
        echo "${SSH_PUBLIC_KEY}" > "${auth_keys}"
    else
        echo ""
        echo -e "\033[1;33mВставьте свой публичный SSH ключ (ssh-rsa ... или ssh-ed25519 ...):\033[0m"
        echo -e "\033[0;34mНажмите Enter дважды после вставки для завершения:\033[0m"
        echo "=========================================="

        > "${auth_keys}"
        local key_count=0
        while true; do
            read -r line </dev/tty
            [[ -z "${line}" ]] && break
            echo "${line}" >> "${auth_keys}"
            (( key_count++ )) || true
        done

        if [[ ${key_count} -eq 0 ]]; then
            warn "Ни одного ключа не было добавлено!"
            return 1
        fi
    fi

    [[ ! -s "${auth_keys}" ]] && { warn "SSH ключ не добавлен!"; return 1; }

    chmod 600 "${auth_keys}"
    chown "${ssh_user}:${ssh_user}" "${auth_keys}"

    command -v restorecon &>/dev/null && restorecon -R "${ssh_dir}" 2>/dev/null || true

    info "Добавлено ключей: $(wc -l < "${auth_keys}")"
    success "SSH ключ(и) добавлен(ы) для: ${ssh_user}"
}

module_ssh_key
