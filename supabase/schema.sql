-- شغّل هذا الملف مرة واحدة في Supabase: SQL Editor ← New query ← Run
-- وفعّل أيضاً: Authentication ← Providers ← Anonymous Sign-Ins (ON)
-- (ولتجربة التسجيل بالبريد بسهولة: Authentication ← Providers ← Email ← عطّل Confirm email)

create table if not exists user_data (
  user_id uuid primary key references auth.users(id) on delete cascade,
  data jsonb not null,
  updated_at timestamptz not null default now()
);

create table if not exists profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  name text not null,
  streak int not null default 0,
  used_pct int,
  updated_at timestamptz not null default now()
);

create table if not exists challenges (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  title text not null,
  kind text not null check (kind in ('no_spend','no_cat','limit')),
  cat text not null default '',
  limit_amount numeric not null default 0,
  days int not null check (days between 1 and 90),
  creator uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists challenge_members (
  challenge_id uuid not null references challenges(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  ok_days int not null default 0,
  joined_on date not null,
  primary key (challenge_id, user_id)
);

alter table user_data enable row level security;
alter table profiles enable row level security;
alter table challenges enable row level security;
alter table challenge_members enable row level security;

-- بياناتك المالية: لا يراها غيرك
create policy "own data all" on user_data for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- الترتيب العام: الجميع يقرأ، وأنت وحدك تكتب صفّك (اسم + أيام التزام + نسبة، بلا مبالغ)
create policy "profiles read" on profiles for select to authenticated using (true);
create policy "profiles write own" on profiles for insert to authenticated with check (auth.uid() = user_id);
create policy "profiles update own" on profiles for update to authenticated using (auth.uid() = user_id);
create policy "profiles delete own" on profiles for delete to authenticated using (auth.uid() = user_id);

-- التحديات: من يملك الرمز يصل إليها
create policy "challenges read" on challenges for select to authenticated using (true);
create policy "challenges create" on challenges for insert to authenticated with check (auth.uid() = creator);

create policy "members read" on challenge_members for select to authenticated using (true);
create policy "members join" on challenge_members for insert to authenticated with check (auth.uid() = user_id);
create policy "members update own" on challenge_members for update to authenticated using (auth.uid() = user_id);
