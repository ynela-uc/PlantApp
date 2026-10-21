-- 018: a person can delete their own account from the apps (required by Google Play and the App Store).
--
-- delete_my_account():
--   * refuses while orders are in progress ('open_orders'): preparing, photo_sent, approved, out_for_delivery
--     (for a customer: their orders; for a shop owner: the orders of their shop);
--   * cancels orders that were not accepted yet;
--   * keeps past orders for the shops' and our records but removes the person's name, phone and address from them;
--   * a shop is hidden and emptied (name, phone, bio, products removed); its order history stays;
--   * removes the profile, notification addresses and the sign-in account.

do $$
declare fk text;
begin
  -- orders must survive the buyer's account: buyer_id becomes optional and is cleared when the account is deleted
  alter table orders alter column buyer_id drop not null;
  for fk in
    select c.conname from pg_constraint c
    where c.conrelid = 'public.orders'::regclass and c.contype = 'f'
      and c.conkey = array[(select attnum from pg_attribute where attrelid = 'public.orders'::regclass and attname = 'buyer_id')]
  loop
    execute format('alter table orders drop constraint %I', fk);
  end loop;
  alter table orders add constraint orders_buyer_id_fkey foreign key (buyer_id) references auth.users(id) on delete set null;
end $$;

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

  -- orders nobody accepted yet are cancelled
  update orders set
    status = 'cancelled',
    cancel_reason = case when buyer_id = uid then 'customer_cancelled' else 'other' end,
    cancelled_by = case when buyer_id = uid then 'customer' else 'shop' end,
    cancelled_at = now()
  where status = 'placed' and (buyer_id = uid or seller_id = any(my_shops));

  -- the person's details leave their past orders
  update orders set
    buyer_name = '', buyer_phone = '', address = '',
    recipient_name = null, recipient_phone = null, gift_note = null
  where buyer_id = uid;

  -- a shop is emptied and hidden
  delete from listings where seller_id = any(my_shops);
  update sellers set owner_id = null, approved = false, name = 'Deleted shop', phone = '', bio = '', delivers_to = null
  where id = any(my_shops);

  delete from profiles where id = uid;
  delete from auth.users where id = uid;
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
