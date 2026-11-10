-- ISMS 文件庫 | 在 Supabase SQL Editor 執行(可重複執行)
-- 架構沿用 clockin:前端純靜態、資料與檔案全在 Supabase、RLS 擋住匿名

-- ========== 管理員(與 clockin 共用同一張表,已存在則略過) ==========
create table if not exists public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade
);
alter table public.admins enable row level security;

create or replace function public.is_admin() returns boolean
language sql security definer stable set search_path = public as $$
  select exists (select 1 from public.admins where user_id = auth.uid())
$$;

-- ========== 資料表 ==========
-- 文件清單(只存 metadata;檔案本體放 Storage 的私有 bucket "isms")
create table if not exists public.isms_docs (
  code  text primary key check (code ~ '^IS-[BD]-[0-9]{2}(-[0-9]{2})?$'),
  title text not null,
  files jsonb not null default '{}'::jsonb,   -- {"word":"word/IS-D-01-01.docx","pdf":"pdf/IS-D-01-01.pdf"}
  updated_at timestamptz not null default now()
);

-- 可檢視名單(以 Email 比對;不在名單內即使有帳號也看不到)
create table if not exists public.isms_viewers (
  email text primary key check (email = lower(email)),
  note  text,
  created_at timestamptz not null default now()
);

alter table public.isms_docs    enable row level security;
alter table public.isms_viewers enable row level security;

create or replace function public.is_viewer() returns boolean
language sql security definer stable set search_path = public as $$
  select public.is_admin()
      or exists (select 1 from public.isms_viewers
                 where email = lower(coalesce(auth.jwt() ->> 'email', '')))
$$;

-- ========== 權限:匿名完全不能碰 ==========
revoke all on public.isms_docs, public.isms_viewers from anon, authenticated;
grant select, insert, update, delete on public.isms_docs, public.isms_viewers to authenticated;

drop policy if exists docs_read    on public.isms_docs;
drop policy if exists docs_admin   on public.isms_docs;
drop policy if exists viewers_admin on public.isms_viewers;
create policy docs_read  on public.isms_docs for select to authenticated using (public.is_viewer());
create policy docs_admin on public.isms_docs for all    to authenticated
  using (public.is_admin()) with check (public.is_admin());
create policy viewers_admin on public.isms_viewers for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

grant execute on function public.is_admin()  to authenticated;
grant execute on function public.is_viewer() to authenticated;

-- ========== 私有檔案庫 ==========
insert into storage.buckets (id, name, public, file_size_limit)
values ('isms', 'isms', false, 52428800)       -- 單檔上限 50 MB
on conflict (id) do update set public = false;

drop policy if exists isms_read   on storage.objects;
drop policy if exists isms_insert on storage.objects;
drop policy if exists isms_update on storage.objects;
drop policy if exists isms_delete on storage.objects;
create policy isms_read   on storage.objects for select to authenticated
  using (bucket_id = 'isms' and public.is_viewer());
create policy isms_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'isms' and public.is_admin());
create policy isms_update on storage.objects for update to authenticated
  using (bucket_id = 'isms' and public.is_admin());
create policy isms_delete on storage.objects for delete to authenticated
  using (bucket_id = 'isms' and public.is_admin());

-- ========== 設定管理員(信箱換成你在 Supabase Auth 建立的帳號) ==========
-- insert into public.admins (user_id) select id from auth.users where email = '你的信箱' on conflict do nothing;
