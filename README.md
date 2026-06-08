# Hasil-TKA-Mumtaza

Aplikasi web untuk melihat dan mengunduh Hasil Tes Kemampuan Akademik (TKA) SMP Mumtaza.

**Live:** [https://smpmumtaza.github.io/Hasil-TKA-Mumtaza/](https://smpmumtaza.github.io/Hasil-TKA-Mumtaza/)

## Fitur

- Cari data siswa berdasarkan NISN + Tanggal Lahir (format ddmmyyyy)
- Unduh PDF hasil TKA dari Google Drive — **semua client-side, tanpa backend server**
- Enkripsi AES-256-GCM — file ID tidak pernah terekspos
- Admin panel dengan CRUD data siswa, tahun ajaran, dan pengaturan label
- Rate limiting — 3 percobaan gagal → lockout 30 detik
- Download token — kedaluwarsa 60 detik

## Sistem Keamanan (Secure Download)

### Security Model

Setiap siswa memiliki file PDF di Google Drive. File ID Google Drive dienkripsi menggunakan **AES-256-GCM** dengan key yang diturunkan dari **NISN + tanggal lahir** siswa itu sendiri.

```
Key = PBKDF2(
    password  = NISN + ":" + ddmmyyyy,
    salt      = "mumtaza-tka-2026",
    iterations = 100000,
    hash      = SHA-256,
    length    = 32 bytes
)
```

**Artinya:** Seorang attacker yang mendownload `encrypted_map.json` dari GitHub tidak bisa mengakses PDF apapun tanpa mengetahui **NISN DAN tanggal lahir** siswa tertentu secara bersamaan.

### File Sensitif — JANGAN Pernah di-commit

| File | Isi | Wajib di-gitignore? |
|------|-----|---------------------|
| `drive_files.csv` | Mapping NISN → Google Drive File ID (PLAIN TEXT) | **YA** |
| `drive_files_*.csv` | Variasi/salinan file mapping | **YA** |
| `*.key` | Kunci enkripsi tidak sengaja tersimpan | **YA** |
| `.env` | Environment variables | **YA** |

File-file ini sudah ada di `.gitignore`. Verifikasi dengan:
```bash
git check-ignore drive_files.csv   # harus mengembalikan path file
```

### Cara Kerja

1. **Admin** membuat `drive_files.csv` berisi NISN dan Google Drive file ID (manual)
2. **Admin** menjalankan `generate_encrypted_map.py` → menghasilkan `docs/encrypted_map.json` dan `docs/student_index.json`
3. **File ID tidak pernah** muncul di source code, network request, browser DevTools, atau GitHub
4. **Siswa** membuka halaman, memasukkan NISN + tanggal lahir
5. Browser mendekripsi file ID di sisi klien menggunakan Web Crypto API
6. Download PDF dari Google Drive — file ID hanya ada di memory, expired 60 detik

### Menjalankan Enkripsi

```bash
# 1. Buat drive_files.csv (JANGAN di-commit!)
#    Format: NISN,drive_file_id
#    3111120517,1ABCxyzGoogleDriveID

# 2. Generate encrypted map
python generate_encrypted_map.py

# 3. Commit hasil enkripsi (hanya file JSON-nya!)
git add docs/encrypted_map.json docs/student_index.json
git commit -m "update encrypted map"
git push
```

### Verifikasi Mapping

```bash
# Lihat ringkasan
python tools/check_mapping.py

# Test dekripsi siswa tertentu
python tools/check_mapping.py --test --nisn 1234567890 --dob 01012010
```

Script verifikasi **tidak pernah** mencetak fileId ke console — hanya menampilkan "✓ fileId present".

### Keterbatasan

- **Google Drive "virus scan" warning**: File PDF > 25MB akan discan Google Drive dan mungkin menampilkan warning sebelum download. Solusi: pastikan file PDF < 25MB.
- **Drive sharing**: Setiap file PDF harus di-set ke "Anyone with the link" (public) agar bisa didownload siswa.
- **Client-side only**: Tidak ada logging server-side — tidak bisa melacak siapa yang mendownload.
- **Rate limiting local**: Rate limiting hanya berlaku per tab browser (sessionStorage). Bukan proteksi server-side.

### Rotasi Enkripsi

Jika ingin mengganti salt atau key:

1. Ubah `SALT` di `generate_encrypted_map.py`
2. Update juga `SALT` di `docs/index.html` (variabel `salt` di fungsi `deriveKey`)
3. Update `tools/check_mapping.py`
4. Generate ulang: `python generate_encrypted_map.py`
5. Deploy `docs/encrypted_map.json` dan `docs/index.html`

## Struktur File

```
├── docs/
│   ├── index.html                     # Aplikasi utama (single-page)
│   ├── encrypted_map.json             # [Auto-generated] File ID terenkripsi
│   ├── student_index.json             # [Auto-generated] Index nama siswa
│   ├── _headers                       # Security headers (Cloudflare Pages)
│   ├── .nojekyll                      # Force GitHub Pages tanpa Jekyll
│   ├── admin/
│   │   └── index.html                 # Admin panel (CRUD data siswa)
│   └── images/
│       ├── logo.png
│       ├── image1.jpg
│       └── image2.jpg
├── generate_encrypted_map.py          # Script enkripsi file ID
├── tools/
│   └── check_mapping.py               # Admin verification tool
├── .gitignore                         # Proteksi file sensitif
├── app.py                             # [Opsional] Flask backend
├── template.docx                      # Template DOCX asli
├── requirements.txt                   # Python dependencies
└── render.yaml                        # Render deploy config
```

## Tech Stack

- **Frontend:** Tailwind CSS + vanilla JS + Web Crypto API
- **Crypto:** PBKDF2 + AES-256-GCM (client-side, no library)
- **Storage:** Google Drive (PDF files)
- **Admin:** Supabase (CRUD data siswa & settings)
- **Hosting:** GitHub Pages

## Admin Panel

Login di `https://smpmumtaza.github.io/Hasil-TKA-Mumtaza/admin/`

| Fitur | Deskripsi |
|-------|-----------|
| Dashboard | Statistik download (Supabase) |
| Data Siswa | CRUD data, upload XLSX, export XLSX |
| Tahun Ajaran | Kelola tahun ajaran |
| Pengaturan | Edit label sistem (akronim, NISN, dll) + upload template DOCX |
