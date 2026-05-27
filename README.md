# Hasil-TKA-Mumtaza

Aplikasi web untuk melihat dan mencetak Hasil Tes Kemampuan Akademik (TKA) SMP Mumtaza.

## Fitur

- Cari data siswa berdasarkan NISN dan Tanggal Lahir (ddmmyyyy)
- Tampilkan hasil nilai Matematika dan Bahasa Indonesia
- Preview PDF langsung dari template DOCX
- Download file DOCX hasil isian
- Responsive (Tailwind CSS) — mobile & desktop

## Tech Stack

- **Backend:** Python Flask
- **Frontend:** Tailwind CSS (CDN)
- **Template:** DOCX (python-docx)
- **PDF:** Microsoft Word (win32com) — Windows / LibreOffice — Linux

## Cara Pakai (Lokal)

```bash
pip install -r requirements.txt
python app.py
```

Buka `http://localhost:5000` di browser.

## Deploy ke Production

> **Catatan:** Karena aplikasi ini menggunakan Python backend, **GitHub Pages tidak dapat digunakan** (hanya untuk static site).

### Opsi 1: Render (Gratis & Mudah)

1. Push repo ini ke GitHub
2. Login ke [render.com](https://render.com)
3. Pilih **New + Web Service** → hubungkan GitHub repo
4. Render akan otomatis mendeteksi `render.yaml` dan deploy
5. Aplikasi akan live di `https://hasil-tka.onrender.com`

### Opsi 2: PythonAnywhere

1. Upload file ke PythonAnywhere
2. Setup WSGI dengan Flask
3. Install LibreOffice untuk konversi PDF

## Struktur File

```
├── app.py                  # Flask app utama
├── requirements.txt        # Python dependencies
├── render.yaml             # Render deployment config
├── template.docx           # Template DOCX dengan <<variable>>
├── Data TKA SMP Mumtaza.xlsx  # Database siswa
└── templates/
    └── index.html          # UI dengan Tailwind CSS
```
