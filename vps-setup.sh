#!/bin/bash

# VPS Initial Setup Script for Ubuntu 24.04
# Version 1.1.0

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
BOLD="\033[1m"
RESET="\033[0m"

ensure_sudo() {
  if ! sudo -v; then
    echo -e "${RED}Требуются права суперпользователя (sudo). Запустите скрипт с sudo или настройте sudoers.${RESET}"
    exit 1
  fi
}

print_banner() {
  clear
  cat << "EOF"

██╗   ██╗██████╗ ███████╗      ███████╗███████╗████████╗██╗   ██╗██████╗ 
██║   ██║██╔══██╗██╔════╝      ██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗
██║   ██║██████╔╝███████╗█████╗███████╗█████╗     ██║   ██║   ██║██████╔╝
╚██╗ ██╔╝██╔═══╝ ╚════██║╚════╝╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝ 
 ╚████╔╝ ██║     ███████║      ███████║███████╗   ██║   ╚██████╔╝██║     
  ╚═══╝  ╚═╝     ╚══════╝      ╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝     

EOF
  echo -e "${CYAN}${BOLD}          VPS Initial Setup Script for Ubuntu 24.04${RESET}"
  echo -e "${YELLOW}${BOLD}                      by Heda4etak - 2025${RESET}\n"
}

check_port() {
  local port="$1"
  if sudo ss -tln | grep -q ":${port} "; then
    echo -e "${YELLOW}Порт ${port} уже занят. Выберите другой.${RESET}"
    exit 1
  fi
}

main() {
  ensure_sudo
  print_banner

  echo -e "${GREEN}Обновление пакетов...${RESET}"
  sudo apt update && sudo apt upgrade -y

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
    ssh-keygen -t rsa -b 4096 -N "" -f "$KEY_FILE"
  fi

  sudo mkdir -p /root/.ssh
  sudo touch /root/.ssh/authorized_keys
  sudo chmod 600 /root/.ssh/authorized_keys
  PUB_KEY_CONTENT=$(cat "$KEY_FILE.pub")
  sudo grep -qxF "$PUB_KEY_CONTENT" /root/.ssh/authorized_keys || sudo bash -c "echo '$PUB_KEY_CONTENT' >> /root/.ssh/authorized_keys"

  echo -e "${GREEN}Настройка SSH...${RESET}"
  sudo sed -i "/^Port /d" /etc/ssh/sshd_config
  echo "Port $SSH_PORT" | sudo tee -a /etc/ssh/sshd_config

  sudo sed -i "/^PasswordAuthentication /d" /etc/ssh/sshd_config
  echo "PasswordAuthentication no" | sudo tee -a /etc/ssh/sshd_config

  sudo sed -i "/^PubkeyAuthentication /d" /etc/ssh/sshd_config
  echo "PubkeyAuthentication yes" | sudo tee -a /etc/ssh/sshd_config

  sudo sed -i "/^PermitRootLogin /d" /etc/ssh/sshd_config
  echo "PermitRootLogin prohibit-password" | sudo tee -a /etc/ssh/sshd_config

  sudo systemctl restart sshd

  echo -e "${GREEN}Установка и настройка UFW...${RESET}"
  sudo apt install -y ufw
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  sudo ufw allow "$SSH_PORT"/tcp
  sudo ufw allow 80/tcp
  sudo ufw allow 443/tcp
  echo -e "${YELLOW}⚠️ Убедитесь, что SSH-порт $SSH_PORT открыт в UFW перед перезапуском SSH.${RESET}"
  sleep 3
  if ! sudo ufw status | grep -q "Status: active"; then
    sudo ufw --force enable
  fi

  echo -e "${CYAN}Перезапуск SSH...${RESET}"
  sudo systemctl restart sshd

  echo -e "${GREEN}✅ Настройка завершена.${RESET}"
  echo -e "${CYAN}🔑 Ваш SSH приватный ключ: ${YELLOW}$KEY_FILE${RESET}"
  echo -e "${CYAN}📂 Используйте ключ для подключения:${RESET}"
  echo -e "${YELLOW}ssh -i $KEY_FILE root@<IP> -p $SSH_PORT${RESET}"
  echo -e "${GREEN}⚠️ Рекомендуется перезагрузить VPS.${RESET}"
}

main "$@"
