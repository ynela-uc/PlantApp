-- 019: real ratings from customers.
--
--   * ratings: one per delivered order, 1 to 5 stars and an optional comment (max 300 characters), written only through
--     rate_order() by the customer of that order. The reviewer's first name and last initial are stored with it.
--   * sellers.rating (average, one decimal) and sellers.rating_count are kept up to date by a trigger. The old rating values
--     were demo data, so they are reset to 0. Apps and shop owners cannot change these two columns themselves.
--   * Ratings of visible (approved) shops can be read by everyone signed in; the owner sees their own shop's ratings.
--   * The customer gets a push when an order is delivered ("How was your order?").
--   * Deleting a customer account removes the name from their ratings (the rating itself stays).
-- Apps show "New" instead of stars until a shop has 3 ratings.

alter table sellers add column if not exists rating_count integer not null default 0;
update sellers set rating = 0, rating_count = 0;

create table if not exists ratings (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references orders(id) on delete cascade,
  seller_id uuid not null references sellers(id) on delete cascade,
  buyer_id uuid references auth.users(id) on delete set null,
  stars smallint not null check (stars between 1 and 5),
  comment text check (comment is null or char_length(comment) <= 300),
  reviewer_name text not null default '',
  created_at timestamptz not null default now()
);
create index if not exists ratings_seller_idx on ratings (seller_id, created_at desc);
alter table ratings enable row level security;

drop policy if exists "Ratings of visible shops can be read" on ratings;
create policy "Ratings of visible shops can be read" on ratings
  for select using (
    exists (select 1 from sellers s where s.id = ratings.seller_id and (s.approved or s.owner_id = auth.uid()))
  );

-- ------------------------------------------------------------ writing a rating
create or replace function public.rate_order(p_order_id uuid, p_stars integer, p_comment text default null) returns void
language plpgsql security definer set search_path = public
as $$
declare
  o orders%rowtype;
  p profiles%rowtype;
  who text;
begin
  select * into o from orders where id = p_order_id;
  if not found then raise exception 'order not found'; end if;
  if o.buyer_id is distinct from auth.uid() then raise exception 'not your order'; end if;
  if o.status <> 'delivered' then raise exception 'not delivered'; end if;
  if p_stars is null or p_stars not between 1 and 5 then raise exception 'invalid stars'; end if;
  if exists (select 1 from ratings where order_id = p_order_id) then raise exception 'already rated'; end if;
  select * into p from profiles where id = auth.uid();
  who := trim(coalesce(p.first_name, '') || case when coalesce(p.last_name, '') <> '' then ' ' || left(p.last_name, 1) || '.' else '' end);
  insert into ratings (order_id, seller_id, buyer_id, stars, comment, reviewer_name)
  values (p_order_id, o.seller_id, auth.uid(), p_stars, nullif(left(trim(coalesce(p_comment, '')), 300), ''), who);
end;
$$;

revoke all on function public.rate_order(uuid, integer, text) from public, anon;
grant execute on function public.rate_order(uuid, integer, text) to authenticated;

-- ------------------------------------------------------------ shop averages
create or replace function public.ratings_refresh() returns trigger
language plpgsql security definer set search_path = public
as $$
declare sid uuid := coalesce(new.seller_id, old.seller_id);
begin
  perform set_config('app.rating_update', 'on', true);
  update sellers set
    rating = coalesce((select round(avg(stars)::numeric, 1) from ratings where seller_id = sid), 0),
    rating_count = (select count(*) from ratings where seller_id = sid)
  where id = sid;
  perform set_config('app.rating_update', 'off', true);
  return null;
end;
$$;

drop trigger if exists ratings_refresh on ratings;
create trigger ratings_refresh
  after insert or delete on ratings
  for each row execute function public.ratings_refresh();

-- shop owners and apps must not edit their own rating or approval
create or replace function public.sellers_guard_approval() returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if coalesce(auth.role(), 'service_role') = 'authenticated' then
    if tg_op = 'INSERT' then
      new.approved := false;
      new.approved_at := null;
      new.rating := 0;
      new.rating_count := 0;
    else
      if coalesce(current_setting('app.deleting_account', true), '') <> 'on' then
        new.approved := old.approved;
        new.approved_at := old.approved_at;
      end if;
      if coalesce(current_setting('app.rating_update', true), '') <> 'on' then
        new.rating := old.rating;
        new.rating_count := old.rating_count;
      end if;
    end if;
  end if;
  return new;
end;
$$;

-- ------------------------------------------------------------ push on delivery
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
    elsif new.status = 'delivered' then
      perform push_event('order_delivered', new.id);
    elsif new.status = 'cancelled' then
      if new.cancelled_by = 'customer' then
        perform push_event('customer_cancelled', new.id);
      elsif new.cancelled_by = 'system' then
        perform push_event('order_expired', new.id);
      elsif old.status = 'out_for_delivery' then
        perform push_event('delivery_failed', new.id);
      else
        perform push_event('order_cancelled', new.id);
      end if;
    elsif new.status = 'approved' and old.status = 'photo_sent' and auth.uid() = new.buyer_id then
      perform push_event('photo_approved', new.id);
    elsif new.status = 'preparing' and old.status = 'photo_sent' and auth.uid() = new.buyer_id then
      perform push_event('photo_change', new.id);
    end if;
  end if;
  return null;
end;
$$;

-- ------------------------------------------------------------ deleting an account: remove the name from ratings
create or replace function public.delete_my_account() returns void
language plpgsql security definer set search_path = public
as $$
declare
  uid uuid := auth.uid();
  my_shops uuid[];
begin
  if uid is null then raise exception 'not signed in'; end if;

  select coalesce(array_agg(id), '{}') into my_shops from sellers where owner_id = uid;

  if exists (
    select 1 from orders
    where status in ('preparing', 'photo_sent', 'approved', 'out_for_delivery')
      and (buyer_id = uid or seller_id = any(my_shops))
  ) then
    raise exception 'open_orders';
  end if;

  update orders set
    status = 'cancelled',
    cancel_reason = case when buyer_id = uid then 'customer_cancelled' else 'other' end,
    cancelled_by = case when buyer_id = uid then 'customer' else 'shop' end,
    cancelled_at = now()
  where status = 'placed' and (buyer_id = uid or seller_id = any(my_shops));

  update orders set
    buyer_name = '', buyer_phone = '', address = '',
    recipient_name = null, recipient_phone = null, gift_note = null
  where buyer_id = uid;

  update ratings set reviewer_name = '' where buyer_id = uid;

  perform set_config('app.deleting_account', 'on', true);
  delete from listings where seller_id = any(my_shops);
  update sellers set owner_id = null, approved = false, name = 'Deleted shop', phone = '', bio = '', delivers_to = null
  where id = any(my_shops);

  delete from profiles where id = uid;
  delete from auth.users where id = uid;
end;
$$;
