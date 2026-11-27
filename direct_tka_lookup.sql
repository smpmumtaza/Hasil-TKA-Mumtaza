begin;

create table if not exists tka_private.lookup_quota (
  source_hash bytea primary key,
  minute_start timestamptz not null,
  attempts integer not null
);
alter table tka_private.lookup_quota enable row level security;
create index if not exists lookup_quota_minute on tka_private.lookup_quota(minute_start);

create or replace function tka_private.allow_lookup()
returns boolean language plpgsql set search_path = ''
as $$
declare
  headers jsonb := coalesce(nullif(current_setting('request.headers', true), ''), '{}')::jsonb;
  ip text := coalesce(nullif(headers ->> 'cf-connecting-ip', ''),
    nullif(trim(split_part(headers ->> 'x-forwarded-for', ',', 1)), ''), 'unknown');
  started timestamptz := date_trunc('minute', statement_timestamp());
  used integer;
begin
  delete from tka_private.lookup_quota where minute_start < started - interval '1 hour';
  insert into tka_private.lookup_quota as q (source_hash, minute_start, attempts)
  values (sha256(convert_to(ip, 'UTF8')), started, 1)
  on conflict (source_hash) do update
    set minute_start = excluded.minute_start,
        attempts = case when q.minute_start = excluded.minute_start then q.attempts + 1 else 1 end
    where q.minute_start <> excluded.minute_start or q.attempts < 30
  returning attempts into used;
  return used is not null;
end;
$$;

create or replace function tka_private.normalize_student_name(p_name text)
returns text language sql immutable set search_path = ''
as $$
  select lower(trim(regexp_replace(p_name, '[[:space:]]+', ' ', 'g')));
$$;

create or replace function public.find_tka_official_by_birth(p_identity text, p_birth date)
returns table(nama text, matematika numeric, bahasa_indonesia numeric,
  matematika_predikat text, bahasa_indonesia_predikat text)
language plpgsql security definer set search_path = ''
as $$
declare
  ident text := tka_private.normalize_student_name(p_identity);
begin
  if not tka_private.allow_lookup() then
    raise exception 'Terlalu banyak percobaan. Coba lagi dalam satu menit.' using errcode = 'PT429';
  end if;
  if ident is null or length(ident) not between 1 and 200 or p_birth is null then return; end if;
  return query
    with candidates as (
      select r.nama, r.matematika, r.bahasa_indonesia, r.matematika_predikat,
        r.bahasa_indonesia_predikat, count(*) over () as matches
      from tka_private.official_results r
      cross join lateral (select tka_private.normalize_student_name(r.nama) as n) normalized
      where r.tanggal_lahir = p_birth and (normalized.n = ident or split_part(normalized.n, ' ', 1) = ident)
    )
    select c.nama, c.matematika, c.bahasa_indonesia, c.matematika_predikat, c.bahasa_indonesia_predikat
    from candidates c where c.matches = 1;
end;
$$;

create or replace function public.find_tka_tryout_by_birth(p_identity text, p_birth date)
returns table(nama text, kelas text, bahasa_indonesia numeric, matematika numeric,
  rata_rata numeric, peringkat_sekolah integer, peringkat_total integer)
language plpgsql security definer set search_path = ''
as $$
declare
  ident text := tka_private.normalize_student_name(p_identity);
begin
  if not tka_private.allow_lookup() then
    raise exception 'Terlalu banyak percobaan. Coba lagi dalam satu menit.' using errcode = 'PT429';
  end if;
  if ident is null or length(ident) not between 1 and 200 or p_birth is null then return; end if;
  return query
    with candidates as (
      select r.nama, r.kelas, r.bahasa_indonesia, r.matematika, r.rata_rata,
        r.peringkat_sekolah, r.peringkat_total, count(*) over () as matches
      from tka_private.tryout_results r
      join tka_private.tryout_birth_dates b using (code_hash)
      cross join lateral (select tka_private.normalize_student_name(r.nama) as n) normalized
      where b.tanggal_lahir = p_birth and (normalized.n = ident or split_part(normalized.n, ' ', 1) = ident)
    )
    select c.nama, c.kelas, c.bahasa_indonesia, c.matematika, c.rata_rata, c.peringkat_sekolah, c.peringkat_total
    from candidates c where c.matches = 1;
end;
$$;

revoke all on function public.find_tka_official_by_birth(text,date) from public, anon, authenticated;
revoke all on function public.find_tka_tryout_by_birth(text,date) from public, anon, authenticated;
grant execute on function public.find_tka_official_by_birth(text,date) to anon, authenticated;
grant execute on function public.find_tka_tryout_by_birth(text,date) to anon, authenticated;

commit;
