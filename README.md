# FastNodeUbuntu

**Ubuntu 24 LTS Server Automation Script** — модульная настройка и hardening.

## Быстрый старт

```bash
apt update && apt install -y git
git clone https://github.com/begugla0/FastNodeUbuntu.git
cd FastNodeUbuntu
sudo ./main.sh
```

Или одной командой:

```bash
curl -fsSL https://raw.githubusercontent.com/begugla0/FastNodeUbuntu/main/run.sh | bash
```

## Автоматический режим (все модули)

```bash
INTERACTIVE_MODE=false sudo ./main.sh
```

## Модули

| # | Модуль | Описание |
|---|--------|----------|
| 02 | `02-locale-setup.sh` | Локаль ru_RU.UTF-8 |
| 03 | `03-time-sync.sh` | Время МСК (Europe/Moscow) + chrony |
| 04 | `04-ssh-key.sh` | Добавление SSH публичного ключа |
| 05 | `05-ssh-hardening.sh` | Hardening SSH, порт 2225 |
| 06 | `06-swap-setup.sh` | SWAP 2GB, swappiness=80 |
| 07 | `07-packages.sh` | Установка необходимых пакетов |

## Конфигурация

Все параметры в `config/settings.conf`.

## Добавление модуля

1. Создайте `modules/NN-module-name.sh`
2. Добавьте функцию `module_<name>()`
3. Вызовите функцию в конце файла
4. Добавьте пункт меню в `main.sh`
