begin;

create table if not exists tka_private.tryout_pdf_manifest (
  nisn text primary key check (nisn ~ '^[0-9]{10}$'),
  nama text not null,
  kelas text not null,
  tanggal_lahir date not null,
  bahasa_indonesia numeric not null,
  matematika numeric not null,
  drive_file_id text not null unique check (drive_file_id ~ '^[A-Za-z0-9_-]{10,200}$')
);
alter table tka_private.tryout_pdf_manifest enable row level security;

create or replace function public.find_tka_tryout_with_pdf(p_identity text, p_birth date, p_code text default null)
returns table(nama text, kelas text, bahasa_indonesia numeric, matematika numeric, rata_rata numeric,
  peringkat_sekolah integer, peringkat_total integer, drive_file_id text)
language sql security definer set search_path = ''
as $$
  with found as materialized (
    select f.* from public.find_tka_tryout_by_birth(p_identity, p_birth) f where p_code is null
    union all
    select f.* from public.find_tka_tryout_link(p_identity, p_birth, p_code) f where p_code is not null
  )
  select f.nama, f.kelas, f.bahasa_indonesia, f.matematika, f.rata_rata,
    f.peringkat_sekolah, f.peringkat_total, m.drive_file_id
  from found f
  left join lateral (
    select min(p.drive_file_id) as drive_file_id
    from tka_private.tryout_pdf_manifest p
    join tka_private.tryout_results r using (nisn)
    join tka_private.tryout_birth_dates b on b.code_hash = r.code_hash
    where b.tanggal_lahir = p_birth and p.tanggal_lahir = p_birth
      and p.nama = r.nama and r.nama = f.nama
      and p.kelas = r.kelas and r.kelas = f.kelas
      and p.bahasa_indonesia = r.bahasa_indonesia and r.bahasa_indonesia = f.bahasa_indonesia
      and p.matematika = r.matematika and r.matematika = f.matematika
      and (p_code is null or r.code_hash = sha256(convert_to(p_code,'UTF8')))
    having count(*) = 1
  ) m on true;
$$;

revoke all on function public.find_tka_tryout_with_pdf(text,date,text) from public, anon, authenticated;
grant execute on function public.find_tka_tryout_with_pdf(text,date,text) to anon, authenticated;

commit;
