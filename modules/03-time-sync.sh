#!/bin/bash
#===============================================================================
# Module 03: Time Synchronization — Europe/Moscow (МСК)
# Ubuntu 24 compatible
#===============================================================================

module_time_sync() {
    info "Настройка синхронизации времени (МСК)..."

    timedatectl set-timezone "Europe/Moscow"

    # Ubuntu 24 использует systemd-timesyncd — отключаем перед chrony
    if systemctl is-active --quiet systemd-timesyncd 2>/dev/null; then
        info "Отключение systemd-timesyncd..."
        systemctl stop systemd-timesyncd
        systemctl disable systemd-timesyncd
    fi

    DEBIAN_FRONTEND=noninteractive apt install -y chrony

    systemctl enable chrony
    systemctl restart chrony

    chronyc -a makestep

    timedatectl set-ntp true

    info "Текущее время: $(date)"
    info "Часовой пояс:  $(timedatectl | grep 'Time zone')"
    info "Статус NTP:    $(timedatectl | grep 'NTP service')"

    success "Время синхронизировано: МСК (Europe/Moscow)"
}

module_time_sync
