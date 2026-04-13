#!/bin/bash
#===============================================================================
# Module 05: SSH Hardening — порт ${SSH_PORT}
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

    # Закомментируем Port в основном конфиге — drop-in должен быть единственным
    sed -i 's/^Port /#Port /' "${sshd_config}"
    # Также закомментируем PasswordAuthentication в основном, чтобы drop-in переопределял
    sed -i 's/^PasswordAuthentication /#PasswordAuthentication /' "${sshd_config}"

    mkdir -p "${dropin_dir}"

    # Проверяем есть ли authorized_keys для root
    local has_keys="no"
    if [[ -s /root/.ssh/authorized_keys ]]; then
        has_keys="yes"
        info "Обнаружен authorized_keys — вход по паролю будет отключён (PasswordAuthentication no)"
    else
        warn "Нет authorized_keys — PasswordAuthentication останется yes (сначала добавьте ключ через модуль 4)"
    fi

    local password_auth="yes"
    [[ "${has_keys}" == "yes" ]] && password_auth="no"

    cat > "${dropin_file}" <<EOF
# FastNodeUbuntu — SSH Hardening
# Ubuntu 24 drop-in config
Port ${SSH_PORT}
PermitRootLogin ${SSH_PERMIT_ROOT:-yes}
PermitEmptyPasswords no
PasswordAuthentication ${password_auth}
PubkeyAuthentication yes
AuthenticationMethods publickey
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
X11Forwarding no
EOF

    info "Hardening конфиг → ${dropin_file}"
    info "Port: ${SSH_PORT} | PasswordAuth: ${password_auth} | PermitRoot: ${SSH_PERMIT_ROOT:-yes}"

    if ! sshd -t -f "${sshd_config}"; then
        echo -e "\033[0;31m[Ошибка] Неверная конфигурация SSH — откат!\033[0m"
        rm -f "${dropin_file}"
        cp "${backup}" "${sshd_config}"
        return 1
    fi

    success "SSH конфигурация валидна"

    # Автодетект сервиса: Ubuntu 24 = ssh.service, старые = sshd.service
    local ssh_service="sshd"
    systemctl list-units --type=service 2>/dev/null | grep -q '\.service' \
        && systemctl list-units --type=service 2>/dev/null | grep -q 'ssh\.service' \
        && ssh_service="ssh"

    systemctl restart "${ssh_service}"
    success "SSH перезапущен на порту ${SSH_PORT} (${ssh_service})"

    echo ""
    warn "НЕ ЗАКРЫВАЙТЕ СЕССИЮ! Проверьте подключение к порту ${SSH_PORT}"
    warn "Команда: ssh -p ${SSH_PORT} root@<IP>"
    printf "Подтвердите что подключение работает (yes/no): "
    read -r confirm </dev/tty

    if [[ "${confirm}" != "yes" ]]; then
        warn "Откат конфигурации..."
        rm -f "${dropin_file}"
        cp "${backup}" "${sshd_config}"
        # Восстанавливаем оригинальные Port и PasswordAuthentication в sshd_config
        systemctl restart "${ssh_service}"
        warn "Конфигурация SSH откачена на порт 22"
        return 1
    fi

    success "SSH hardening применён. Порт: ${SSH_PORT}, пароль: ${password_auth}"
}

module_ssh_hardening
