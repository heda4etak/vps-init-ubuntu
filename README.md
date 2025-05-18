# VPS Init Ubuntu 24.04

Автоматический скрипт для первичной настройки VPS на Ubuntu 24.04.

---

## Что делает скрипт

1. Позволяет выбрать порт для SSH.
2. Создает SSH-ключ для авторизации.
3. Отключает вход по паролю, оставляя только вход по ключу.
4. Настраивает SSHD.
5. Устанавливает и настраивает UFW (открывает выбранный SSH порт, HTTP и HTTPS).

---

## Быстрый запуск скрипта

Скопируйте и вставьте эту команду на вашем VPS для автоматической настройки:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/heda4etak/vps-init-ubuntu/main/setup_vps.sh)
```
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/heda4etak/vps-init-ubuntu/main/vps-setup.sh)

