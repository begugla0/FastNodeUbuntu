#!/bin/bash
#===============================================================================
# Module 03: Time Synchronization — Europe/Moscow (МСК)
# Ubuntu 24 compatible
# NOTE: timedatectl set-ntp работает только с systemd-timesyncd.
#       Мы используем chrony — NTP управляется независимо.
#===============================================================================

module_time_sync() {
    info "Настройка синхронизации времени (МСК)..."

    timedatectl set-timezone "Europe/Moscow"

    # Отключаем systemd-timesyncd (конфликтует с chrony)
    if systemctl is-active --quiet systemd-timesyncd 2>/dev/null; then
        info "Отключение systemd-timesyncd..."
        systemctl stop systemd-timesyncd || true
        systemctl disable systemd-timesyncd || true
    fi

    DEBIAN_FRONTEND=noninteractive apt-get install -y chrony

    systemctl enable chrony
    systemctl restart chrony

    # Подождём пока chrony поднялся
    sleep 2
    chronyc -a makestep 2>/dev/null || warn "makestep: сервер ещё не готов, NTP синхронизация выполнится в фоне"

    info "Текущее время: $(date)"
    info "Часовой пояс:  $(timedatectl | grep 'Time zone')"

    # Проверка статуса chrony
    if systemctl is-active --quiet chrony; then
        info "chrony: $(systemctl is-active chrony) (используется вместо timedatectl NTP)"
        chronyc tracking 2>/dev/null | grep -E "Reference|Stratum|RMS" || true
    else
        warn "chrony не запущен!"
    fi

    success "Время синхронизировано: МСК (Europe/Moscow)"
}

module_time_sync
