-- 014: the photo the customer approves before delivery is now optional.
--
--   * Each product says how it works: listings.photo_approval = 'off' (default) / 'optional' / 'required'.
--   * At checkout the customer can ask for a photo on products where it is 'optional' (orders.photo_requested).
--   * The server decides orders.photo_required: any 'required' product, or an 'optional' one the customer asked for.
--   * Orders without a photo go straight from 'preparing' to 'out_for_delivery'.
--   * If the customer has not answered a photo within 60 minutes, the shop may move the order on ('photo_sent' -> 'approved').
--     (Checked here, no timer needed: the shop's app offers the button once the time has passed.)
-- Orders already in progress keep their photo step.

alter table listings add column if not exists photo_approval text not null default 'off'
  check (photo_approval in ('off', 'optional', 'required'));

alter table orders add column if not exists photo_requested boolean not null default false;
alter table orders add column if not exists photo_required boolean not null default false;
alter table orders add column if not exists photo_sent_at timestamptz;

update orders set photo_required = true where status in ('preparing', 'photo_sent', 'approved');
update orders set photo_sent_at = now() where status = 'photo_sent' and photo_sent_at is null;

-- ------------------------------------------------------------ order checking (013) + photo flags
create or replace function public.orders_validate_insert()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  s sellers%rowtype;
  p profiles%rowtype;
  l listings%rowtype;
  line jsonb;
  opt jsonb;
  chosen jsonb;
  chosen_value text;
  clean jsonb := '[]'::jsonb;
  qty integer;
  subtotal bigint := 0;
  fee integer;
  has_required boolean := false;
  has_optional boolean := false;
  today date := (now() at time zone 'Asia/Baghdad')::date;
begin
  if coalesce(auth.role(), 'service_role') <> 'authenticated' then
    return new;
  end if;

  new.buyer_id := auth.uid();
  new.created_at := now();

  if (select count(*) from orders where buyer_id = auth.uid() and created_at > now() - interval '1 hour') >= 30 then
    raise exception 'too_many_orders';
  end if;
  if new.payment_method <> 'cod' then
    raise exception 'payment_not_available';
  end if;

  select * into s from sellers where id = new.seller_id;
  if not found then raise exception 'unavailable'; end if;
  if not (s.city = new.city or s.delivery_scope = 'nationwide' or new.city = any(coalesce(s.delivers_to, '{}'))) then
    raise exception 'unavailable';
  end if;

  if jsonb_typeof(new.items) <> 'array' or jsonb_array_length(new.items) not between 1 and 30 then
    raise exception 'unavailable';
  end if;

  for line in select value from jsonb_array_elements(new.items) loop
    if jsonb_typeof(line) <> 'object'
       or coalesce(line->>'listing_id', '') !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
       or jsonb_typeof(line->'qty') <> 'number'
       or jsonb_typeof(line->'unit_price_iqd') <> 'number' then
      raise exception 'unavailable';
    end if;

    select * into l from listings where id = (line->>'listing_id')::uuid and seller_id = s.id;
    if not found or not l.in_stock then raise exception 'unavailable'; end if;

    qty := (line->>'qty')::numeric::integer;
    if (line->>'qty')::numeric <> qty or qty not between 1 and 99 then raise exception 'unavailable'; end if;

    if (line->>'unit_price_iqd')::numeric <> l.price_iqd then raise exception 'price_changed'; end if;

    chosen := coalesce(line->'options', '{}'::jsonb);
    if jsonb_typeof(chosen) <> 'object' then raise exception 'unavailable'; end if;
    if (select count(*) from jsonb_object_keys(chosen)) <> jsonb_array_length(coalesce(l.options, '[]'::jsonb)) then
      raise exception 'unavailable';
    end if;
    for opt in select value from jsonb_array_elements(coalesce(l.options, '[]'::jsonb)) loop
      chosen_value := chosen ->> (opt ->> 'name');
      if chosen_value is null or not ((opt -> 'values') @> to_jsonb(chosen_value)) then
        raise exception 'unavailable';
      end if;
    end loop;

    if l.photo_approval = 'required' then has_required := true; end if;
    if l.photo_approval = 'optional' then has_optional := true; end if;

    subtotal := subtotal + l.price_iqd::bigint * qty;
    clean := clean || jsonb_build_object(
      'listing_id', l.id, 'name', l.name, 'qty', qty, 'unit_price_iqd', l.price_iqd, 'options', chosen
    );
  end loop;

  fee := coalesce((s.delivery_fees ->> new.city)::integer, s.delivery_fee_iqd, 0);
  if new.delivery_fee_iqd is distinct from fee or new.total_iqd::bigint is distinct from subtotal + fee then
    raise exception 'price_changed';
  end if;

  if new.delivery_date is null or new.delivery_date < today - 1 or new.delivery_date > today + 90 then
    raise exception 'unavailable';
  end if;

  select * into p from profiles where id = auth.uid();
  new.items := clean;
  new.seller_name := s.name;
  new.buyer_name := trim(coalesce(p.first_name, '') || ' ' || coalesce(p.last_name, ''));
  new.buyer_phone := coalesce(p.phone, '');
  new.status := 'placed';
  new.preparation_photo_path := null;
  new.change_request := null;
  new.photo_sent_at := null;
  new.photo_requested := coalesce(new.photo_requested, false) and has_optional;
  new.photo_required := has_required or new.photo_requested;
  new.address := left(new.address, 500);
  if new.is_gift then
    new.recipient_name := left(new.recipient_name, 100);
    new.recipient_phone := left(new.recipient_phone, 30);
    new.gift_note := left(new.gift_note, 500);
  else
    new.recipient_name := null;
    new.recipient_phone := null;
    new.gift_note := null;
  end if;
  return new;
end;
$$;

-- ------------------------------------------------------------ status changes by the shop
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
    (o.status = 'preparing' and o.photo_required     and p_status in ('photo_sent', 'cancelled')) or
    (o.status = 'preparing' and not o.photo_required and p_status in ('out_for_delivery', 'cancelled')) or
    (o.status = 'photo_sent' and p_status = 'approved'
       and o.photo_sent_at is not null and o.photo_sent_at < now() - interval '60 minutes') or
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
    photo_sent_at = case when p_status = 'photo_sent' then now() else photo_sent_at end,
    change_request = case when p_status = 'photo_sent' then null else change_request end
  where id = p_order_id;
end;
$$;
