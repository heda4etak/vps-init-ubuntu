#!/bin/bash

# VPS Initial Setup Script for Ubuntu 24.04
# Version 1.3.0

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
BOLD="\033[1m"
RESET="\033[0m"

START_TIME=$(date +%s)

ensure_sudo() {
  if ! sudo -v; then
    echo -e "${RED}Требуются права суперпользователя (sudo). Запустите скрипт с sudo или настройте sudoers.${RESET}"
    exit 1
  fi
}

print_banner() {
  echo -e "\033c"
  cat << "EOF"

██╗   ██╗██████╗ ███████╗      ███████╗███████╗████████╗██╗   ██╗██████╗ 
██║   ██║██╔══██╗██╔════╝      ██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗
██║   ██║██████╔╝███████╗█████╗███████╗█████╗     ██║   ██║   ██║██████╔╝
╚██╗ ██╔╝██╔═══╝ ╚════██║╚════╝╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝ 
 ╚████╔╝ ██║     ███████║      ███████║███████╗   ██║   ╚██████╔╝██║     
  ╚═══╝  ╚═╝     ╚══════╝      ╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝     

EOF
  echo -e "${CYAN}${BOLD}          VPS Initial Setup Script for Ubuntu 24.04${RESET}"
  echo -e "${YELLOW}${BOLD}                      by heda4etak - 2025${RESET}\n"
}

main() {
  print_banner

  # Ожидание подтверждения перед началом
  read -p "⚠️  Нажмите Enter для начала установки или Ctrl+C для отмены..."

  ensure_sudo

  echo -e "${GREEN}Обновление пакетов...${RESET}"
  sudo apt update && sudo apt upgrade -y
  sleep 1
  print_banner

  while true; do
    read -rp "Введите новый порт для SSH (например, 2222): " SSH_PORT
    if ! [[ "$SSH_PORT" =~ ^[0-9]+$ ]] || [ "$SSH_PORT" -lt 1 ] || [ "$SSH_PORT" -gt 65535 ]; then
      echo -e "${YELLOW}Неверный порт. Введите число от 1 до 65535.${RESET}"
      continue
    fi

    if sudo ss -tln | grep -q ":${SSH_PORT} "; then
      echo -e "${YELLOW}Порт ${SSH_PORT} уже занят. Попробуйте другой.${RESET}"
      continue
    fi

    break
  done

  read -rp "Введите имя SSH-ключа (без пути, например: id_rsa_myvps): " KEY_NAME
  if [[ -z "$KEY_NAME" ]]; then
    echo -e "${YELLOW}Имя ключа не может быть пустым.${RESET}"
    exit 1
  fi

  SSH_DIR="$HOME/.ssh"
  KEY_FILE="$SSH_DIR/$KEY_NAME"

  mkdir -p "$SSH_DIR" && chmod 700 "$SSH_DIR"

  if [ -f "$KEY_FILE" ]; then
    echo -e "${YELLOW}SSH ключ уже существует: $KEY_FILE${RESET}"
  else
    echo -e "${GREEN}Генерация SSH ключа...${RESET}"
    if ! ssh-keygen -t rsa -b 4096 -N "" -f "$KEY_FILE"; then
      echo -e "${RED}Ошибка генерации ключа.${RESET}"
      rm -f "$KEY_FILE" "$KEY_FILE.pub"
      exit 1
    fi
  fi

  PUB_KEY_CONTENT=$(cat "$KEY_FILE.pub")
  sudo mkdir -p /root/.ssh
  sudo touch /root/.ssh/authorized_keys
  sudo chmod 600 /root/.ssh/authorized_keys

  if ! sudo grep -qxF "$PUB_KEY_CONTENT" /root/.ssh/authorized_keys; then
    echo "$PUB_KEY_CONTENT" | sudo tee -a /root/.ssh/authorized_keys > /dev/null
  fi

  echo -e "${GREEN}Настройка SSH...${RESET}"
  sudo sed -i "/^Port /d" /etc/ssh/sshd_config
  echo "Port $SSH_PORT" | sudo tee -a /etc/ssh/sshd_config > /dev/null

  sudo sed -i "/^PasswordAuthentication /d" /etc/ssh/sshd_config
  echo "PasswordAuthentication no" | sudo tee -a /etc/ssh/sshd_config > /dev/null

  sudo sed -i "/^PubkeyAuthentication /d" /etc/ssh/sshd_config
  echo "PubkeyAuthentication yes" | sudo tee -a /etc/ssh/sshd_config > /dev/null

  sudo sed -i "/^PermitRootLogin /d" /etc/ssh/sshd_config
  echo "PermitRootLogin prohibit-password" | sudo tee -a /etc/ssh/sshd_config > /dev/null

  echo -e "${GREEN}Установка и настройка UFW...${RESET}"
  if ! command -v ufw &> /dev/null; then
    sudo apt install -y ufw
  fi

  sudo ufw --force reset
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  sudo ufw allow "$SSH_PORT"/tcp
  sudo ufw allow 80/tcp
  sudo ufw allow 443/tcp

  if ! sudo ufw status | grep -q "Status: active"; then
    echo -e "${YELLOW}⚠️  Включение UFW...${RESET}"
    sudo ufw --force enable
  fi

  END_TIME=$(date +%s)
  RUNTIME=$((END_TIME - START_TIME))

  echo -e "\n -✅ ${GREEN}Настройка завершена за ${RUNTIME} секунд.${RESET}"
  echo -e " - 🔑 ${YELLOW}SSH приватный ключ:${RESET} ${GREEN}$KEY_FILE${RESET}"
  echo -e " - 📂 ${YELLOW}Используйте:${RESET} ${CYAN}ssh -i $KEY_FILE root@<IP> -p $SSH_PORT${RESET}"
  echo -e " - ⚠️ ${RED}Рекомендуется перезагрузить VPS.${RESET}\n"

  read -p "$(echo -e \"${YELLOW}Нажмите Enter для перезапуска системы или Ctrl+C для ручной перезагрузки позже.${RESET}\\n\")"
  sudo reboot
}

main "$@"
