# Rumah Jurnal - Literasi Nusantara

Repository ini berisi paket perencanaan dan deployment awal untuk portal jurnal ilmiah **Literasi Nusantara Journal Center** berbasis Open Journal Systems (OJS).

Target domain:

```text
jurnal.literasinusantara.com
```

Isi utama:

- `OJS_VPS_DEPLOYMENT_LITERASI_NUSANTARA.md` - panduan audit VPS dan instalasi OJS step-by-step.
- `literasi-nusantara-ojs-custom.css` - stylesheet ringan untuk branding OJS.
- `scripts/audit-vps.sh` - script audit VPS non-destruktif sebelum instalasi.

Tujuan akhir:

- OJS berjalan di VPS dengan HTTPS.
- Portal siap menerima submission artikel.
- Workflow submission, review, editorial, archive, dan indexing siap dikonfigurasi.
- Backup dan cron job dasar aktif.

Catatan:

- Panduan memakai OJS 3.4.0-10 sebagai pilihan produksi konservatif.
- OJS core tidak diedit untuk branding awal; gunakan custom stylesheet dari dashboard OJS.

## Langkah Berikutnya

Jalankan audit di VPS:

```bash
wget https://raw.githubusercontent.com/ahmadhumaidi/rumah-jurnal/main/scripts/audit-vps.sh
chmod +x audit-vps.sh
./audit-vps.sh jurnal.literasinusantara.com | tee audit-vps-literasi-nusantara.txt
```

Kirim hasil `audit-vps-literasi-nusantara.txt` sebelum instalasi OJS dijalankan.
