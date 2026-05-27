# Hasil-TKA-Mumtaza

Aplikasi web untuk melihat dan mencetak Hasil Tes Kemampuan Akademik (TKA) SMP Mumtaza.

**Live Demo:** [https://hasil-tka-mumtaza.onrender.com](https://hasil-tka-mumtaza.onrender.com)

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
- **PDF:** Microsoft Word (Windows) / LibreOffice (Linux)

## Cara Pakai (Lokal)

```bash
pip install -r requirements.txt
python app.py
```

Buka `http://localhost:5000` di browser.

## Deploy ke Production

### Opsi 1: Render (Gratis — Recommended)

1. Fork/clone repo ini ke GitHub
2. Login ke [render.com](https://render.com) dengan GitHub
3. **New + Web Service** → pilih repo `smpmumtaza/Hasil-TKA-Mumtaza`
4. Render akan otomatis mendeteksi `render.yaml` dan deploy
5. Aplikasi live di `https://hasil-tka-mumtaza.onrender.com`

### Opsi 2: PythonAnywhere

1. Upload file ke PythonAnywhere
2. Setup WSGI dengan Flask
3. Install LibreOffice untuk konversi PDF (`apt-get install libreoffice-writer`)

## GitHub Pages

Repo ini sudah dilengkapi GitHub Pages landing page di folder `docs/`.  
Untuk mengaktifkannya:

1. Buka repo → **Settings** → **Pages**
2. **Source**: Deploy from branch → `main` → `/docs`
3. URL: `https://smpmumtaza.github.io/Hasil-TKA-Mumtaza/`

Halaman ini berisi link ke aplikasi utama (Render).

## Struktur File

```
├── app.py                     # Flask app utama
├── requirements.txt           # Python dependencies
├── render.yaml                # Render auto-deploy config
├── template.docx              # Template DOCX dengan <<variable>>
├── Data TKA SMP Mumtaza.xlsx  # Database siswa
├── docs/
│   └── index.html             # GitHub Pages landing page
└── templates/
    └── index.html             # UI aplikasi (Tailwind CSS)
```

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/` | Halaman utama |
| POST | `/lookup` | Cari siswa (body: `nisn`, `date`) |
| POST | `/generate` | Generate PDF/DOCX (body: `nisn`, `date`) |
