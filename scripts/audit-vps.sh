#!/usr/bin/env bash
set -u

DOMAIN="${1:-jurnal.literasinusantara.com}"

section() {
  printf '\n===== %s =====\n' "$1"
}

run() {
  printf '\n$ %s\n' "$*"
  "$@" 2>&1 || true
}

section "Identity"
run whoami
run hostname
run hostnamectl

section "Operating System"
run sh -c 'lsb_release -a 2>/dev/null || cat /etc/os-release'
run uname -a

section "Resources"
run free -h
run df -h
run lsblk

section "Network And DNS"
run ip addr show
run sh -c "command -v dig >/dev/null 2>&1 && dig +short \"$DOMAIN\" || getent hosts \"$DOMAIN\""
run sh -c "curl -I --max-time 10 http://$DOMAIN 2>/dev/null || true"

section "Firewall"
run sh -c 'command -v ufw >/dev/null 2>&1 && sudo ufw status verbose || true'

section "Web Server"
run sh -c 'command -v nginx >/dev/null 2>&1 && nginx -v || true'
run sh -c 'command -v apache2 >/dev/null 2>&1 && apache2 -v || true'
run systemctl status nginx --no-pager
run systemctl status apache2 --no-pager

section "PHP"
run sh -c 'command -v php >/dev/null 2>&1 && php -v || true'
run sh -c 'command -v php >/dev/null 2>&1 && php -m || true'
run sh -c 'systemctl list-units --type=service --all | grep -E "php.*fpm" || true'

section "Database"
run sh -c 'command -v mariadb >/dev/null 2>&1 && mariadb --version || true'
run sh -c 'command -v mysql >/dev/null 2>&1 && mysql --version || true'
run systemctl status mariadb --no-pager
run systemctl status mysql --no-pager

section "Existing Web Roots"
run ls -lah /var/www
run sh -c 'ls -lah /etc/nginx/sites-available 2>/dev/null || true'
run sh -c 'ls -lah /etc/nginx/sites-enabled 2>/dev/null || true'
run sh -c 'ls -lah /etc/apache2/sites-available 2>/dev/null || true'
run sh -c 'ls -lah /etc/apache2/sites-enabled 2>/dev/null || true'

section "Ports"
run sh -c 'ss -tulpn | grep -E ":80|:443|:3306|:5432|:22" || true'

section "Summary Reminder"
cat <<EOF
Audit selesai. Kirim/paste output ini ke Codex sebelum menjalankan instalasi.
Script ini hanya membaca kondisi server dan tidak mengubah konfigurasi.
Domain yang dicek: $DOMAIN
EOF

