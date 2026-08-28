#!/usr/bin/env bash
set -euo pipefail

source ".env"

if [[ -n "$NEW_USER" && -n "$HOST_LOCATION" && -n "$SSH_AUTH_KEY" && -n "$SSH_PASSPHRASE" && -n "$ALLOWED_HOSTS" ]]; then
  echo ""
  echo "Загружены параметры из .env"
  echo ""
  echo "NEW_USER: $NEW_USER"
  echo "HOST_LOCATION: $HOST_LOCATION"
  echo "SSH_AUTH_KEY: $SSH_AUTH_KEY"
  echo "SSH_PASSPHRASE: $SSH_PASSPHRASE"
  echo "ALLOWED_HOSTS: $ALLOWED_HOSTS"
  echo ""

else
  echo ""
  echo "Переменные среды не загружены: NEW_USER or HOST_LOCATION or SSH_AUTH_KEY or SSH_PASSPHRASE or ALLOWED_HOSTS is NULL"
  echo "Отредактируйте файл: .env"
  echo "Подробнее: см README.md или cat env_markup"
  echo ""
  exit 1

fi

# Обновление пакетов
apt update && apt upgrade -y && apt autoremove -y
apt install file vim ufw cron git socat nginx vnstat iftop -y

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

# Настройка hostname
hostnamectl set-hostname ${HOST_LOCATION}

# Настройка timezone
timedatectl set-timezone "Europe/Moscow"

# Настройка journalctl
journalctl --vacuum-time=1d

echo "Регистрация нового пользователя"
cp -a /etc/passwd "/etc/passwd.bak.$(date +%Y%m%d)"
useradd -m -s /bin/bash -c "${HOST_LOCATION}" -G sudo "${NEW_USER}"
echo "Придумайте пароль для ${NEW_USER}: "
passwd "${NEW_USER}"
usermod -s /usr/sbin/nologin root
echo "Пользователь ${NEW_USER} создан."
echo ""
echo "Профили пользователей: root, ${NEW_USER} на vps в /etc/passwd:"
getent passwd "${NEW_USER}"
id "${NEW_USER}"
getent passwd root

# Выбор редактора: VIM
new_user_bashrc="/home/${NEW_USER}/.bashrc"
echo "export EDITOR=vim" >> $new_user_bashrc && echo "export VISUAL=vim" >> $new_user_bashrc

# Копирование monitoring/ -> /home/{NEW_USER}/
cp -r monitoring/ /home/${NEW_USER}/
chown -R ${NEW_USER}:${NEW_USER} /home/${NEW_USER}/monitoring

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
# Включить ufw, если не включен
ufw --force enable
ufw reload

# Настройка sysctl
cp "/etc/sysctl.conf" "/etc/sysctl.conf.back.$(date +%Y%m%d%H%M%S)"
cp "data/sysctl.conf" "/etc/sysctl.conf"
echo "sudo sysctl -p:"
echo ""
sysctl -p

# Выбор редактора по умолчанию: выставить vim
update-alternatives --config editor

# Настройка SSH_AUTH_KEY пользователя NEW_USER
new_user_ssh="/home/${NEW_USER}/.ssh"
mkdir -p $new_user_ssh
chown -R ${NEW_USER}:${NEW_USER} $new_user_ssh
chmod 700 $new_user_ssh
echo "${SSH_AUTH_KEY}" > "${new_user_ssh}/authorized_keys" && chmod 600 "${new_user_ssh}/authorized_keys"

# Настройка доступа к github.com
echo "Настройка доступа к github.com."
echo "Регистрация id_ed25519.pub"
echo ""
rm -f "${new_user_ssh}/id_ed25519" "${new_user_ssh}/id_ed25519.pub"
ssh-keygen -t ed25519 -N "${SSH_PASSPHRASE}" -C "${HOST_LOCATION}" -f "${new_user_ssh}/id_ed25519"
chmod 700 $new_user_ssh && chmod 600 "${new_user_ssh}/id_ed25519" && chmod 644 "${new_user_ssh}/id_ed25519.pub"
chown -R ${NEW_USER}:${NEW_USER} /home/${NEW_USER}/.ssh

echo ""
echo "Вставьте этот SSH-ключ в https://github.com/settings/keys"
echo "cat ${new_user_ssh}/id_ed25519.pub:"
cat "${new_user_ssh}/id_ed25519.pub"
echo ""
echo "cat /etc/ssh/sshd_config"
cat /etc/ssh/sshd_config
echo ""
echo "ufw status"
ufw status
echo ""

# Переключение пользователя на NEW_USER
echo "Протестируйте шелл пользователя USER:${NEW_USER} и запуск основных программ

su ${NEW_USER}
cd ~
sudo ls

ssh -T git@github.com

Затем, перезагрузите систему:
sudo reboot
"
