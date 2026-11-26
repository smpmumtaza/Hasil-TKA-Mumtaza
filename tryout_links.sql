begin;
create table if not exists tka_private.tryout_birth_dates (
  code_hash bytea primary key references tka_private.tryout_results(code_hash) on delete cascade,
  tanggal_lahir date not null check (tanggal_lahir >= date '1900-01-01' and tanggal_lahir <= current_date)
);
alter table tka_private.tryout_birth_dates enable row level security;

create or replace function public.publish_tka_tryout_links(p_rows jsonb)
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
        nama text, nisn text, kelas text, tanggal_lahir date, bahasa_indonesia numeric,
        matematika numeric, rata_rata numeric, peringkat_sekolah integer, peringkat_total integer
      )
    ), inserted as (
      insert into tka_private.tryout_results
      select sha256(convert_to(r.kode, 'UTF8')), r.nama, r.nisn, r.kelas,
        r.bahasa_indonesia, r.matematika, r.rata_rata, r.peringkat_sekolah, r.peringkat_total
      from rows r
      returning code_hash
    )
    , births as (
      insert into tka_private.tryout_birth_dates
      select i.code_hash, r.tanggal_lahir
      from rows r join inserted i on i.code_hash = sha256(convert_to(r.kode, 'UTF8'))
      returning code_hash
    )
    select r.nama, r.nisn, r.kelas, r.kode
    from rows r join births b on b.code_hash = sha256(convert_to(r.kode, 'UTF8'))
    order by r.nama;
end;
$$;

create or replace function public.find_tka_tryout_link(p_identity text, p_birth date, p_code text)
returns table(nama text, kelas text, bahasa_indonesia numeric, matematika numeric,
  rata_rata numeric, peringkat_sekolah integer, peringkat_total integer)
language sql stable security definer set search_path = ''
as $$
  select r.nama, r.kelas, r.bahasa_indonesia, r.matematika,
    r.rata_rata, r.peringkat_sekolah, r.peringkat_total
  from tka_private.tryout_results r
  join tka_private.tryout_birth_dates b using (code_hash)
  cross join lateral (
    select lower(regexp_replace(trim(r.nama), '[[:space:]]+', ' ', 'g')) as nama,
      lower(regexp_replace(trim(p_identity), '[[:space:]]+', ' ', 'g')) as identitas
  ) n
  where p_code ~ '^[0-9a-f]{32}$'
    and r.code_hash = sha256(convert_to(p_code, 'UTF8'))
    and b.tanggal_lahir = p_birth
    and (n.identitas = n.nama or n.identitas = split_part(n.nama, ' ', 1));
$$;

revoke all on function public.publish_tka_tryout_links(jsonb) from public, anon, authenticated;
grant execute on function public.publish_tka_tryout_links(jsonb) to authenticated;
revoke all on function public.find_tka_tryout_link(text, date, text) from public, anon, authenticated;
grant execute on function public.find_tka_tryout_link(text, date, text) to anon, authenticated;
commit;
