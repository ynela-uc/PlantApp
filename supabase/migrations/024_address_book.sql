-- 024: the customer's address book (Home, Work, Apartment, ...).
--
--   * addresses: up to 10 saved addresses per customer, each with a name (label), the structured address from migration 023,
--     an optional map position (lat/lng, filled in later by the map pin) and an is_default flag.
--   * Exactly one address is the default: the first one saved becomes the default, making another one the default clears the
--     old one, and deleting the default hands the role to the oldest remaining address.
--   * Only the owner can read or change their addresses. Deleting the account deletes them (cascade).
--   * Existing customers: their profile address becomes their first saved address, named 'home'.
--   * New customers: the sign-up trigger saves the sign-up address as the first address.
--   * Orders keep their own copy of the address (migration 023), so changing or deleting a saved address never changes an order.
-- The label is either one of 'home', 'work', 'apartment' (shown in the app language) or the customer's own text.

create table if not exists addresses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  label text not null default '' check (char_length(label) <= 40),
  city text not null default '',
  district text not null default '' check (char_length(district) <= 100),
  neighborhood text not null default '' check (char_length(neighborhood) <= 100),
  street text not null default '' check (char_length(street) <= 300),
  landmark text not null default '' check (char_length(landmark) <= 200),
  notes text not null default '' check (char_length(notes) <= 300),
  lat double precision,
  lng double precision,
  is_default boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists addresses_user_idx on addresses (user_id, created_at);
create unique index if not exists addresses_one_default on addresses (user_id) where is_default;

alter table addresses enable row level security;
drop policy if exists "Customers read their own addresses" on addresses;
create policy "Customers read their own addresses" on addresses for select using (user_id = auth.uid());
drop policy if exists "Customers add their own addresses" on addresses;
create policy "Customers add their own addresses" on addresses for insert with check (user_id = auth.uid());
drop policy if exists "Customers change their own addresses" on addresses;
create policy "Customers change their own addresses" on addresses for update using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "Customers delete their own addresses" on addresses;
create policy "Customers delete their own addresses" on addresses for delete using (user_id = auth.uid());

-- ------------------------------------------------------------ the default rule and the limit
create or replace function public.addresses_before_write() returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    if (select count(*) from addresses where user_id = new.user_id) >= 10 then
      raise exception 'too many addresses';
    end if;
    if not exists (select 1 from addresses where user_id = new.user_id) then
      new.is_default := true;
    end if;
  end if;
  if new.is_default then
    update addresses set is_default = false where user_id = new.user_id and id <> new.id and is_default;
  end if;
  return new;
end;
$$;

drop trigger if exists addresses_before_write on addresses;
create trigger addresses_before_write
  before insert or update on addresses
  for each row execute function public.addresses_before_write();

create or replace function public.addresses_after_delete() returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if old.is_default then
    update addresses set is_default = true
    where id = (select id from addresses where user_id = old.user_id order by created_at limit 1);
  end if;
  return null;
end;
$$;

drop trigger if exists addresses_after_delete on addresses;
create trigger addresses_after_delete
  after delete on addresses
  for each row execute function public.addresses_after_delete();

-- ------------------------------------------------------------ existing customers
insert into addresses (user_id, label, city, district, neighborhood, street, landmark, notes, is_default)
select p.id, 'home', p.city, p.district, p.neighborhood, left(p.address, 300), p.landmark, p.address_notes, true
from profiles p
where p.role = 'customer' and p.city <> '' and p.address <> ''
  and not exists (select 1 from addresses a where a.user_id = p.id);

-- ------------------------------------------------------------ new customers: the sign-up address is the first one
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
begin
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
    insert into public.addresses (user_id, label, city, district, neighborhood, street, landmark, notes, is_default)
    values (new.id, 'home', town, district, neighborhood, street, landmark, notes, true);
  end if;
  return new;
end;
$$;
