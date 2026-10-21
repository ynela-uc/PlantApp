-- 016: shops must be approved before customers can see them.
--
--   * sellers.approved (default false). Shops that exist today are approved.
--   * Customers (and everyone else) only see approved shops and their products; the owner always sees their own shop.
--   * A shop owner can never approve themselves: the apps' requests cannot change `approved` (new shops always start unapproved);
--     only the SQL editor / Table Editor / service role can.
--   * Orders can only be placed with approved shops.
--   * The admin gets a push when a new shop signs up (internal_config 'admin_user_id'), and the shop owner gets one when approved.
--
-- To approve a shop: Supabase -> Table Editor -> sellers -> tick `approved` (or: update sellers set approved = true where id = '...').

alter table sellers add column if not exists approved boolean not null default false;
alter table sellers add column if not exists approved_at timestamptz;
update sellers set approved = true, approved_at = now() where not approved;

-- ------------------------------------------------------------ who can see what
drop policy if exists "Anyone can view sellers" on sellers;
drop policy if exists "Approved shops are visible, owners see their own" on sellers;
create policy "Approved shops are visible, owners see their own" on sellers
  for select using (approved or owner_id = auth.uid());

drop policy if exists "Anyone can view listings" on listings;
drop policy if exists "Listings of approved shops are visible, owners see their own" on listings;
create policy "Listings of approved shops are visible, owners see their own" on listings
  for select using (
    exists (select 1 from sellers s where s.id = listings.seller_id and (s.approved or s.owner_id = auth.uid()))
  );

-- ------------------------------------------------------------ nobody approves themselves
create or replace function public.sellers_guard_approval() returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if coalesce(auth.role(), 'service_role') = 'authenticated' then
    if tg_op = 'INSERT' then
      new.approved := false;
      new.approved_at := null;
    else
      new.approved := old.approved;
      new.approved_at := old.approved_at;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists sellers_guard_approval on sellers;
create trigger sellers_guard_approval
  before insert or update on sellers
  for each row execute function public.sellers_guard_approval();

-- ------------------------------------------------------------ no orders with a shop that is not approved
create or replace function public.orders_require_approved_shop() returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if coalesce(auth.role(), 'service_role') = 'authenticated'
     and not exists (select 1 from sellers where id = new.seller_id and approved) then
    raise exception 'unavailable';
  end if;
  return new;
end;
$$;

drop trigger if exists orders_require_approved_shop on orders;
create trigger orders_require_approved_shop
  before insert on orders
  for each row execute function public.orders_require_approved_shop();

-- ------------------------------------------------------------ push to the admin (new shop) and the owner (approved)
create or replace function public.push_shop_event(p_event text, p_seller_id uuid) returns void
language plpgsql security definer set search_path = public
as $$
declare secret text;
begin
  select value into secret from internal_config where key = 'notify_secret';
  if secret is null then return; end if;
  perform net.http_post(
    url := 'https://uspzexcaiwavtpbfskta.supabase.co/functions/v1/notify',
    body := jsonb_build_object('event', p_event, 'seller_id', p_seller_id),
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-notify-secret', secret)
  );
exception when others then
  null;
end;
$$;

create or replace function public.sellers_push_events() returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if tg_op = 'INSERT' and not new.approved and new.owner_id is not null then
    perform push_shop_event('new_shop', new.id);
  elsif tg_op = 'UPDATE' and new.approved and not old.approved then
    perform push_shop_event('shop_approved', new.id);
  end if;
  return null;
end;
$$;

drop trigger if exists sellers_push_events on sellers;
create trigger sellers_push_events
  after insert or update of approved on sellers
  for each row execute function public.sellers_push_events();
