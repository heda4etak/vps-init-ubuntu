#!/bin/bash

# Цвета
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
NC="\033[0m"

cat << "EOF"


██╗   ██╗██████╗ ███████╗      ███████╗███████╗████████╗██╗   ██╗██████╗ 
██║   ██║██╔══██╗██╔════╝      ██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗
██║   ██║██████╔╝███████╗█████╗███████╗█████╗     ██║   ██║   ██║██████╔╝
╚██╗ ██╔╝██╔═══╝ ╚════██║╚════╝╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝ 
 ╚████╔╝ ██║     ███████║      ███████║███████╗   ██║   ╚██████╔╝██║     
  ╚═══╝  ╚═╝     ╚══════╝      ╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝     
                                                                         
 
                                             
    VPS Initial Setup Script for Ubuntu 24.04
              by Heda4etak - 2025

EOF

echo -e "${CYAN}--- VPS Initial Setup Script for Ubuntu 24.04 ---${NC}"

# 1. Настройка SSH-порта
read -p "Введите новый порт для SSH (например, 2222): " SSH_PORT

if ! [[ "$SSH_PORT" =~ ^[0-9]+$ ]] || [ "$SSH_PORT" -lt 1 ] || [ "$SSH_PORT" -gt 65535 ]; then
    echo -e "${YELLOW}Неверный порт. Завершение.${NC}"
    exit 1
fi

# 2. Ввод имени SSH-ключа
read -p "Введите имя SSH-ключа (без пути, например: id_rsa_myvps): " KEY_NAME
if [[ -z "$KEY_NAME" ]]; then
    echo -e "${YELLOW}Имя ключа не может быть пустым. Завершение.${NC}"
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
fi

# Копируем публичный ключ в authorized_keys root-пользователя
sudo mkdir -p /root/.ssh
sudo cp "$KEY_FILE.pub" /root/.ssh/authorized_keys
sudo chmod 600 /root/.ssh/authorized_keys

# 3. Настройка sshd_config
echo -e "${GREEN}Настройка SSH...${NC}"
sudo sed -i "s/#Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config
sudo sed -i "s/#PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
sudo sed -i "s/#PubkeyAuthentication yes/PubkeyAuthentication yes/" /etc/ssh/sshd_config
sudo sed -i "s/PermitRootLogin .*/PermitRootLogin prohibit-password/" /etc/ssh/sshd_config

# 4. Установка XanMod ядра и включение BBR3
echo -e "${GREEN}Установка XanMod ядра с BBR3...${NC}"
echo 'deb http://deb.xanmod.org releases main' | sudo tee /etc/apt/sources.list.d/xanmod-kernel.list
wget -qO - https://dl.xanmod.org/gpg.key | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/xanmod.gpg
sudo apt update
sudo apt install -y linux-xanmod-x64v4

echo -e "${GREEN}Включение BBR...${NC}"
sudo tee -a /etc/sysctl.conf > /dev/null <<EOF

# BBR and network tuning
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF

sudo sysctl -p

# 5. Настройка UFW
echo -e "${GREEN}Установка и настройка UFW...${NC}"
sudo apt install -y ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow "$SSH_PORT"/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable

# 6. Перезапуск SSH
echo -e "${CYAN}Перезапуск SSH...${NC}"
sudo systemctl restart ssh

# Финал
echo -e "${GREEN}✅ Настройка завершена.${NC}"
echo -e "${CYAN}🔑 Ваш SSH приватный ключ: ${YELLOW}$KEY_FILE${NC}"
echo -e "${CYAN}📂 Используйте ключ для подключения. Пример команды:${NC}"
echo -e "${YELLOW}ssh -i $KEY_FILE root@<IP> -p $SSH_PORT${NC}"
echo -e "${GREEN}⚠️ Не забудьте перезагрузить VPS для загрузки с нового ядра.${NC}"
