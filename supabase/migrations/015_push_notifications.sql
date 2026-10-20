-- 015: push notifications (new orders for shops, photo and delivery updates for customers, a reminder after 10 minutes).
--
-- How it works: a trigger on `orders` calls the `notify` edge function (through pg_net) with the event and the order id.
-- The function looks up who should hear about it and sends a Firebase Cloud Messaging push to their devices.
-- Devices are stored in `device_tokens`, written only through the two functions below.
-- Setup that is NOT in this file (secrets): the `notify_secret` row in internal_config, and the NOTIFY_SECRET and
-- FCM_SERVICE_ACCOUNT secrets of the edge function. See docs/push-setup.md.

create extension if not exists pg_net;
create extension if not exists pg_cron;

-- ------------------------------------------------------------ devices
create table if not exists device_tokens (
  token text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null check (platform in ('android', 'ios')),
  language text not null default 'ar' check (language in ('ar', 'ckb', 'en')),
  updated_at timestamptz not null default now()
);
create index if not exists device_tokens_user_idx on device_tokens (user_id);
alter table device_tokens enable row level security; -- no policies: only the functions below and the service role

create or replace function public.register_device_token(
  p_token text, p_platform text, p_language text default 'ar'
) returns void
language plpgsql security definer set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if coalesce(p_token, '') = '' or length(p_token) > 4096 then raise exception 'bad token'; end if;
  insert into device_tokens (token, user_id, platform, language, updated_at)
  values (
    p_token, auth.uid(),
    case when p_platform = 'ios' then 'ios' else 'android' end,
    case when p_language in ('ar', 'ckb', 'en') then p_language else 'ar' end,
    now()
  )
  on conflict (token) do update
    set user_id = excluded.user_id, platform = excluded.platform, language = excluded.language, updated_at = now();
end;
$$;

create or replace function public.unregister_device_token(p_token text) returns void
language plpgsql security definer set search_path = public
as $$
begin
  delete from device_tokens where token = p_token and user_id = auth.uid();
end;
$$;

revoke all on function public.register_device_token(text, text, text) from public, anon;
revoke all on function public.unregister_device_token(text) from public, anon;
grant execute on function public.register_device_token(text, text, text) to authenticated;
grant execute on function public.unregister_device_token(text) to authenticated;

-- ------------------------------------------------------------ private settings (no policies: server only)
create table if not exists internal_config (key text primary key, value text not null);
alter table internal_config enable row level security;

-- ------------------------------------------------------------ sending
alter table orders add column if not exists reminder_sent_at timestamptz;

create or replace function public.push_event(p_event text, p_order_id uuid) returns void
language plpgsql security definer set search_path = public
as $$
declare secret text;
begin
  select value into secret from internal_config where key = 'notify_secret';
  if secret is null then return; end if;
  perform net.http_post(
    url := 'https://uspzexcaiwavtpbfskta.supabase.co/functions/v1/notify',
    body := jsonb_build_object('event', p_event, 'order_id', p_order_id),
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-notify-secret', secret)
  );
exception when others then
  null; -- a failed push must never block an order
end;
$$;

create or replace function public.orders_push_events() returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    perform push_event('new_order', new.id);
  elsif new.status is distinct from old.status then
    if new.status = 'photo_sent' then
      perform push_event('photo_ready', new.id);
    elsif new.status = 'out_for_delivery' then
      perform push_event('out_for_delivery', new.id);
    elsif new.status = 'cancelled' then
      perform push_event('order_cancelled', new.id);
    elsif new.status = 'approved' and old.status = 'photo_sent' and auth.uid() = new.buyer_id then
      perform push_event('photo_approved', new.id);
    elsif new.status = 'preparing' and old.status = 'photo_sent' and auth.uid() = new.buyer_id then
      perform push_event('photo_change', new.id);
    end if;
  end if;
  return null;
end;
$$;

drop trigger if exists orders_push_events on orders;
create trigger orders_push_events
  after insert or update of status on orders
  for each row execute function public.orders_push_events();

-- ------------------------------------------------------------ reminder: a new order nobody opened for 10 minutes
create or replace function public.send_order_reminders() returns void
language plpgsql security definer set search_path = public
as $$
declare r record;
begin
  for r in
    select id from orders
    where status = 'placed' and reminder_sent_at is null
      and created_at < now() - interval '10 minutes' and created_at > now() - interval '12 hours'
  loop
    update orders set reminder_sent_at = now() where id = r.id;
    perform push_event('order_reminder', r.id);
  end loop;
end;
$$;

select cron.schedule('order-reminders', '* * * * *', 'select public.send_order_reminders()');
