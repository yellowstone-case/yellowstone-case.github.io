-- قضية حديقة يلوستون الوطنية: جدول الفرق
-- الصقي هذا كله في Supabase > SQL Editor ثم اضغطي Run مرة وحدة.

create extension if not exists pgcrypto;

create table if not exists public.teams (
  id          uuid primary key default gen_random_uuid(),
  secret      uuid not null default gen_random_uuid(),
  name        text not null check (char_length(name) between 1 and 40),
  score       int  not null default 0 check (score between 0 and 100),
  step        int  not null default 0 check (step between 0 and 20),
  finished    boolean not null default false,
  choice      text check (choice is null or char_length(choice) <= 20),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- لا أحد يقرأ أو يكتب الجدول مباشرة؛ كل شيء يمر عبر الدوال تحت
alter table public.teams enable row level security;
revoke all on public.teams from anon, authenticated;

-- تسجيل فريق جديد: يرجّع رقم الفريق ورمزه السري (يبقى في جهاز الفريق فقط)
create or replace function public.register_team(p_name text)
returns table (id uuid, secret uuid)
language sql security definer set search_path = public as $$
  insert into public.teams (name) values (left(trim(p_name), 40))
  returning teams.id, teams.secret;
$$;

-- تحديث نقاط الفريق ومرحلته (لا يقبل إلا من يملك الرمز السري)
create or replace function public.update_team(
  p_id uuid, p_secret uuid, p_score int, p_step int, p_finished boolean, p_choice text default null)
returns void
language sql security definer set search_path = public as $$
  update public.teams
     set score = greatest(0, least(100, p_score)),
         step = greatest(0, least(20, p_step)),
         finished = p_finished,
         choice = left(p_choice, 20),
         updated_at = now()
   where id = p_id and secret = p_secret;
$$;

-- قراءة الترتيب (بدون الرموز السرية)
create or replace function public.get_board(p_since timestamptz default now() - interval '1 day')
returns table (id uuid, name text, score int, step int, finished boolean, created_at timestamptz, updated_at timestamptz)
language sql stable security definer set search_path = public as $$
  select t.id, t.name, t.score, t.step, t.finished, t.created_at, t.updated_at
    from public.teams t
   where t.created_at >= p_since
   order by t.score desc, t.updated_at asc
   limit 300;
$$;

grant execute on function public.register_team(text) to anon;
grant execute on function public.update_team(uuid, uuid, int, int, boolean, text) to anon;
grant execute on function public.get_board(timestamptz) to anon;
