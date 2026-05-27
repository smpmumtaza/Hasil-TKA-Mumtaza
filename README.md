# Hasil-TKA-Mumtaza

Aplikasi web untuk melihat dan mencetak Hasil Tes Kemampuan Akademik (TKA) SMP Mumtaza.

**Live:** [https://smpmumtaza.github.io/Hasil-TKA-Mumtaza/](https://smpmumtaza.github.io/Hasil-TKA-Mumtaza/)

## Fitur

- Cari data siswa berdasarkan NISN + Tanggal Lahir (format ddmmyyyy)
- Tampilkan nilai Matematika & Bahasa Indonesia
- Preview dan download PDF — **semua client-side, tanpa backend server**

## Cara Pakai

Buka [https://smpmumtaza.github.io/Hasil-TKA-Mumtaza/](https://smpmumtaza.github.io/Hasil-TKA-Mumtaza/) langsung di browser.

Atau jalankan lokal dengan server statis:
```bash
python -m http.server 8000 --directory docs
```
Lalu buka `http://localhost:8000`.

## Tech Stack

- **Frontend:** Tailwind CSS + vanilla JS
- **Spreadsheet:** SheetJS (XLSX parse client-side)
- **PDF:** html2pdf.js (render HTML template ke PDF via browser)
- **Hosting:** GitHub Pages

## Struktur File

```
├── docs/
│   ├── index.html                     # Aplikasi utama (single-page)
│   ├── Data TKA SMP Mumtaza.xlsx      # Database siswa
│   └── .nojekyll                      # Force GitHub Pages tanpa Jekyll
├── app.py                             # [Opsional] Flask backend
├── template.docx                      # Template DOCX asli
├── requirements.txt                   # Python dependencies
└── render.yaml                        # Render deploy config
```

## API Endpoints (Flask Backend)

Jika ingin menjalankan dengan backend Python (untuk konversi DOCX asli ke PDF):

```bash
pip install -r requirements.txt
python app.py
# Buka http://localhost:5000
```

| Method | Path | Deskripsi |
|--------|------|-----------|
| GET | `/` | Halaman utama |
| POST | `/lookup` | Cari siswa (body: `nisn`, `date`) |
| POST | `/generate` | Generate PDF dari DOCX (body: `nisn`, `date`) |
