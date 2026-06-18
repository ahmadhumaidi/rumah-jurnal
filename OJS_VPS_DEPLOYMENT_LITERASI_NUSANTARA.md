# Rencana Teknis Deployment OJS

Brand: Literasi Nusantara  
Domain: jurnal.literasinusantara.com  
Target: portal jurnal ilmiah profesional berbasis Open Journal Systems (OJS) untuk submission, review, editorial workflow, archive, dan indexing.

## Ringkasan Keputusan Aman

- Gunakan Ubuntu 22.04 LTS atau 24.04 LTS.
- Gunakan OJS 3.4.0-10 untuk produksi awal karena rilis 3.5.0-4 sudah tersedia tetapi belum ditandai LTS oleh PKP per 18 Juni 2026.
- Gunakan PHP 8.2 atau lebih baru. Untuk kompatibilitas praktis, PHP 8.2 adalah pilihan konservatif.
- Gunakan MariaDB atau MySQL. MariaDB dari repository Ubuntu aman untuk VPS standar.
- Gunakan Nginx + PHP-FPM untuk performa ringan di VPS.
- Simpan `files_dir` OJS di luar web root: `/var/ojs-files`.
- Jangan jalankan perintah penghapusan massal. Panduan ini tidak memakai perintah hapus rekursif.
- Composer tidak wajib bila memakai paket rilis resmi OJS `.tar.gz`.

Referensi resmi:

- PKP Download OJS: https://pkp.sfu.ca/software/ojs/download/
- OJS GitHub README requirements: https://github.com/pkp/ojs/blob/main/README.md

## 1. Audit Kondisi VPS

Jalankan bagian ini dulu setelah login SSH ke VPS.

```bash
whoami
hostnamectl
lsb_release -a || cat /etc/os-release
uname -a
df -h
free -h
ip addr show
sudo ufw status verbose
systemctl status nginx --no-pager || true
systemctl status apache2 --no-pager || true
php -v || true
mysql --version || mariadb --version || true
```

Yang dicari dari audit:

- OS Ubuntu aktif dan masih didukung.
- RAM minimal nyaman: 2 GB. Bisa jalan di 1 GB, tetapi review/upload PDF akan lebih sehat di 2 GB+.
- Storage minimal awal: 20 GB, lebih baik 40 GB+ karena file submission dan backup akan tumbuh.
- Port 80 dan 443 bisa dibuka.
- Belum ada service web server penting yang dipakai aplikasi lain.

Jika VPS sudah punya website lain, berhenti dulu sebelum konfigurasi Nginx agar tidak menimpa virtual host yang aktif.

## 2. DNS Domain/Subdomain

Di panel DNS domain `literasinusantara.com`, buat record:

```text
Type: A
Name: jurnal
Value: IP_VPS_ANDA
TTL: default / 300
```

Verifikasi dari komputer lokal atau VPS:

```bash
dig +short jurnal.literasinusantara.com
```

Lanjutkan SSL hanya setelah hasilnya mengarah ke IP VPS.

## 3. Persiapan Server

Fungsi bagian ini: memasang paket server dasar, Nginx, MariaDB, PHP-FPM, ekstensi PHP OJS, unzip/tar/curl, dan Certbot. Ini mengubah paket server, tapi tidak menghapus file website yang sudah ada.

```bash
sudo apt update
sudo apt install -y software-properties-common ca-certificates curl wget unzip tar nano ufw
sudo apt install -y nginx mariadb-server mariadb-client
sudo apt install -y php8.2-fpm php8.2-cli php8.2-mysql php8.2-curl php8.2-gd php8.2-intl php8.2-mbstring php8.2-xml php8.2-zip php8.2-bcmath php8.2-soap php8.2-opcache
sudo apt install -y certbot python3-certbot-nginx
```

Cek versi:

```bash
php -v
nginx -v
mariadb --version
```

## 4. Firewall

Fungsi bagian ini: membuka akses SSH, HTTP, dan HTTPS. Jangan aktifkan UFW kalau akses SSH VPS belum pasti memakai port standar atau belum ada akses panel recovery.

```bash
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw status verbose
sudo ufw enable
```

## 5. Hardening Ringan PHP

Fungsi bagian ini: menaikkan batas upload dan runtime agar submission PDF tidak mudah gagal.

Edit:

```bash
sudo nano /etc/php/8.2/fpm/php.ini
```

Set nilai berikut:

```ini
memory_limit = 256M
upload_max_filesize = 64M
post_max_size = 72M
max_execution_time = 120
max_input_time = 120
date.timezone = Asia/Jakarta
```

Restart PHP-FPM:

```bash
sudo systemctl restart php8.2-fpm
```

## 6. Setup Database

Fungsi bagian ini: membuat database dan user khusus OJS. Gunakan password kuat dan simpan di password manager.

Masuk MariaDB:

```bash
sudo mariadb
```

Jalankan SQL berikut. Ganti `PASSWORD_KUAT_DI_SINI`.

```sql
CREATE DATABASE ojs_literasi CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'ojs_literasi'@'localhost' IDENTIFIED BY 'PASSWORD_KUAT_DI_SINI';
GRANT ALL PRIVILEGES ON ojs_literasi.* TO 'ojs_literasi'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

Tes login database:

```bash
mariadb -u ojs_literasi -p ojs_literasi
```

Keluar dengan:

```sql
EXIT;
```

## 7. Download dan Pasang OJS

Fungsi bagian ini: mengunduh paket resmi OJS, menaruh kode di `/var/www/ojs`, dan menyiapkan folder file upload di luar web root. Perintah ini tidak menghapus folder website lain.

```bash
cd /tmp
wget https://pkp.sfu.ca/ojs/download/ojs-3.4.0-10.tar.gz
tar -xzf ojs-3.4.0-10.tar.gz
sudo mkdir -p /var/www/ojs
sudo cp -a ojs-3.4.0-10/. /var/www/ojs/
sudo mkdir -p /var/ojs-files
sudo chown -R www-data:www-data /var/www/ojs /var/ojs-files
sudo find /var/www/ojs -type d -exec chmod 755 {} \;
sudo find /var/www/ojs -type f -exec chmod 644 {} \;
sudo chmod -R 750 /var/ojs-files
sudo chmod 664 /var/www/ojs/config.inc.php
```

Catatan permission:

- `/var/www/ojs/public`
- `/var/www/ojs/cache`
- `/var/www/ojs/cache/t_cache`
- `/var/www/ojs/cache/t_compile`
- `/var/www/ojs/cache/_db`
- `/var/ojs-files`

harus bisa ditulis oleh user web server `www-data`.

Pastikan:

```bash
sudo -u www-data test -w /var/www/ojs/config.inc.php && echo "config writable"
sudo -u www-data test -w /var/ojs-files && echo "files dir writable"
```

## 8. Konfigurasi Nginx

Fungsi bagian ini: membuat virtual host khusus `jurnal.literasinusantara.com`. Ini tidak menghapus konfigurasi Nginx lain.

Buat file:

```bash
sudo nano /etc/nginx/sites-available/jurnal.literasinusantara.com
```

Isi:

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name jurnal.literasinusantara.com;

    root /var/www/ojs;
    index index.php index.html;

    client_max_body_size 72M;

    access_log /var/log/nginx/jurnal.literasinusantara.com.access.log;
    error_log /var/log/nginx/jurnal.literasinusantara.com.error.log;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ ^/(cache|files|store|dbscripts|docs|tools)/ {
        deny all;
    }

    location ~ /\. {
        deny all;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
```

Aktifkan site:

```bash
sudo ln -s /etc/nginx/sites-available/jurnal.literasinusantara.com /etc/nginx/sites-enabled/jurnal.literasinusantara.com
sudo nginx -t
sudo systemctl reload nginx
```

Jika `ln -s` gagal karena file sudah ada, jangan timpa. Cek dulu:

```bash
ls -l /etc/nginx/sites-enabled/
```

## 9. Instalasi OJS dari Browser

Buka:

```text
http://jurnal.literasinusantara.com
```

Isi form instalasi:

- Administrator username: buat akun admin utama.
- Administrator password: password kuat.
- Administrator email: email resmi pengelola.
- Locale: Indonesian dan English bila diperlukan.
- Database driver: MySQLi.
- Host: localhost.
- Username: ojs_literasi.
- Password: password database.
- Database name: ojs_literasi.
- Repository files path: `/var/ojs-files`.

Setelah instalasi sukses, amankan config:

```bash
sudo chmod 640 /var/www/ojs/config.inc.php
sudo chown www-data:www-data /var/www/ojs/config.inc.php
```

Pastikan di `/var/www/ojs/config.inc.php`:

```ini
installed = On
base_url = "https://jurnal.literasinusantara.com"
```

## 10. Setup SSL

Fungsi bagian ini: membuat sertifikat HTTPS Let's Encrypt untuk subdomain. Jalankan setelah DNS benar dan Nginx sudah menampilkan OJS via HTTP.

```bash
sudo certbot --nginx -d jurnal.literasinusantara.com
```

Pilih redirect HTTP ke HTTPS jika ditanya.

Tes auto-renew:

```bash
sudo certbot renew --dry-run
```

## 11. Cron Job OJS

Fungsi bagian ini: menjalankan scheduled task OJS agar email, reminder, dan pekerjaan berkala berjalan.

Buka crontab user web:

```bash
sudo crontab -u www-data -e
```

Tambahkan:

```cron
*/15 * * * * php /var/www/ojs/tools/runScheduledTasks.php >/dev/null 2>&1
```

## 12. Backup Otomatis

Fungsi bagian ini: membuat backup database, file upload OJS, dan config. Backup disimpan di `/var/backups/ojs`. Untuk instalasi awal, panduan ini tidak menghapus backup lama secara otomatis agar tidak ada risiko salah target.

Buat folder:

```bash
sudo mkdir -p /var/backups/ojs
sudo chown root:root /var/backups/ojs
sudo chmod 700 /var/backups/ojs
```

Buat file script:

```bash
sudo nano /usr/local/sbin/backup-ojs-literasi.sh
```

Isi:

```bash
#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="/var/backups/ojs"
DATE="$(date +%F_%H-%M-%S)"
DB_NAME="ojs_literasi"
DB_USER="ojs_literasi"
DB_PASS="PASSWORD_DATABASE_DI_SINI"

mkdir -p "$BACKUP_DIR/$DATE"

mysqldump --single-transaction --routines --triggers -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" | gzip > "$BACKUP_DIR/$DATE/database.sql.gz"
tar -czf "$BACKUP_DIR/$DATE/ojs-files.tar.gz" -C /var ojs-files
tar -czf "$BACKUP_DIR/$DATE/ojs-config.tar.gz" -C /var/www/ojs config.inc.php public
```

Amankan script:

```bash
sudo chmod 700 /usr/local/sbin/backup-ojs-literasi.sh
sudo chown root:root /usr/local/sbin/backup-ojs-literasi.sh
```

Tes backup:

```bash
sudo /usr/local/sbin/backup-ojs-literasi.sh
sudo ls -lah /var/backups/ojs
```

Jadwalkan backup harian jam 02:30:

```bash
sudo crontab -e
```

Tambahkan:

```cron
30 2 * * * /usr/local/sbin/backup-ojs-literasi.sh >/var/log/ojs-backup.log 2>&1
```

Rekomendasi tambahan: sinkronkan `/var/backups/ojs` ke storage luar VPS, misalnya S3, Google Drive, atau server backup lain.

Untuk melihat backup yang sudah lebih dari 14 hari tanpa menghapusnya:

```bash
sudo find /var/backups/ojs -mindepth 1 -maxdepth 1 -type d -mtime +14 -print
```

## 13. Email Jurnal

OJS butuh email yang stabil untuk registrasi, submission, editorial decision, dan review reminder.

Rekomendasi:

- Pakai SMTP domain, bukan PHP mail bawaan.
- Buat alamat seperti `jurnal@literasinusantara.com` atau `editorial@literasinusantara.com`.
- Di OJS, atur SMTP dari dashboard admin.

Contoh konfigurasi `config.inc.php` bila memakai SMTP:

```ini
smtp = On
smtp_server = "smtp.provider-anda.com"
smtp_port = 587
smtp_auth = ssl
smtp_username = "jurnal@literasinusantara.com"
smtp_password = "PASSWORD_EMAIL"
allow_envelope_sender = On
default_envelope_sender = "jurnal@literasinusantara.com"
```

## 14. Checklist Setelah Instalasi

- Buat akun admin utama dan simpan kredensial di password manager.
- Set nama website: `Literasi Nusantara Journal Center`.
- Set email utama: `jurnal@literasinusantara.com` atau alamat final yang dipilih.
- Buat jurnal pertama, misalnya `Jurnal Literasi Nusantara`.
- Upload logo dan favicon.
- Lengkapi halaman About.
- Lengkapi Author Guidelines.
- Lengkapi Publication Ethics.
- Lengkapi Peer Review Process.
- Lengkapi Focus and Scope.
- Lengkapi Copyright Notice dan License, misalnya CC BY 4.0 jika sesuai kebijakan.
- Aktifkan DOI/Crossref hanya setelah punya membership dan prefix DOI.
- Aktifkan metadata indexing: OAI-PMH, Google Scholar-friendly metadata, sitemap bila plugin tersedia.
- Buat role editor, section editor, reviewer, copyeditor bila dibutuhkan.
- Tes alur submission dengan akun author dummy.
- Tes assignment reviewer dengan akun reviewer dummy.
- Tes email keluar dari OJS.
- Tes upload PDF dan galley.
- Tes halaman archive dan issue pertama.

## 15. Custom Tampilan Ringan

Cara paling aman untuk awal: jangan edit core OJS. Gunakan custom stylesheet dari menu Appearance.

File CSS yang disiapkan di workspace:

```text
literasi-nusantara-ojs-custom.css
```

Upload melalui:

```text
Settings > Website > Appearance > Advanced > Journal style sheet
```

Jika ingin benar-benar membuat theme plugin khusus, lakukan setelah website stabil. Untuk MVP, custom stylesheet lebih aman dan mudah dipulihkan.

## 16. Smoke Test Publik

Setelah SSL aktif:

```bash
curl -I https://jurnal.literasinusantara.com
curl -I https://jurnal.literasinusantara.com/index.php/index
sudo tail -n 80 /var/log/nginx/jurnal.literasinusantara.com.error.log
```

Dari browser:

- Buka homepage.
- Login admin.
- Buka dashboard.
- Buat jurnal pertama.
- Buat submission dummy.
- Upload file dummy PDF.
- Pastikan tidak ada error 403/404/500.

## 17. Catatan Operasional

- Jangan upgrade OJS langsung di production tanpa backup database dan `/var/ojs-files`.
- Jangan simpan `files_dir` di dalam `/var/www/ojs/public`.
- Jangan memberi permission `777`.
- Jangan edit core OJS untuk branding awal.
- Simpan catatan semua password, versi OJS, tanggal instalasi, dan lokasi backup.
- Aktifkan monitoring uptime sederhana untuk `https://jurnal.literasinusantara.com`.
