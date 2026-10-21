-- 023: structured addresses for customers, shops and orders.
--
-- An address is now: governorate (the existing `city` column, one of the 19 governorate codes), district (city / qada),
-- neighborhood, street or building (the existing `address` column), nearest landmark and delivery notes.
-- Iraq has no reliable street names or postcodes, so the landmark carries a lot of weight.
--   * profiles: district, neighborhood, landmark, address_notes (the customer's main address, until the address book arrives).
--   * sellers: the shop address, same fields plus `address` (only the admin and the owner see it; customers see the governorate).
--   * orders: a copy of the delivery address as it was when the order was placed.
--   * the sign-up trigger stores the new fields too; admin_shops() returns the shop address for the admin.
-- Old rows keep working: the new columns are empty ('') until the person fills them in.

alter table profiles add column if not exists district text not null default '';
alter table profiles add column if not exists neighborhood text not null default '';
alter table profiles add column if not exists landmark text not null default '';
alter table profiles add column if not exists address_notes text not null default '';

alter table sellers add column if not exists address text not null default '';
alter table sellers add column if not exists district text not null default '';
alter table sellers add column if not exists neighborhood text not null default '';
alter table sellers add column if not exists landmark text not null default '';
alter table sellers add column if not exists address_notes text not null default '';

alter table orders add column if not exists district text not null default '';
alter table orders add column if not exists neighborhood text not null default '';
alter table orders add column if not exists landmark text not null default '';
alter table orders add column if not exists address_notes text not null default '';

alter table profiles drop constraint if exists profiles_address_len;
alter table profiles add constraint profiles_address_len
  check (char_length(district) <= 100 and char_length(neighborhood) <= 100 and char_length(landmark) <= 200 and char_length(address_notes) <= 300);
alter table sellers drop constraint if exists sellers_address_len;
alter table sellers add constraint sellers_address_len
  check (char_length(address) <= 300 and char_length(district) <= 100 and char_length(neighborhood) <= 100
         and char_length(landmark) <= 200 and char_length(address_notes) <= 300);
alter table orders drop constraint if exists orders_address_len;
alter table orders add constraint orders_address_len
  check (char_length(district) <= 100 and char_length(neighborhood) <= 100 and char_length(landmark) <= 200 and char_length(address_notes) <= 300);

-- ------------------------------------------------------------ sign-up stores the full address
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, role, first_name, last_name, phone, city, address, district, neighborhood, landmark, address_notes)
  values (
    new.id,
    case when new.raw_user_meta_data->>'role' = 'seller' then 'seller' else 'customer' end,
    coalesce(new.raw_user_meta_data->>'first_name', ''),
    coalesce(new.raw_user_meta_data->>'last_name', ''),
    coalesce(new.raw_user_meta_data->>'phone', ''),
    coalesce(new.raw_user_meta_data->>'city', ''),
    left(coalesce(new.raw_user_meta_data->>'address', ''), 500),
    left(coalesce(new.raw_user_meta_data->>'district', ''), 100),
    left(coalesce(new.raw_user_meta_data->>'neighborhood', ''), 100),
    left(coalesce(new.raw_user_meta_data->>'landmark', ''), 200),
    left(coalesce(new.raw_user_meta_data->>'address_notes', ''), 300)
  );
  return new;
end;
$$;

-- ------------------------------------------------------------ the admin sees the shop address
drop function if exists public.admin_shops();

create function public.admin_shops()
returns table (
  id uuid, name text, city text, phone text, bio text, shop_types text[], delivery_scope text,
  review_status text, review_note text, owner_name text, owner_email text, created_at timestamptz,
  delivers_to text[], delivery_fee_iqd integer, delivery_fees jsonb, product_count integer,
  approved boolean, rating numeric, rating_count integer,
  district text, neighborhood text, address text, landmark text, address_notes text
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
           s.district, s.neighborhood, s.address, s.landmark, s.address_notes
    from sellers s
    left join profiles p on p.id = s.owner_id
    left join auth.users u on u.id = s.owner_id
    where s.owner_id is not null
    order by (s.review_status = 'pending') desc, s.created_at desc;
end;
$$;

revoke all on function public.admin_shops() from public, anon;
grant execute on function public.admin_shops() to authenticated;
