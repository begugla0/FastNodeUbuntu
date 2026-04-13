#!/bin/bash
#===============================================================================
# Module 02: Locale Setup — ru_RU.UTF-8
# Ubuntu 24 compatible
# NOTE: localectl set-locale отклоняет LC_ALL через D-Bus в systemd 255+
#       Используем только LANG через localectl, остальное — напрямую в файл
#===============================================================================

module_locale_setup() {
    info "Настройка локали ru_RU.UTF-8..."

    # Установка пакета locales если нет
    if ! dpkg -s locales &>/dev/null 2>&1; then
        info "Устанавливаем пакет locales..."
        DEBIAN_FRONTEND=noninteractive apt-get install -y locales
    fi

    # Включаем ru_RU.UTF-8 в locale.gen
    if ! grep -q "^ru_RU.UTF-8 UTF-8" /etc/locale.gen 2>/dev/null; then
        sed -i 's/^# *ru_RU.UTF-8 UTF-8/ru_RU.UTF-8 UTF-8/' /etc/locale.gen
        # Если строки вообще нет — добавляем
        grep -q "^ru_RU.UTF-8 UTF-8" /etc/locale.gen || echo "ru_RU.UTF-8 UTF-8" >> /etc/locale.gen
    fi

    locale-gen ru_RU.UTF-8

    # localectl принимает только LANG (не LC_ALL) начиная с systemd 255
    localectl set-locale LANG=ru_RU.UTF-8 || warn "localectl set-locale не сработал, продолжаем..."

    # Пишем /etc/default/locale напрямую — надёжный способ для Ubuntu 24
    cat > /etc/default/locale <<EOF
LANG=ru_RU.UTF-8
LANGUAGE=ru_RU:ru
LC_ALL=ru_RU.UTF-8
EOF

    # Применяем для текущей сессии
    export LANG="ru_RU.UTF-8"
    export LANGUAGE="ru_RU:ru"
    export LC_ALL="ru_RU.UTF-8"

    info "Проверка:"
    locale | grep -E "LANG|LC_ALL" || true

    success "Локаль установлена: ru_RU.UTF-8"
}

module_locale_setup
