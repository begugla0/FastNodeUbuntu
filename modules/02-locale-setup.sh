#!/bin/bash
#===============================================================================
# Module 02: Locale Setup — ru_RU.UTF-8
# Ubuntu 24 compatible
#===============================================================================

module_locale_setup() {
    info "Настройка локали ru_RU.UTF-8..."

    if ! dpkg -l locales &>/dev/null; then
        DEBIAN_FRONTEND=noninteractive apt install -y locales
    fi

    sed -i 's/# ru_RU.UTF-8 UTF-8/ru_RU.UTF-8 UTF-8/' /etc/locale.gen
    locale-gen ru_RU.UTF-8

    localectl set-locale \
        LANG="ru_RU.UTF-8" \
        LANGUAGE="ru_RU:ru" \
        LC_ALL="ru_RU.UTF-8"

    cat > /etc/default/locale <<EOF
LANG=ru_RU.UTF-8
LANGUAGE=ru_RU:ru
LC_ALL=ru_RU.UTF-8
EOF

    export LANG="ru_RU.UTF-8"
    export LANGUAGE="ru_RU:ru"
    export LC_ALL="ru_RU.UTF-8"

    success "Локаль установлена: ru_RU.UTF-8"
}

module_locale_setup
