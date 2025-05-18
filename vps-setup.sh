#!/bin/bash
clear

# Цвета
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
CYAN="\033[36m"
NC="\033[0m"

main() {
  # Проверка sudo
  if ! sudo -v; then
      echo -e "${RED}Требуются права суперпользователя (sudo). Запустите скрипт с sudo.${NC}"
      exit 1
  fi

  # Баннер
  cat << "EOF"


██╗   ██╗██████╗ ███████╗      ███████╗███████╗████████╗██╗   ██╗██████╗ 
██║   ██║██╔══██╗██╔════╝      ██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗
██║   ██║██████╔╝███████╗█████╗███████╗█████╗     ██║   ██║   ██║██████╔╝
╚██╗ ██╔╝██╔═══╝ ╚════██║╚════╝╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝ 
 ╚████╔╝ ██║     ███████║      ███████║███████╗   ██║   ╚██████╔╝██║     
  ╚═══╝  ╚═╝     ╚══════╝      ╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝     
                                                                           

                                                 
    VPS Initial Setup Script for Ubuntu 24.04

EOF

  # Ввод порта и проверка
  read -p "Введите новый порт для SSH (например, 2222): " SSH_PORT
  if ! [[ "$SSH_PORT" =~ ^[0-9]+$ ]] || [ "$SSH_PORT" -lt 1 ] || [ "$SSH_PORT" -gt 65535 ]; then
      echo -e "${YELLOW}Неверный порт.${NC}"
      exit 1
  fi

  if sudo ss -tln | grep -q ":$SSH_PORT "; then
      echo -e "${YELLOW}Порт $SSH_PORT уже занят.${NC}"
      exit 1
  fi

  # Ввод имени ключа
  read -p "Введите имя SSH-ключа (без пути, например: id_rsa_myvps): " KEY_NAME
  if [[ -z "$KEY_NAME" ]]; then
      echo -e "${YELLOW}Имя ключа не может быть пустым.${NC}"
      exit 1
  fi

  SSH_DIR="$HOME/.ssh"
  KEY_FILE="$SSH_DIR/$KEY_NAME"

  mkdir -p "$SSH_DIR"
  chmod 700 "$SSH_DIR"

  if [ -f "$KEY_FILE" ]; then
      echo -e "${YELLOW}SSH ключ уже существует: $KEY_FILE${NC}"
  else
      echo -e "${GREEN}Генерация SSH ключа...${NC}"
      ssh-keygen -t rsa -b 4096 -N "" -f "$KEY_FILE"
      if [ $? -ne 0 ]; then
          echo -e "${RED}Ошибка генерации SSH ключа.${NC}"
          exit 1
      fi
  fi

  # Добавление публичного ключа в root authorized_keys
  sudo mkdir -p /root/.ssh
  sudo touch /root/.ssh/authorized_keys
  sudo chmod 600 /root/.ssh/authorized_keys
  PUB_KEY_CONTENT=$(cat "$KEY_FILE.pub")
  if ! sudo grep -qxF "$PUB_KEY_CONTENT" /root/.ssh/authorized_keys; then
      echo "$PUB_KEY_CONTENT" | sudo tee -a /root/.ssh/authorized_keys > /dev/null
  fi

  # Настройка sshd_config
  echo -e "${GREEN}Настройка SSH...${NC}"
  sudo sed -i "/^Port /d" /etc/ssh/sshd_config
  echo "Port $SSH_PORT" | sudo tee -a /etc/ssh/sshd_config

  sudo sed -i "/^PasswordAuthentication /d" /etc/ssh/sshd_config
  echo "PasswordAuthentication no" | sudo tee -a /etc/ssh/sshd_config

  sudo sed -i "/^PubkeyAuthentication /d" /etc/ssh/sshd_config
  echo "PubkeyAuthentication yes" | sudo tee -a /etc/ssh/sshd_config

  sudo sed -i "/^PermitRootLogin /d" /etc/ssh/sshd_config
  echo "PermitRootLogin prohibit-password" | sudo tee -a /etc/ssh/sshd_config

  # Установка XanMod ядра и ключа
  echo -e "${GREEN}Установка XanMod ядра с BBR3...${NC}"
  echo 'deb http://deb.xanmod.org releases main' | sudo tee /etc/apt/sources.list.d/xanmod-kernel.list
  wget -qO - https://dl.xanmod.org/gpg.key | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/xanmod.gpg

  sudo apt update || { echo -e "${RED}Ошибка обновления списков пакетов.${NC}"; exit 1; }
  sudo apt install -y linux-xanmod-x64v4 || { echo -e "${RED}Ошибка установки XanMod ядра.${NC}"; exit 1; }

  # Включение BBR через sysctl.d
  echo -e "${GREEN}Включение BBR...${NC}"
  sudo tee /etc/sysctl.d/99-bbr.conf > /dev/null <<EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
  sudo sysctl --system

  # Настройка UFW
  echo -e "${GREEN}Установка и настройка UFW...${NC}"
  sudo apt install -y ufw
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  sudo ufw allow "$SSH_PORT"/tcp
  sudo ufw allow 80/tcp
  sudo ufw allow 443/tcp

  if ! sudo ufw status | grep -q "Status: active"; then
      sudo ufw --force enable
  fi

  echo -e "${CYAN}Перезапуск SSH...${NC}"
  sudo systemctl restart ssh

  echo -e "${GREEN}✅ Настройка завершена.${NC}"
  echo -e "${CYAN}🔑 Ваш SSH приватный ключ: ${YELLOW}$KEY_FILE${NC}"
  echo -e "${CYAN}📂 Используйте ключ для подключения:${NC}"
  echo -e "${YELLOW}ssh -i $KEY_FILE root@<IP> -p $SSH_PORT${NC}"
  echo -e "${GREEN}⚠️ Рекомендуется перезагрузить VPS для загрузки нового ядра и применения настроек.${NC}"
}

main "$@"
