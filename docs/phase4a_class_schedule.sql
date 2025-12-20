-- Phase 4A: Read-only class schedule (members)
--
-- Creates: public.class_schedule
-- RLS: SELECT-only for authenticated users

create table if not exists public.class_schedule (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  start_time timestamptz not null,
  end_time timestamptz not null,
  instructor text null,
  category text null,
  created_at timestamptz default now()
);

alter table public.class_schedule enable row level security;

drop policy if exists "Authenticated can read class schedule" on public.class_schedule;
create policy "Authenticated can read class schedule"
on public.class_schedule
for select
to authenticated
using (true);

-- Intentionally no insert/update/delete policies (client must be read-only).
