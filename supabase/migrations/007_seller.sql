-- 007: seller side — photo storage, safe order-status functions, AI usage log
-- Run once in Supabase Dashboard -> SQL Editor.

-- ---------------------------------------------------------------- storage
insert into storage.buckets (id, name, public) values
  ('plant-photos', 'plant-photos', true),
  ('order-photos', 'order-photos', false)
on conflict (id) do nothing;

-- Plant photos: public read; a seller writes only inside their own folder (<user id>/...).
create policy "Plant photos are public" on storage.objects
  for select using (bucket_id = 'plant-photos');

create policy "Sellers upload plant photos to their folder" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'plant-photos' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "Sellers update their plant photos" on storage.objects
  for update to authenticated
  using (bucket_id = 'plant-photos' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "Sellers delete their plant photos" on storage.objects
  for delete to authenticated
  using (bucket_id = 'plant-photos' and (storage.foldername(name))[1] = auth.uid()::text);

-- Order photos (<order id>/photo.jpg): the shop uploads, the buyer and the shop can read.
create policy "Shop owner uploads order photo" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'order-photos' and exists (
      select 1 from orders o join sellers s on s.id = o.seller_id
      where o.id::text = (storage.foldername(name))[1] and s.owner_id = auth.uid()
    )
  );

create policy "Shop owner replaces order photo" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'order-photos' and exists (
      select 1 from orders o join sellers s on s.id = o.seller_id
      where o.id::text = (storage.foldername(name))[1] and s.owner_id = auth.uid()
    )
  );

create policy "Buyer and shop owner read order photo" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'order-photos' and exists (
      select 1 from orders o join sellers s on s.id = o.seller_id
      where o.id::text = (storage.foldername(name))[1]
        and (o.buyer_id = auth.uid() or s.owner_id = auth.uid())
    )
  );

-- ------------------------------------------------------------------ orders
alter table orders add column if not exists change_request text;

-- Shops must not edit orders directly (they could change prices); status changes go through functions.
drop policy if exists "Sellers can update status of their own orders" on orders;

create or replace function public.seller_set_order_status(
  p_order_id uuid, p_status text, p_photo_path text default null
) returns void
language plpgsql security definer set search_path = public
as $$
declare o orders%rowtype;
begin
  select * into o from orders where id = p_order_id;
  if not found then raise exception 'order not found'; end if;
  if not exists (select 1 from sellers where id = o.seller_id and owner_id = auth.uid()) then
    raise exception 'not your order';
  end if;
  if not (
    (o.status = 'placed'    and p_status in ('preparing', 'cancelled')) or
    (o.status = 'preparing' and p_status in ('photo_sent', 'cancelled')) or
    (o.status = 'approved'  and p_status = 'out_for_delivery') or
    (o.status = 'out_for_delivery' and p_status = 'delivered')
  ) then
    raise exception 'invalid status change % -> %', o.status, p_status;
  end if;
  if p_status = 'photo_sent' and coalesce(p_photo_path, '') = '' then
    raise exception 'a photo is required';
  end if;
  update orders set
    status = p_status,
    preparation_photo_path = case when p_status = 'photo_sent' then p_photo_path else preparation_photo_path end,
    change_request = case when p_status = 'photo_sent' then null else change_request end
  where id = p_order_id;
end;
$$;

create or replace function public.customer_review_photo(
  p_order_id uuid, p_approve boolean, p_note text default null
) returns void
language plpgsql security definer set search_path = public
as $$
declare o orders%rowtype;
begin
  select * into o from orders where id = p_order_id;
  if not found then raise exception 'order not found'; end if;
  if o.buyer_id <> auth.uid() then raise exception 'not your order'; end if;
  if o.status <> 'photo_sent' then raise exception 'no photo waiting for approval'; end if;
  update orders set
    status = case when p_approve then 'approved' else 'preparing' end,
    change_request = case when p_approve then null else left(coalesce(p_note, ''), 300) end
  where id = p_order_id;
end;
$$;

revoke all on function public.seller_set_order_status(uuid, text, text) from public, anon;
revoke all on function public.customer_review_photo(uuid, boolean, text) from public, anon;
grant execute on function public.seller_set_order_status(uuid, text, text) to authenticated;
grant execute on function public.customer_review_photo(uuid, boolean, text) to authenticated;

-- ------------------------------------------------------------- AI usage log
-- Written only by the identify-plant edge function (service role); no policies on purpose.
create table if not exists ai_scans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
create index if not exists ai_scans_user_time on ai_scans (user_id, created_at);
alter table ai_scans enable row level security;
