#!/usr/bin/env bash
set -euo pipefail

source ".env"

if [[ -n "$NEW_USER" || -n "$HOST_LOCATION" || -n "$SSH_AUTH_KEY" || -n "$ALLOWED_HOSTS" ]]; then
  echo ""
  echo "Загружены параметры из .env"
  echo ""
  echo "NEW_USER: $NEW_USER"
  echo "HOST_LOCATION: $HOST_LOCATION"
  echo "SSH_AUTH_KEY: $SSH_AUTH_KEY"
  echo "ALLOWED_HOSTS: $ALLOWED_HOSTS"
  echo ""

else
  echo ""
  echo "Переменные среды не загружены: NEW_USER or HOST_LOCATION or SSH_AUTH_KEY or ALLOWED_HOSTS is NULL"
  echo "Отредактируйте файл: .env"
  echo "Подробнее: см README.md или cat env_markup"
  echo ""
  exit 1

fi

# Обновление пакетов
apt update && apt upgrade -y && apt autoremove -y
apt install file vim ufw cron git gh socat nginx python3.12-venv vnstat iftop -y

echo "Регистрация нового пользователя"
useradd -m -c "${HOST_LOCATION}" ${NEW_USER}
echo "Придумайте пароль для ${NEW_USER}: "
passwd $NEW_USER
usermod -aG sudo $NEW_USER
echo "Пользователь ${NEW_USER} создан."

if [[ -n "${HOST_LOCATION:-}" ]]; then
  sudo cp -a /etc/passwd "/etc/passwd.bak.$(date +%Y%m%d)"
  awk -v host_location="$HOST_LOCATION" -F: '
  $1 == "root" {
    print "root:x:0:0:root:/root:/sbin/nologin"
    next
  }
  $1 == $NEW_USER {
    print "${NEW_USER}:x:1000:1000:${HOST_LOCATION}:/home/${NEW_USER}:/bin/bash"
    next
  }
  { print }
  ' /etc/passwd | sudo tee /etc/passwd.new >/dev/null
  sudo mv /etc/passwd.new /etc/passwd

fi

# Настройка ssh
cp -a "/etc/ssh/sshd_config" "/etc/ssh/sshd_config.bak.$(date +%Y%m%d)"
cp "data/sshd_config" "/etc/ssh/"
systemctl restart ssh
echo "auth required pam_listfile.so onerr=succeed item=user sense=deny file=/etc/ssh/deniedusers" >> /etc/pam.d/login
echo "root" > "/etc/ssh/deniedusers" && chmod 600 "/etc/ssh/deniedusers"

#Настройка ufw
# Добавить в ufw доступ к SSH: allow ip:port:
# 32755/tcp поочередно для каждого IP из ALLOWED_HOSTS, если ip's указаны, иначе доступ с любого ip на 32755/tcp, если ALLOWED_HOSTS=="*"

if [[ "$ALLOWED_HOSTS" == "*" ]]; then
  ufw allow 32755/tcp comment "SSH from any ip"

else
  for allowed_ip in $ALLOWED_HOSTS; do
    ufw allow from $allowed_ip proto tcp to any port 32755 comment "SSH from ${allowed_ip}"
  
  done

fi

# Запустить ufw, если не запущен
if systemctl is-active --quiet ufw; then
  ufw reload
  echo "Ufw уже был запущен"

else
  ufw enable
  ufw start
  echo ""
  echo "Ufw установлен, настроен и запущен."

fi

# Настройка hostname
hostnamectl set-hostname ${HOST_LOCATION}

# Настройка timezone
timedatectl set-timezone "Europe/Moscow"

# Настройка journalctl
journalctl --vacuum-time=1d

# Настройка sysctl
cp "/etc/sysctl.conf" "/etc/sysctl.conf.back.$(date +%Y%m%d%H%M%S)"
cp "data/sysctl.conf" "/etc/sysctl.conf"
echo "sudo sysctl -p:"
echo ""
sysctl -p

# Автозагрузка Crontab
( crontab -l 2>/dev/null | sed '/^# MYJOBS-BEGIN$/,/^# MYJOBS-END$/d' || true
  cat <<'CRON'
# MYJOBS-BEGIN
0 0,12 * * * reboot
59 23 * * * truncate -s 0 /var/log/syslog && rm /var/log/*.gz && rm /var/log/*.1
59 23 * * * journalctl --vacuum-time=1d
# MYJOBS-END
CRON
) | crontab -

# Копирование monitoring/ -> /home/{NEW_USER}/
cp -r monitoring/ /home/${NEW_USER}/
chown -R ${NEW_USER}:${NEW_USER} /home/${NEW_USER}/monitoring

# Настройка SSH_AUTH_KEY пользователя NEW_USER
new_user_ssh="/home/${NEW_USER}/.ssh"
mkdir $new_user_ssh
chown -R ${NEW_USER}:${NEW_USER} $new_user_ssh
chmod 700 $new_user_ssh
echo "${SSH_AUTH_KEY}" >> "${new_user_ssh}/authorized_keys" && chmod 600 "${new_user_ssh}/authorized_keys"

# Выбор редактора: VIM
new_user_bashrc="/home/${NEW_USER}/.bashrc"
echo "export EDITOR=vim" >> $new_user_bashrc && echo "export VISUAL=vim" >> $new_user_bashrc

# Настройка доступа к github.com
echo "Настройка доступа к github.com."
echo "Регистрация id_ed25519.pub"
echo ""
ssh-keygen -t ed25519 -C "${HOST_LOCATION}" -f "${new_user_ssh}/id_ed25519"
chmod 700 $new_user_ssh && chmod 600 "${new_user_ssh}/id_ed25519" && chmod 644 "${new_user_ssh}/id_ed25519.pub"
echo "cat ${new_user_ssh}/id_ed25519.pub:"
cat "${new_user_ssh}/id_ed25519.pub"
echo "Вставьте этот SSH-ключ в github.com/ВАШ_USERNAME -> Settings -> SSH & GPG keys -> New SSH Key -> вставить новый auth key"
chown -R ${NEW_USER}:${NEW_USER} /home/${NEW_USER}/.ssh

# Переключение пользователя на NEW_USER
echo "Переключение пользователя: root -> USER:${NEW_USER}

Проверьте настройки нового пользователя:
sudo cat /etc/passwd
sudo sysctl -p
sudo cat /etc/ssh/sshd_config
sudo ufw status
ssh -T git@github.com
sudo update-alternatives --config editor

Затем, перезагрузите систему:
sudo reboot

"

su -c ${NEW_USER}
cd ~
sudo ls
