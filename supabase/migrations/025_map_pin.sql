-- 025: a map pin on addresses (GPS / map) so a courier can navigate to the door.
--
--   * addresses already has lat/lng (migration 024); sellers (the shop address) and orders (the delivery address as it was
--     when the order was placed) get them too. Both are optional and always set together.
--   * The sign-up trigger stores the pin entered at sign-up with the first address.
--   * admin_shops() returns the shop pin so the admin can open it in a map.
-- The apps show a customer's pin to the shop only after it accepts the order, like the full address.

alter table sellers add column if not exists lat double precision;
alter table sellers add column if not exists lng double precision;
alter table orders add column if not exists lat double precision;
alter table orders add column if not exists lng double precision;

alter table addresses drop constraint if exists addresses_pin_valid;
alter table addresses add constraint addresses_pin_valid
  check ((lat is null) = (lng is null) and (lat is null or (lat between -90 and 90 and lng between -180 and 180)));
alter table sellers drop constraint if exists sellers_pin_valid;
alter table sellers add constraint sellers_pin_valid
  check ((lat is null) = (lng is null) and (lat is null or (lat between -90 and 90 and lng between -180 and 180)));
alter table orders drop constraint if exists orders_pin_valid;
alter table orders add constraint orders_pin_valid
  check ((lat is null) = (lng is null) and (lat is null or (lat between -90 and 90 and lng between -180 and 180)));

-- ------------------------------------------------------------ sign-up stores the pin with the first address
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  is_seller boolean := new.raw_user_meta_data->>'role' = 'seller';
  town text := coalesce(new.raw_user_meta_data->>'city', '');
  street text := left(coalesce(new.raw_user_meta_data->>'address', ''), 300);
  district text := left(coalesce(new.raw_user_meta_data->>'district', ''), 100);
  neighborhood text := left(coalesce(new.raw_user_meta_data->>'neighborhood', ''), 100);
  landmark text := left(coalesce(new.raw_user_meta_data->>'landmark', ''), 200);
  notes text := left(coalesce(new.raw_user_meta_data->>'address_notes', ''), 300);
  pin_lat double precision;
  pin_lng double precision;
begin
  begin
    pin_lat := nullif(new.raw_user_meta_data->>'lat', '')::double precision;
    pin_lng := nullif(new.raw_user_meta_data->>'lng', '')::double precision;
    if pin_lat is null or pin_lng is null or pin_lat not between -90 and 90 or pin_lng not between -180 and 180 then
      pin_lat := null;
      pin_lng := null;
    end if;
  exception when others then
    pin_lat := null;
    pin_lng := null;
  end;

  insert into public.profiles (id, role, first_name, last_name, phone, city, address, district, neighborhood, landmark, address_notes)
  values (
    new.id,
    case when is_seller then 'seller' else 'customer' end,
    coalesce(new.raw_user_meta_data->>'first_name', ''),
    coalesce(new.raw_user_meta_data->>'last_name', ''),
    coalesce(new.raw_user_meta_data->>'phone', ''),
    town, street, district, neighborhood, landmark, notes
  );
  if not is_seller and town <> '' then
    insert into public.addresses (user_id, label, city, district, neighborhood, street, landmark, notes, lat, lng, is_default)
    values (new.id, 'home', town, district, neighborhood, street, landmark, notes, pin_lat, pin_lng, true);
  end if;
  return new;
end;
$$;

-- ------------------------------------------------------------ the admin sees the shop pin
drop function if exists public.admin_shops();

create function public.admin_shops()
returns table (
  id uuid, name text, city text, phone text, bio text, shop_types text[], delivery_scope text,
  review_status text, review_note text, owner_name text, owner_email text, created_at timestamptz,
  delivers_to text[], delivery_fee_iqd integer, delivery_fees jsonb, product_count integer,
  approved boolean, rating numeric, rating_count integer,
  district text, neighborhood text, address text, landmark text, address_notes text,
  lat double precision, lng double precision
)
language plpgsql stable security definer set search_path = public
as $$
begin
  if not is_admin() then raise exception 'not admin'; end if;
  return query
    select s.id, s.name, s.city, s.phone, s.bio, s.shop_types, s.delivery_scope, s.review_status, s.review_note,
           trim(coalesce(p.first_name, '') || ' ' || coalesce(p.last_name, '')),
           u.email::text, s.created_at,
           s.delivers_to, s.delivery_fee_iqd, s.delivery_fees,
           (select count(*)::integer from listings l where l.seller_id = s.id),
           s.approved, s.rating, s.rating_count,
           s.district, s.neighborhood, s.address, s.landmark, s.address_notes,
           s.lat, s.lng
    from sellers s
    left join profiles p on p.id = s.owner_id
    left join auth.users u on u.id = s.owner_id
    where s.owner_id is not null
    order by (s.review_status = 'pending') desc, s.created_at desc;
end;
$$;

revoke all on function public.admin_shops() from public, anon;
grant execute on function public.admin_shops() to authenticated;
