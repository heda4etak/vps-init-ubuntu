#!/bin/bash

# VPS Init Script for Ubuntu 24.04
# Features:
# 1. Custom SSH port + SSH key auth only
# 2. SSHD config tuning
# 3. XanMod kernel install (optional, install manually)
# 4. UFW setup
# 5. Network optimizations

set -e

# Prompt for SSH port
read -p "Введите новый порт для SSH (например, 2222): " SSH_PORT

# Prompt for SSH key name
read -p "Введите имя файла ключа SSH (например, id_rsa_server1): " SSH_KEY_NAME

# Generate SSH key
ssh-keygen -t rsa -b 4096 -f ~/.ssh/$SSH_KEY_NAME

# Установим публичный ключ на сервер
mkdir -p ~/.ssh
cat ~/.ssh/${SSH_KEY_NAME}.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# Настройка SSHD
echo "Настраиваем sshd_config..."
sudo sed -i "s/^#Port.*/Port $SSH_PORT/" /etc/ssh/sshd_config
sudo sed -i "s/^#PasswordAuthentication.*/PasswordAuthentication no/" /etc/ssh/sshd_config
sudo sed -i "s/^#PubkeyAuthentication.*/PubkeyAuthentication yes/" /etc/ssh/sshd_config
sudo sed -i "s/^PermitRootLogin.*/PermitRootLogin prohibit-password/" /etc/ssh/sshd_config

# Перезапускаем SSH
echo "Перезапускаем SSH..."
sudo systemctl restart sshd

# Установка UFW
echo "Устанавливаем UFW и настраиваем..."
sudo apt update
sudo apt install -y ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow $SSH_PORT/tcp
sudo ufw allow http
sudo ufw allow https
sudo ufw --force enable

# Оптимизация sysctl
echo "Настройка сети (sysctl)..."
cat <<EOF | sudo tee -a /etc/sysctl.conf

# Custom network optimizations
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl -p

echo "✅ Настройка завершена. Переподключитесь к серверу по новому порту SSH: $SSH_PORT"
