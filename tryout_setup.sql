-- Jalankan file ini di SQL Editor proyek Supabase sekolah.
-- Undang akun admin sekolah melalui Authentication > Users.
-- Di SQL Editor, tetapkan izin akun yang sudah dibuat:
-- update auth.users
-- set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) || '{"tka_admin":true}'::jsonb
-- where email = 'EMAIL_ADMIN_SEKOLAH';
-- Admin masuk di halaman tryout.html#admin, unggah XLSX, lalu unduh daftar kode pribadi.
-- Simpan daftar kode secara privat. Unggahan baru mengganti hasil aktif dan kode.
begin;

create schema if not exists tka_private;
revoke all on schema tka_private from public, anon, authenticated;

create table if not exists tka_private.tryout_results (
  code_hash bytea primary key,
  nama text not null check (length(nama) between 1 and 200),
  nisn text check (nisn ~ '^[0-9]{10}$'),
  kelas text check (length(kelas) <= 40),
  bahasa_indonesia numeric not null check (bahasa_indonesia between 0 and 100),
  matematika numeric not null check (matematika between 0 and 100),
  rata_rata numeric not null check (rata_rata between 0 and 100),
  peringkat_sekolah integer check (peringkat_sekolah > 0),
  peringkat_total integer check (peringkat_total > 0)
);
alter table tka_private.tryout_results enable row level security;
create unique index if not exists tryout_results_nisn
  on tka_private.tryout_results (nisn) where nisn is not null;

create or replace function public.publish_tka_tryout(p_rows jsonb)
returns table(nama text, nisn text, kelas text, kode text)
language plpgsql security definer set search_path = ''
as $$
begin
  if auth.uid() is null or (auth.jwt() -> 'app_metadata' ->> 'tka_admin') is distinct from 'true' then
    raise exception 'Akses admin diperlukan' using errcode = '42501';
  end if;
  if p_rows is null or jsonb_typeof(p_rows) <> 'array' then
    raise exception 'Data unggahan tidak valid';
  end if;
  if jsonb_array_length(p_rows) not between 1 and 2000 then
    raise exception 'Unggah 1 sampai 2000 siswa';
  end if;

  lock table tka_private.tryout_results in share row exclusive mode;
  delete from tka_private.tryout_results;
  return query
    with rows as materialized (
      select r.*, replace(gen_random_uuid()::text, '-', '') as kode
      from jsonb_to_recordset(p_rows) as r(
        nama text, nisn text, kelas text, bahasa_indonesia numeric,
        matematika numeric, rata_rata numeric, peringkat_sekolah integer, peringkat_total integer
      )
    ), inserted as (
      insert into tka_private.tryout_results
      select sha256(convert_to(r.kode, 'UTF8')), r.nama, r.nisn, r.kelas,
        r.bahasa_indonesia, r.matematika, r.rata_rata, r.peringkat_sekolah, r.peringkat_total
      from rows r
      returning code_hash
    )
    select r.nama, r.nisn, r.kelas, r.kode
    from rows r join inserted i on i.code_hash = sha256(convert_to(r.kode, 'UTF8'))
    order by r.nama;
end;
$$;

create or replace function public.find_tka_tryout(p_identity text, p_code text)
returns table(nama text, kelas text, bahasa_indonesia numeric, matematika numeric,
  rata_rata numeric, peringkat_sekolah integer, peringkat_total integer)
language sql security definer set search_path = ''
as $$
  select r.nama, r.kelas, r.bahasa_indonesia, r.matematika,
    r.rata_rata, r.peringkat_sekolah, r.peringkat_total
  from tka_private.tryout_results r
  where p_code ~ '^[0-9a-f]{32}$'
    and r.code_hash = sha256(convert_to(p_code, 'UTF8'))
    and (r.nisn = p_identity or
      lower(regexp_replace(trim(r.nama), '[[:space:]]+', ' ', 'g')) =
      lower(regexp_replace(trim(p_identity), '[[:space:]]+', ' ', 'g')));
$$;

revoke all on function public.publish_tka_tryout(jsonb) from public, anon, authenticated;
revoke all on function public.find_tka_tryout(text, text) from public, anon, authenticated;
grant execute on function public.publish_tka_tryout(jsonb) to authenticated;
grant execute on function public.find_tka_tryout(text, text) to anon, authenticated;

commit;
