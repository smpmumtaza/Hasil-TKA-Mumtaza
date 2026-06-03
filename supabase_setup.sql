-- Jalankan SQL ini di Supabase SQL Editor (https://supabase.com/dashboard/project/skiraowhzwtdcidnhply/sql/new)

-- Table siswa
CREATE TABLE IF NOT EXISTS siswa (
  id BIGSERIAL PRIMARY KEY,
  nomor_peserta TEXT DEFAULT '',
  nisn TEXT NOT NULL DEFAULT '',
  ddmmyyyy TEXT DEFAULT '',
  nama TEXT DEFAULT '',
  matematika_score NUMERIC DEFAULT NULL,
  matematika_rating TEXT DEFAULT '',
  bahasa_indonesia_score NUMERIC DEFAULT NULL,
  bahasa_indonesia_rating TEXT DEFAULT '',
  tahun_ajaran TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table tahun_ajaran
CREATE TABLE IF NOT EXISTS tahun_ajaran (
  id BIGSERIAL PRIMARY KEY,
  nama TEXT NOT NULL UNIQUE,
  is_default BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index
CREATE INDEX IF NOT EXISTS idx_siswa_nisn ON siswa(nisn);
CREATE INDEX IF NOT EXISTS idx_siswa_tahun ON siswa(tahun_ajaran);

-- Row Level Security (allow anon access for admin panel)
ALTER TABLE siswa ENABLE ROW LEVEL SECURITY;
ALTER TABLE tahun_ajaran ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all on siswa" ON siswa;
CREATE POLICY "Allow all on siswa" ON siswa FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all on tahun_ajaran" ON tahun_ajaran;
CREATE POLICY "Allow all on tahun_ajaran" ON tahun_ajaran FOR ALL USING (true) WITH CHECK (true);

-- Seed default tahun ajaran
INSERT INTO tahun_ajaran (nama, is_default) VALUES ('2024/2025', false) ON CONFLICT (nama) DO NOTHING;
INSERT INTO tahun_ajaran (nama, is_default) VALUES ('2025/2026', true) ON CONFLICT (nama) DO NOTHING;
INSERT INTO tahun_ajaran (nama, is_default) VALUES ('2026/2027', false) ON CONFLICT (nama) DO NOTHING;

-- Table settings for system-wide configurable labels
CREATE TABLE IF NOT EXISTS settings (
  id BIGSERIAL PRIMARY KEY,
  key TEXT NOT NULL UNIQUE,
  value TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all on settings" ON settings;
CREATE POLICY "Allow all on settings" ON settings FOR ALL USING (true) WITH CHECK (true);

-- Default settings
INSERT INTO settings (key, value) VALUES ('app_acronym', 'TKA') ON CONFLICT (key) DO NOTHING;
INSERT INTO settings (key, value) VALUES ('app_subtitle', 'Hasil Tes Kemampuan Akademik') ON CONFLICT (key) DO NOTHING;
INSERT INTO settings (key, value) VALUES ('app_title', 'Sistem Hasil TKA SMP Mumtaza') ON CONFLICT (key) DO NOTHING;
INSERT INTO settings (key, value) VALUES ('nisn_label', 'NISN') ON CONFLICT (key) DO NOTHING;
INSERT INTO settings (key, value) VALUES ('ttl_label', 'Tanggal Lahir') ON CONFLICT (key) DO NOTHING;
INSERT INTO settings (key, value) VALUES ('no_peserta_label', 'Nomor Peserta') ON CONFLICT (key) DO NOTHING;
INSERT INTO settings (key, value) VALUES ('template_variables', '{}') ON CONFLICT (key) DO NOTHING;
