#!/bin/bash
#===============================================================================
# Module 07: Install Required Packages (apt only, no update)
# Ubuntu 24 compatible
# Packages sourced from original 01-system-update.sh REQUIRED_PACKAGES
#===============================================================================

module_packages() {
    info "Установка необходимых пакетов..."

    DEBIAN_FRONTEND=noninteractive apt install -y \
        mc htop screen \
        build-essential python3-pip gnupg2 logrotate \
        sudo tmux ncdu grc glances \
        curl ufw fail2ban \
        chrony locales openssh-server

    success "Все пакеты установлены"
}

module_packages
