-- 013: the server checks every new order instead of trusting the app.
--
-- Until now the app sent the prices, delivery fee and total and the database stored them as given, so a modified
-- app could order for 1 dinar. This trigger runs before every order insert by a signed-in user and:
--   * looks each product up (it must exist, belong to the shop, be in stock, and the chosen options must be real),
--   * takes the price from the product and the delivery fee from the shop, and works out the total itself,
--   * rejects the order ('price_changed') when what the app showed differs from that (stale or tampered prices),
--   * rejects shops that do not deliver to the city, cash-only for now, and more than 30 orders an hour,
--   * rebuilds the stored lines from the product (name, price, options), and takes the buyer's name and phone from
--     their profile, so nothing else the app sent is trusted.
-- Errors the apps understand: price_changed, unavailable, too_many_orders, payment_not_available.
-- Inserts by an administrator (SQL editor / service role) are not checked.

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

    -- every option the product has needs one of its listed values; nothing else is accepted
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

drop trigger if exists orders_validate_insert on orders;
create trigger orders_validate_insert
  before insert on orders
  for each row execute function public.orders_validate_insert();
