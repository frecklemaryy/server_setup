#!/bin/zsh
set -euo pipefail

if [[ $# -ne 1 || -z "$1" ]]; then
  echo "Использование: $0 VPS_IP"
  exit 1
fi

VPS_IP="$1"
script_dir="${0:A:h}"
base_env="${script_dir}/.server_setup_env"
runtime_env="${script_dir}/.env_to_move_to_new_vps"

if [[ ! -f "$base_env" ]]; then
  echo "Нет файла ${base_env}"
  exit 1
fi

read -r "?NEW_USER_PASSWORD: " NEW_USER_PASSWORD
read -r "?HOST_LOCATION: " HOST_LOCATION

if [[ -z "$NEW_USER_PASSWORD" || -z "$HOST_LOCATION" ]]; then
  echo "NEW_USER_PASSWORD и HOST_LOCATION не могут быть пустыми"
  exit 1
fi

quote() {
  local value="$1"
  value=${value//\'/\'\\\'\'}
  print -r -- "'${value}'"
}

trap 'rm -f "$runtime_env"' EXIT

seen_password=0
seen_location=0
{
  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      NEW_USER_PASSWORD=*)
        print -r -- "NEW_USER_PASSWORD=$(quote "$NEW_USER_PASSWORD")"
        seen_password=1
        ;;
      HOST_LOCATION=*)
        print -r -- "HOST_LOCATION=$(quote "$HOST_LOCATION")"
        seen_location=1
        ;;
      *)
        print -r -- "$line"
        ;;
    esac
  done < "$base_env"
  if (( ! seen_password )); then
    print -r -- "NEW_USER_PASSWORD=$(quote "$NEW_USER_PASSWORD")"
  fi
  if (( ! seen_location )); then
    print -r -- "HOST_LOCATION=$(quote "$HOST_LOCATION")"
  fi
} > "$runtime_env"

chmod 600 "$runtime_env"
echo "${VPS_IP}"
scp -P 22 "$runtime_env" "root@${VPS_IP}:/tmp/.server_setup_env"
