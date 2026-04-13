#!/bin/bash
#===============================================================================
# Module 05: SSH Hardening — порт 2225
# Ubuntu 24 compatible (drop-in /etc/ssh/sshd_config.d/)
#===============================================================================

module_ssh_hardening() {
    info "Hardening SSH (порт ${SSH_PORT})..."

    local sshd_config="/etc/ssh/sshd_config"
    local dropin_dir="/etc/ssh/sshd_config.d"
    local dropin_file="${dropin_dir}/99-hardening.conf"
    local backup="${sshd_config}.backup.$(date +%Y%m%d_%H%M%S)"

    cp "${sshd_config}" "${backup}"
    info "Резервная копия: ${backup}"

    mkdir -p "${dropin_dir}"

    if ! grep -q "^Include ${dropin_dir}/" "${sshd_config}"; then
        echo "Include ${dropin_dir}/*.conf" >> "${sshd_config}"
        info "Добавлена директива Include"
    fi

    cat > "${dropin_file}" <<EOF
# FastNodeUbuntu — SSH Hardening
# Ubuntu 24 drop-in config
Port ${SSH_PORT}
PermitRootLogin ${SSH_PERMIT_ROOT}
PermitEmptyPasswords ${SSH_EMPTY_PASSWORDS}
PasswordAuthentication ${SSH_PASSWORD_AUTH}
PubkeyAuthentication yes
AuthenticationMethods publickey
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
EOF

    info "Hardening конфиг → ${dropin_file}"

    if sshd -t -f "${sshd_config}"; then
        success "SSH конфигурация валидна"

        local ssh_service="sshd"
        systemctl list-units --type=service 2>/dev/null | grep -q 'ssh\.service' && ssh_service="ssh"

        systemctl restart "${ssh_service}"
        success "SSH перезапущен на порту ${SSH_PORT} (${ssh_service})"

        warn "НЕ ЗАКРЫВАЙТЕ СЕССИЮ! Проверьте подключение к порту ${SSH_PORT}"
        read -p "Подтвердите что подключение работает (yes/no): " confirm
        if [[ "${confirm}" != "yes" ]]; then
            error "Откат конфигурации..."
            rm -f "${dropin_file}"
            cp "${backup}" "${sshd_config}"
            systemctl restart "${ssh_service}"
            exit 1
        fi
    else
        error "Ошибка конфигурации SSH — откат!"
        rm -f "${dropin_file}"
        cp "${backup}" "${sshd_config}"
        exit 1
    fi
}

module_ssh_hardening
