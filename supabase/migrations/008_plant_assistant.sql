-- 008: usage log for the customer-facing plant assistant (edge function plant-assistant).
-- One row per assistant call. Only the edge function (service role) reads or writes it;
-- there are deliberately no policies, so the app itself cannot touch it.

create table if not exists ai_assistant_calls (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  has_image   boolean not null default false,
  created_at  timestamptz not null default now()
);

create index if not exists ai_assistant_calls_user_time on ai_assistant_calls (user_id, created_at);

alter table ai_assistant_calls enable row level security;
