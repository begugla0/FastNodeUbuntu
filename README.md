# ⚡ FastNodeUbuntu

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04%20LTS-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com)
[![Bash](https://img.shields.io/badge/Bash-5.x-4EAA25?logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![GitHub stars](https://img.shields.io/github/stars/begugla0/FastNodeUbuntu?style=flat)](https://github.com/begugla0/FastNodeUbuntu/stargazers)

> Модульный bash-скрипт для быстрой настройки и hardening свежего **Ubuntu 24.04 LTS** сервера.

---

## 🚀 Быстрый старт

```bash
curl -fsSL https://raw.githubusercontent.com/begugla0/FastNodeUbuntu/main/run.sh | bash
```

Или через git:

```bash
apt update && apt install -y git
git clone https://github.com/begugla0/FastNodeUbuntu.git
cd FastNodeUbuntu
bash main.sh
```

---

## 📦 Модули

| # | Модуль | Описание |
|:-:|--------|----------|
| **2** | `02-locale-setup.sh` | Настройка локали `ru_RU.UTF-8` |
| **3** | `03-time-sync.sh` | Часовой пояс `Europe/Moscow`, замена `systemd-timesyncd` на `chrony` |
| **4** | `04-ssh-key.sh` | Интерактивное добавление SSH публичного ключа |
| **5** | `05-ssh-hardening.sh` | Hardening SSH: порт `2225`, автоотключение пароля при наличии ключа |
| **6** | `06-swap-setup.sh` | SWAP `2GB`, `swappiness=80`, поддержка btrfs |
| **7** | `07-packages.sh` | Установка базовых пакетов (`htop`, `mc`, `fail2ban`, `ufw` и др.) |

---

## ⚙️ Конфигурация

Все параметры находятся в `config/settings.conf`:

```bash
# SSH
SSH_PORT="2225"           # порт SSH
SSH_PERMIT_ROOT="yes"     # вход под root
SSH_PUBLIC_KEY=""         # оставь пустым — ключ запросится интерактивно

# SWAP
SWAP_SIZE="2G"            # размер swap-файла
SWAP_SWAPPINESS="80"      # aggressiveness использования swap

# Время
TIMEZONE="Europe/Moscow"

# Локаль
LOCALE_LANG="ru_RU.UTF-8"
```

---

## 🤖 Автоматический режим

Запуск всех модулей без меню и запросов:

```bash
INTERACTIVE_MODE=false bash main.sh
```

---

## 🗂️ Структура проекта

```
FastNodeUbuntu/
├── main.sh              # главное меню
├── run.sh               # one-liner запуск
├── config/
│   └── settings.conf    # все параметры
├── modules/
│   ├── 02-locale-setup.sh
│   ├── 03-time-sync.sh
│   ├── 04-ssh-key.sh
│   ├── 05-ssh-hardening.sh
│   ├── 06-swap-setup.sh
│   └── 07-packages.sh
└── logs/                # логи запусков
```

---

## ➕ Добавление своего модуля

1. Создайте `modules/NN-module-name.sh` со функцией `module_<name>()`
2. Добавьте пункт в меню `main.sh`
3. Вызовите `module_<name>` в конце файла

---

## 🛡️ Что делает hardening SSH

- Меняет порт с `22` на `2225`
- Отключает `ssh.socket` (socket activation Ubuntu 24)
- Автоматически отключает вход по паролю при наличии SSH ключа
- Использует drop-in `99-zz-hardening.conf` (загружается последним)
- Просит подтверждение перед закрытием сессии, откат при отказе

---

## 📝 Лицензия

MIT — см. [LICENSE](LICENSE)
