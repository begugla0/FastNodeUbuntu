#!/bin/bash
# ==============================================================================
# Module 09: Установка ядра XanMod + BBRv3 + оптимизация сети
# Поддержка: Ubuntu 22.04 LTS (jammy) / Ubuntu 24.04 LTS (noble)
#
# Что делает:
#   1. Определяет уровень CPU (x86-64-v2/v3)
#   2. Устанавливает ядро linux-xanmod-x64v{2,3}
#   3. Настраивает BBRv3 + fq_pie через sysctl
#   4. Устанавливает лимиты файловых дескрипторов (ulimit)
# ==============================================================================

if ! declare -f info > /dev/null 2>&1; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'
    info()    { echo -e "${CYAN} ℹ ${*}${NC}"; }
    warn()    { echo -e "${YELLOW} ⚠ ${*}${NC}"; }
    success() { echo -e "${GREEN} ✓ ${*}${NC}"; }
    error()   { echo -e "${RED} ✗ ${*}${NC}"; exit 1; }
fi

module_xanmod_setup() {
    echo ""
    echo -e "${CYAN}  ██╗  ██╗ █████╗ ███╗   ██╗███╗   ███╗ ██████╗ ██████╗ ${NC}"
    echo -e "${CYAN}  ╚██╗██╔╝██╔══██╗████╗  ██║████╗ ████║██╔═══██╗██╔══██╗${NC}"
    echo -e "${CYAN}   ╚███╔╝ ███████║██╔██╗ ██║██╔████╔██║██║   ██║██║  ██║${NC}"
    echo -e "${CYAN}   ██╔██╗ ██╔══██║██║╚██╗██║██║╚██╔╝██║██║   ██║██║  ██║${NC}"
    echo -e "${CYAN}  ██╔╝ ██╗██║  ██║██║ ╚████║██║ ╚═╝ ██║╚██████╔╝██████╔╝${NC}"
    echo -e "${CYAN}  ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝ ╚═════╝${NC}"
    echo ""
    echo -e "  ${BOLD}XanMod Kernel + BBRv3 — Оптимизация для VPN-нод${NC}"
    echo ""

    export DEBIAN_FRONTEND=noninteractive

    # ── ШАГ 1: Проверки ──────────────────────────────────────────────────────

    info "Проверка виртуализации..."
    if command -v systemd-detect-virt &>/dev/null; then
        local virt
        virt=$(systemd-detect-virt)
        info "Тип виртуализации: ${virt}"
        if [[ "${virt}" == "lxc" || "${virt}" == "openvz" || "${virt}" == "docker" ]]; then
            error "Виртуализация ${virt} не поддерживает замену ядра! Прерываемся."
        fi
    fi

    info "Проверка ОС..."
    local distro_id="" codename=""
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        distro_id="${ID:-unknown}"
        codename="${VERSION_CODENAME:-$(lsb_release -sc 2>/dev/null || echo "unknown")}"
        info "Дистрибутив: ${PRETTY_NAME} (${codename})"
    fi

    if [[ "${distro_id}" != "ubuntu" ]]; then
        warn "Обнаружен не Ubuntu (${distro_id}). XanMod работает на Debian/Ubuntu."
        printf " Продолжить? (yes/no): "
        local cont
        read -r cont </dev/tty
        [[ "${cont}" != "yes" ]] && return 1
    fi

    info "Ядро сейчас: $(uname -r) | Архитектура: $(uname -m)"

    # ── ШАГ 2: Анализ CPU ──────────────────────────────────────────────────

    info "Определяем уровень CPU..."
    local cpu_model cpu_flags cpu_level level_desc
    cpu_model=$(grep -m1 'model name' /proc/cpuinfo | cut -d':' -f2 | xargs)
    local cpu_cores
    cpu_cores=$(nproc)
    cpu_flags=$(grep -m1 '^flags' /proc/cpuinfo)

    info "CPU: ${cpu_model} (${cpu_cores} ядер)"

    # ВАЖНО: XanMod публикует только v1–v3 пакеты, v4 не существует
    if echo "${cpu_flags}" | grep -q 'avx512'; then
        cpu_level=3
        level_desc="AVX-512 → используем v3 (v4 пакетов нет в XanMod)"
    elif echo "${cpu_flags}" | grep -q 'avx2'; then
        cpu_level=3
        level_desc="AVX2 (современный процессор)"
    elif echo "${cpu_flags}" | grep -q 'sse4_2'; then
        cpu_level=2
        level_desc="SSE4.2 (базовый уровень)"
    else
        cpu_level=2
        level_desc="x86-64 базовый → используем v2 (fallback)"
    fi

    echo -n "  Флаги: "
    for flag in sse4_2 avx avx2 avx512f aes; do
        if echo "${cpu_flags}" | grep -q "${flag}"; then
            echo -ne "${GREEN}[${flag}]${NC} "
        else
            echo -ne "${RED}[${flag}]${NC} "
        fi
    done
    echo ""
    success "CPU Level: x86-64-v${cpu_level} — ${level_desc}"

    # ── ШАГ 3: Установка XanMod ────────────────────────────────────────────

    info "Подготовка репозитория XanMod..."

    # Удаляем старые ключи
    rm -f /usr/share/keyrings/xanmod-archive-keyring.gpg 2>/dev/null
    rm -f /etc/apt/keyrings/xanmod-archive-keyring.gpg  2>/dev/null

    apt-get update -qq
    apt-get install -y wget gnupg2 ca-certificates lsb-release

    # Добавляем GPG ключ
    mkdir -p /etc/apt/keyrings
    info "Скачиваем GPG ключ XanMod..."
    wget -qO - https://dl.xanmod.org/archive.key | \
        gpg --dearmor -vo /etc/apt/keyrings/xanmod-archive-keyring.gpg --yes
    success "GPG ключ добавлен"

    # Добавляем репозиторий
    echo "deb [signed-by=/etc/apt/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org ${codename} main" \
        | tee /etc/apt/sources.list.d/xanmod-release.list
    success "Репозиторий добавлен: codename=${codename}"

    # Обновляем списки
    apt-get update

    # Определяем и устанавливаем пакет
    local kernel_pkg="linux-xanmod-x64v${cpu_level}"

    info "Проверка доступности пакета: ${kernel_pkg}..."
    if ! apt-cache show "${kernel_pkg}" &>/dev/null; then
        warn "Пакет ${kernel_pkg} не найден!"
        if [[ "${cpu_level}" -eq 3 ]]; then
            kernel_pkg="linux-xanmod-x64v2"
            info "Пробуем fallback: ${kernel_pkg}"
            if ! apt-cache show "${kernel_pkg}" &>/dev/null; then
                error "Пакет ${kernel_pkg} тоже не найден. Доступные: $(apt-cache search linux-xanmod | head -5)"
            fi
        else
            error "Пакет XanMod не найден. Доступные: $(apt-cache search linux-xanmod | head -5)"
        fi
    fi

    info "Устанавливаем ядро: ${kernel_pkg}..."
    echo ""
    echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
    apt-get install -y "${kernel_pkg}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
    echo ""
    success "Ядро ${kernel_pkg} установлено"

    # ── ШАГ 4: Настройка сетевого стека (sysctl) ───────────────────────────

    info "Настройка сетевого стека (sysctl)..."

    local total_mem_mb
    total_mem_mb=$(free -m | awk '/^Mem:/{print $2}')
    local total_mem_gb
    total_mem_gb=$(echo "scale=1; ${total_mem_mb} / 1024" | bc)

    info "RAM: ${total_mem_mb} MB (~${total_mem_gb} GB)"

    local profile_name
    if [[ ${total_mem_mb} -le 1200 ]]; then
        profile_name="SURVIVAL (1 GB)"
    elif [[ ${total_mem_mb} -le 2500 ]]; then
        profile_name="BALANCED (2 GB)"
    elif [[ ${total_mem_mb} -le 8500 ]]; then
        profile_name="PERFORMANCE (4-8 GB)"
    else
        profile_name="ULTRA 10G (8+ GB)"
    fi

    info "Профиль памяти: ${profile_name}"

    local sysctl_file="/etc/sysctl.d/99-xanmod-node.conf"

    cat > "${sysctl_file}" <<EOF
# ==============================================================================
# FastNodeUbuntu: XanMod / VPN Node Tuning
# Профиль: ${profile_name} | RAM: ${total_mem_mb} MB
# Сгенерировано: $(date)
# ==============================================================================

# ── BBRv3 Congestion Control ────────────────────────────────────────────────
net.core.default_qdisc            = fq_pie
net.ipv4.tcp_congestion_control   = bbr

# ── Security & IP Forwarding ────────────────────────────────────────────────
net.ipv4.ip_forward               = 1
net.ipv6.conf.all.forwarding       = 1
net.ipv4.tcp_syncookies           = 1
net.ipv4.tcp_rfc1337              = 1
net.ipv4.conf.all.accept_redirects       = 0
net.ipv4.conf.default.accept_redirects   = 0
net.ipv4.conf.all.send_redirects         = 0
net.ipv4.icmp_echo_ignore_broadcasts     = 1

# ── TCP Keepalives (мобильные клиенты) ─────────────────────────────────────
net.ipv4.tcp_keepalive_time   = 300
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl  = 15

# ── TCP Fast Open ───────────────────────────────────────────────────────────
net.ipv4.tcp_fastopen = 3
EOF

    # Профильные настройки буферов по RAM
    if [[ ${total_mem_mb} -le 1200 ]]; then
        cat >> "${sysctl_file}" <<EOF

# ── TIER 1: 1 GB RAM (Survival) ────────────────────────────────────────────
net.core.rmem_max            = 2097152
net.core.wmem_max            = 2097152
net.ipv4.tcp_rmem            = 4096 87380 2097152
net.ipv4.tcp_wmem            = 4096 16384 2097152
vm.vfs_cache_pressure        = 150
vm.swappiness                = 20
vm.min_free_kbytes           = 65536
EOF

    elif [[ ${total_mem_mb} -le 2500 ]]; then
        cat >> "${sysctl_file}" <<EOF

# ── TIER 2: 2 GB RAM (Balanced) ────────────────────────────────────────────
net.core.rmem_max            = 8388608
net.core.wmem_max            = 8388608
net.ipv4.tcp_rmem            = 4096 87380 8388608
net.ipv4.tcp_wmem            = 4096 32768 8388608
vm.vfs_cache_pressure        = 100
vm.swappiness                = 10
vm.min_free_kbytes           = 65536
EOF

    elif [[ ${total_mem_mb} -le 8500 ]]; then
        cat >> "${sysctl_file}" <<EOF

# ── TIER 3: 4-8 GB RAM (Performance) ──────────────────────────────────────
net.core.rmem_max            = 16777216
net.core.wmem_max            = 16777216
net.ipv4.tcp_rmem            = 4096 87380 16777216
net.ipv4.tcp_wmem            = 4096 65536 16777216
net.core.netdev_max_backlog  = 16384
vm.swappiness                = 10
EOF

    else
        cat >> "${sysctl_file}" <<EOF

# ── TIER 4: 8+ GB RAM (Ultra 10G) ──────────────────────────────────────────
net.core.rmem_max            = 33554432
net.core.wmem_max            = 33554432
net.ipv4.tcp_rmem            = 4096 131072 33554432
net.ipv4.tcp_wmem            = 4096 87380  33554432
net.core.netdev_max_backlog  = 32768
vm.swappiness                = 5
EOF
    fi

    success "sysctl конфиг: ${sysctl_file}"

    # ── ШАГ 5: Лимиты файловых дескрипторов ───────────────────────────────

    info "Настройка лимитов файловых дескрипторов..."

    local limit_count
    if [[ ${total_mem_mb} -le 1200 ]]; then
        limit_count=65535
    else
        limit_count=500000
    fi

    cat > /etc/security/limits.d/99-xanmod-limits.conf <<EOF
# FastNodeUbuntu: File descriptor limits для VPN-ноды
* soft nofile ${limit_count}
* hard nofile ${limit_count}
root soft nofile ${limit_count}
root hard nofile ${limit_count}
EOF

    mkdir -p /etc/systemd/system.conf.d/
    cat > /etc/systemd/system.conf.d/99-xanmod-limits.conf <<EOF
[Manager]
DefaultLimitNOFILE=${limit_count}
EOF

    systemctl daemon-reexec
    success "Лимит nofile: ${limit_count}"

    # ── Итоговый отчёт ─────────────────────────────────────────────────────

    echo ""
    echo -e "${GREEN}  ╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}  ║              ✅ XanMod установлен!                 ║${NC}"
    echo -e "${GREEN}  ╚════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${BOLD}Ядро:${NC}        ${GREEN}${kernel_pkg}${NC}"
    echo -e "  ${BOLD}CPU Level:${NC}   ${GREEN}x86-64-v${cpu_level}${NC}"
    echo -e "  ${BOLD}Профиль RAM:${NC} ${GREEN}${profile_name}${NC}"
    echo -e "  ${BOLD}TCP:${NC}         ${GREEN}BBRv3 + fq_pie${NC}"
    echo -e "  ${BOLD}nofile:${NC}      ${GREEN}${limit_count}${NC}"
    echo ""
    echo -e "  ${BOLD}Файлы:${NC}"
    echo -e "  ├─ ${CYAN}/etc/sysctl.d/99-xanmod-node.conf${NC}"
    echo -e "  ├─ ${CYAN}/etc/security/limits.d/99-xanmod-limits.conf${NC}"
    echo -e "  └─ ${CYAN}/etc/systemd/system.conf.d/99-xanmod-limits.conf${NC}"
    echo ""
    echo -e "  ${YELLOW}⚠ После перезагрузки проверьте:${NC}"
    echo -e "  ${CYAN}uname -r${NC}                                  # должно быть xanmod"
    echo -e "  ${CYAN}sysctl net.ipv4.tcp_congestion_control${NC}    # должно быть bbr"
    echo ""

    printf "  Перезагрузить сервер сейчас? (y/n): "
    local reboot_now
    read -r reboot_now </dev/tty
    if [[ "${reboot_now}" =~ ^[Yy]$ ]]; then
        echo -e "  ${GREEN}Перезагрузка через 3 секунды...${NC}"
        sleep 3
        reboot
    else
        warn "Не забудьте выполнить: sudo reboot"
    fi
}

module_xanmod_setup
