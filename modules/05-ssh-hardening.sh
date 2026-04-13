#!/bin/bash
#===============================================================================
# Module 05: SSH Hardening — порт ${SSH_PORT}
# Ubuntu 24 compatible (drop-in /etc/ssh/sshd_config.d/)
# NOTE: Ubuntu 24 использует socket activation (ssh.socket),
#       который держит порт 22 независимо от sshd_config.
#       Необходимо отключить сокет и перезапустить ssh.service напрямую.
#===============================================================================

module_ssh_hardening() {
    info "Hardening SSH (порт ${SSH_PORT})..."

    local sshd_config="/etc/ssh/sshd_config"
    local dropin_dir="/etc/ssh/sshd_config.d"
    local dropin_file="${dropin_dir}/99-hardening.conf"
    local backup="${sshd_config}.backup.$(date +%Y%m%d_%H%M%S)"

    cp "${sshd_config}" "${backup}"
    info "Резервная копия: ${backup}"

    # Закомментируем Port и PasswordAuthentication в основном конфиге
    sed -i 's/^Port /#Port /' "${sshd_config}"
    sed -i 's/^PasswordAuthentication /#PasswordAuthentication /' "${sshd_config}"

    mkdir -p "${dropin_dir}"

    # Автоопределение PasswordAuthentication
    local password_auth="yes"
    if [[ -s /root/.ssh/authorized_keys ]]; then
        password_auth="no"
        info "Обнаружен authorized_keys — вход по паролю будет отключён (PasswordAuthentication no)"
    else
        warn "Нет authorized_keys — PasswordAuthentication останется yes"
    fi

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
        echo -e "\033[0;31mОшибка конфигурации SSH — откат!\033[0m"
        rm -f "${dropin_file}"
        cp "${backup}" "${sshd_config}"
        return 1
    fi
    success "SSH конфигурация валидна"

    # Отключаем ssh.socket (Ubuntu 24 socket activation держит порт 22 самостоятельно)
    if systemctl is-active --quiet ssh.socket 2>/dev/null; then
        info "Отключение ssh.socket (socket activation)..."
        systemctl stop ssh.socket
        systemctl disable ssh.socket
    fi

    systemctl restart ssh
    success "SSH перезапущен на порту ${SSH_PORT}"

    echo ""
    warn "НЕ ЗАКРЫВАЙТЕ СЕССИЮ! Проверьте подключение к порту ${SSH_PORT}"
    warn "Команда: ssh -p ${SSH_PORT} root@<IP>"
    printf "Подтвердите что подключение работает (yes/no): "
    read -r confirm </dev/tty

    if [[ "${confirm}" != "yes" ]]; then
        warn "Откат конфигурации..."
        rm -f "${dropin_file}"
        cp "${backup}" "${sshd_config}"
        systemctl enable ssh.socket 2>/dev/null || true
        systemctl start ssh.socket 2>/dev/null || true
        systemctl restart ssh
        warn "Конфигурация SSH откачена на порт 22"
        return 1
    fi

    success "SSH hardening применён. Порт: ${SSH_PORT}, пароль: ${password_auth}"
}

module_ssh_hardening
