# ⚡ FastNodeUbuntu

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Ubuntu 22](https://img.shields.io/badge/Ubuntu-22.04%20LTS-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com)
[![Ubuntu 24](https://img.shields.io/badge/Ubuntu-24.04%20LTS-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com)
[![Bash](https://img.shields.io/badge/Bash-5.x-4EAA25?logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)

> Модульный bash-скрипт для быстрой настройки и hardening свежего **Ubuntu 22.04 / 24.04 LTS** сервера.  
> Оптимизирован под VPN-ноды (Xray/Remnawave) с поддержкой ядра **XanMod + BBRv3**.

---

## 🚀 Быстрый старт

```bash
curl -fsSL https://raw.githubusercontent.com/begugla0/FastNodeUbuntu/main/run.sh | bash
```

Или вручную через git:

```bash
apt update && apt install -y git
git clone https://github.com/begugla0/FastNodeUbuntu.git
cd FastNodeUbuntu
bash main.sh
```

---

## 📦 Модули

| #   | Файл                    | Описание                                                              |
|-----|-------------------------|-----------------------------------------------------------------------|
| 01  | `01-packet-update.sh`   | Обновление пакетов системы (`apt upgrade + full-upgrade`)             |
| 02  | `02-locale-setup.sh`    | Настройка локали `ru_RU.UTF-8`                                        |
| 03  | `03-time-sync.sh`       | Часовой пояс `Europe/Moscow`, замена `timesyncd` на `chrony`          |
| 04  | `04-ssh-key.sh`         | Интерактивная установка SSH публичного ключа                          |
| 05  | `05-ssh-hardening.sh`   | SSH Hardening: нестандартный порт, отключение пароля, Ubuntu 24 fix   |
| 06  | `06-swap-setup.sh`      | Настройка SWAP с выбором размера: **1 / 2 / 3 / 4 GB**               |
| 07  | `07-ufw-setup.sh`       | UFW Firewall: deny-by-default, rate-limit SSH, открытие портов        |
| 08  | `08-fail2ban-setup.sh`  | Fail2Ban: защита SSH, детект port-scan, backend systemd               |
| 09  | `09-xanmod-v3.sh`       | XanMod ядро + BBRv3 + sysctl оптимизация под RAM **[нужен reboot]**  |

---

## ⚙️ Конфигурация

Все параметры находятся в `config/settings.conf`:

```bash
# ── SSH ───────────────────────────────────────────
SSH_PORT="2225"           # Нестандартный порт SSH
SSH_PERMIT_ROOT="yes"     # Разрешить root-вход
SSH_PASSWORD_AUTH="no"    # Отключить вход по паролю
SSH_PUBLIC_KEY=""         # Ключ (пусто = спросить интерактивно)

# ── SWAP ──────────────────────────────────────────
SWAP_FILE="/swapfile"
SWAP_SIZE="2G"            # Дефолт; модуль 06 спросит интерактивно
SWAP_SWAPPINESS="10"

# ── Время ─────────────────────────────────────────
TIMEZONE="Europe/Moscow"

# ── Локаль ────────────────────────────────────────
LOCALE_LANG="ru_RU.UTF-8"

# ── Порты UFW ──────────────────────────────────────
ALLOWED_PORTS=("80" "443" "8080" "8443")
```

---

## 🖥️ Меню

```
  ╔══════════════════════════════════════════════════╗
  ║   ⚡ FastNodeUbuntu v2.0 — Ubuntu 22 / 24      ║
  ╚══════════════════════════════════════════════════╝

   1) Обновление пакетов системы
   2) Настройка локали (ru_RU.UTF-8)
   3) Синхронизация времени (Europe/Moscow)
   4) Установка SSH ключа
   5) SSH Hardening (порт 2225)
   6) Настройка SWAP (выбор: 1/2/3/4 GB)
   7) Настройка UFW Firewall
   8) Настройка Fail2Ban
   9) XanMod ядро + BBRv3 [требует reboot]

  111) Выполнить ВСЕ модули (1-8 + опционально 9)
    0) Выход
```

---

## 🤖 Автоматический режим

Запуск всех модулей без меню:

```bash
INTERACTIVE_MODE=false bash main.sh
```

---

## 🛡️ Особенности SSH Hardening (Ubuntu 24)

Ubuntu 24.04 использует **socket activation** для SSH (`ssh.socket` на порту 22).  
При смене порта модуль автоматически:

- Отключает и маскирует `ssh.socket`
- Записывает конфиг в `/etc/ssh/sshd_config.d/99-zz-hardening.conf` (drop-in)
- Перезапускает `ssh.service` напрямую
- Просит подтверждение перед закрытием сессии + откатывает при отказе

---

## 🔥 XanMod + BBRv3

Модуль `09-xanmod-v3.sh`:

- Определяет уровень CPU: `x86-64-v2` (SSE4.2) или `x86-64-v3` (AVX2/AVX-512)
- Устанавливает `linux-xanmod-x64v2` или `linux-xanmod-x64v3`
- Настраивает sysctl с 4 профилями под объём RAM (1 GB / 2 GB / 4-8 GB / 8+ GB)
- Включает `BBRv3` + `fq_pie` вместо стандартного `cubic`
- Поднимает лимиты `nofile` до 500 000 для VPN-нод

После установки требуется `reboot`. Проверка:

```bash
uname -r                                       # → linux-xanmod-...
sysctl net.ipv4.tcp_congestion_control         # → bbr
sysctl net.core.default_qdisc                  # → fq_pie
```

---

## 🗂️ Структура проекта

```
FastNodeUbuntu/
├── main.sh                   # Главное меню + запуск модулей
├── run.sh                    # One-liner запуск (curl | bash)
├── config/
│   └── settings.conf         # Все параметры конфигурации
├── modules/
│   ├── 01-packet-update.sh
│   ├── 02-locale-setup.sh
│   ├── 03-time-sync.sh
│   ├── 04-ssh-key.sh
│   ├── 05-ssh-hardening.sh
│   ├── 06-swap-setup.sh
│   ├── 07-ufw-setup.sh
│   ├── 08-fail2ban-setup.sh
│   └── 09-xanmod-v3.sh
└── logs/                     # Логи запусков (auto-created)
```

---

## ➕ Добавление своего модуля

1. Создайте `modules/NN-module-name.sh`
2. Определите функцию `module_name()` с fallback-функциями для standalone-запуска
3. Добавьте вызов `module_name` в конце файла
4. Добавьте пункт в меню `main.sh`

Шаблон:

```bash
#!/bin/bash
if ! declare -f info > /dev/null 2>&1; then
    info()    { echo -e "\033[0;36m ℹ ${*}\033[0m"; }
    success() { echo -e "\033[0;32m ✓ ${*}\033[0m"; }
    warn()    { echo -e "\033[1;33m ⚠ ${*}\033[0m"; }
    error()   { echo -e "\033[0;31m ✗ ${*}\033[0m"; exit 1; }
fi

module_mymodule() {
    info "Запуск моего модуля..."
    # ... логика ...
    success "Готово"
}

module_mymodule
```

---

## 📝 Лицензия

MIT — см. [LICENSE](LICENSE)
