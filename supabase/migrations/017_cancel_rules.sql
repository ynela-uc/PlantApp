-- 017: cancel and problem rules.
--
--   * Every cancelled order records why (cancel_reason), who cancelled (cancelled_by: customer / shop / system) and when.
--   * A customer can cancel only while the order is new (status 'placed'): customer_cancel_order().
--   * A shop can cancel from placed, preparing, photo_sent and approved with a reason (out_of_stock, cant_deliver_day,
--     cant_make, other), and close an order that failed at the door from out_for_delivery (no_answer, refused,
--     wrong_address, other). Without a reason the server records 'other' (so older apps keep working).
--   * Orders nobody answers for 12 hours are cancelled by the system (reason no_response); checked every 10 minutes.
--   * Pushes: the shop hears about a customer cancellation; the customer hears about an expired order or a failed delivery.

alter table orders add column if not exists cancel_reason text;
alter table orders add column if not exists cancelled_by text check (cancelled_by in ('customer', 'shop', 'system'));
alter table orders add column if not exists cancelled_at timestamptz;

-- ------------------------------------------------------------ the shop's status changes (adds the reason)
drop function if exists public.seller_set_order_status(uuid, text, text);

create or replace function public.seller_set_order_status(
  p_order_id uuid, p_status text, p_photo_path text default null, p_reason text default null
) returns void
language plpgsql security definer set search_path = public
as $$
declare
  o orders%rowtype;
  reason text;
begin
  select * into o from orders where id = p_order_id;
  if not found then raise exception 'order not found'; end if;
  if not exists (select 1 from sellers where id = o.seller_id and owner_id = auth.uid()) then
    raise exception 'not your order';
  end if;
  if not (
    (o.status = 'placed'    and p_status in ('preparing', 'cancelled')) or
    (o.status = 'preparing' and o.photo_required     and p_status in ('photo_sent', 'cancelled')) or
    (o.status = 'preparing' and not o.photo_required and p_status in ('out_for_delivery', 'cancelled')) or
    (o.status = 'photo_sent' and p_status = 'cancelled') or
    (o.status = 'photo_sent' and p_status = 'approved'
       and o.photo_sent_at is not null and o.photo_sent_at < now() - interval '60 minutes') or
    (o.status = 'approved'  and p_status in ('out_for_delivery', 'cancelled')) or
    (o.status = 'out_for_delivery' and p_status in ('delivered', 'cancelled'))
  ) then
    raise exception 'invalid status change % -> %', o.status, p_status;
  end if;
  if p_status = 'photo_sent' and coalesce(p_photo_path, '') = '' then
    raise exception 'a photo is required';
  end if;
  if p_status = 'cancelled' then
    reason := coalesce(p_reason, 'other');
    if o.status = 'out_for_delivery' then
      if reason not in ('no_answer', 'refused', 'wrong_address', 'other') then raise exception 'invalid reason'; end if;
    else
      if reason not in ('out_of_stock', 'cant_deliver_day', 'cant_make', 'other') then raise exception 'invalid reason'; end if;
    end if;
  end if;
  update orders set
    status = p_status,
    preparation_photo_path = case when p_status = 'photo_sent' then p_photo_path else preparation_photo_path end,
    photo_sent_at = case when p_status = 'photo_sent' then now() else photo_sent_at end,
    change_request = case when p_status = 'photo_sent' then null else change_request end,
    cancel_reason = case when p_status = 'cancelled' then reason else cancel_reason end,
    cancelled_by = case when p_status = 'cancelled' then 'shop' else cancelled_by end,
    cancelled_at = case when p_status = 'cancelled' then now() else cancelled_at end
  where id = p_order_id;
end;
$$;

revoke all on function public.seller_set_order_status(uuid, text, text, text) from public, anon;
grant execute on function public.seller_set_order_status(uuid, text, text, text) to authenticated;

-- ------------------------------------------------------------ the customer cancels (only while the order is new)
create or replace function public.customer_cancel_order(p_order_id uuid) returns void
language plpgsql security definer set search_path = public
as $$
declare o orders%rowtype;
begin
  select * into o from orders where id = p_order_id;
  if not found then raise exception 'order not found'; end if;
  if o.buyer_id <> auth.uid() then raise exception 'not your order'; end if;
  if o.status <> 'placed' then raise exception 'too_late'; end if;
  update orders set
    status = 'cancelled', cancel_reason = 'customer_cancelled', cancelled_by = 'customer', cancelled_at = now()
  where id = p_order_id;
end;
$$;

revoke all on function public.customer_cancel_order(uuid) from public, anon;
grant execute on function public.customer_cancel_order(uuid) to authenticated;

-- ------------------------------------------------------------ nobody answered for 12 hours
create or replace function public.cancel_unanswered_orders() returns void
language plpgsql security definer set search_path = public
as $$
begin
  update orders set
    status = 'cancelled', cancel_reason = 'no_response', cancelled_by = 'system', cancelled_at = now()
  where status = 'placed' and created_at < now() - interval '12 hours';
end;
$$;

select cron.schedule('cancel-unanswered-orders', '*/10 * * * *', 'select public.cancel_unanswered_orders()');

-- ------------------------------------------------------------ pushes for the new cases
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

-- A report for the owner: which shops cancel the most (run it in the SQL editor).
create or replace view public.shop_cancellations as
select s.name as shop,
       count(*) filter (where o.status = 'cancelled' and o.cancelled_by = 'shop') as cancelled_by_shop,
       count(*) filter (where o.status = 'cancelled' and o.cancelled_by = 'customer') as cancelled_by_customer,
       count(*) filter (where o.status = 'cancelled' and o.cancelled_by = 'system') as expired,
       count(*) filter (where o.status = 'delivered') as delivered,
       count(*) as total_orders
from orders o join sellers s on s.id = o.seller_id
group by s.name;

revoke all on public.shop_cancellations from anon, authenticated;
