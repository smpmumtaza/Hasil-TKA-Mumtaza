begin;

create schema if not exists tka_private;
revoke all on schema tka_private from public, anon, authenticated;

create table if not exists tka_private.official_results (
  code_hash bytea primary key check (octet_length(code_hash) = 32),
  nisn text not null unique check (nisn ~ '^[0-9]{10}$'),
  nama text not null check (length(nama) between 1 and 200),
  tanggal_lahir date not null,
  matematika numeric not null check (matematika between 0 and 100),
  bahasa_indonesia numeric not null check (bahasa_indonesia between 0 and 100),
  matematika_predikat text not null,
  bahasa_indonesia_predikat text not null,
  drive_file_id text check (drive_file_id ~ '^[A-Za-z0-9_-]{10,200}$'),
  email_reserved_at timestamptz
);
alter table tka_private.official_results enable row level security;

create or replace function tka_private.matches_official(
  r tka_private.official_results, p_identity text, p_birth date, p_code text
)
returns boolean language sql stable set search_path = ''
as $$
  select p_code ~ '^[a-f0-9]{32}$'
    and r.code_hash = sha256(convert_to(p_code, 'UTF8'))
    and r.tanggal_lahir = p_birth
    and (r.nisn = trim(p_identity) or
      lower(regexp_replace(trim(r.nama), '[[:space:]]+', ' ', 'g')) =
      lower(regexp_replace(trim(p_identity), '[[:space:]]+', ' ', 'g')));
$$;

create or replace function public.find_tka_official(p_identity text, p_birth date, p_code text)
returns table(nama text, matematika numeric, bahasa_indonesia numeric,
  matematika_predikat text, bahasa_indonesia_predikat text, drive_file_id text)
language sql stable security definer set search_path = ''
as $$
  select r.nama, r.matematika, r.bahasa_indonesia,
    r.matematika_predikat, r.bahasa_indonesia_predikat, r.drive_file_id
  from tka_private.official_results r
  where r.code_hash = sha256(convert_to(p_code, 'UTF8'))
    and tka_private.matches_official(r, p_identity, p_birth, p_code);
$$;

create or replace function public.reserve_tka_official_email(p_identity text, p_birth date, p_code text)
returns table(nama text, matematika numeric, bahasa_indonesia numeric,
  matematika_predikat text, bahasa_indonesia_predikat text)
language sql security definer set search_path = ''
as $$
  update tka_private.official_results r
  set email_reserved_at = statement_timestamp()
  where r.code_hash = sha256(convert_to(p_code, 'UTF8'))
    and tka_private.matches_official(r, p_identity, p_birth, p_code)
    and (r.email_reserved_at is null or r.email_reserved_at < statement_timestamp() - interval '10 minutes')
  returning r.nama, r.matematika, r.bahasa_indonesia,
    r.matematika_predikat, r.bahasa_indonesia_predikat;
$$;

revoke all on function public.find_tka_official(text, date, text) from public, anon, authenticated;
grant execute on function public.find_tka_official(text, date, text) to anon, authenticated;
revoke all on function public.reserve_tka_official_email(text, date, text) from public, anon, authenticated;
grant execute on function public.reserve_tka_official_email(text, date, text) to service_role;

commit;
