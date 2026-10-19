-- 004: account roles (customer / seller)
-- Run once in Supabase Dashboard -> SQL Editor.

alter table profiles
  add column if not exists role text not null default 'customer'
  check (role in ('customer', 'seller'));

-- Anyone who already owns a shop (from the prototype) is a seller.
update profiles set role = 'seller'
where id in (select owner_id from sellers where owner_id is not null);

-- Sign-up trigger now also stores the role chosen in the app. Anything other
-- than 'seller' falls back to 'customer'.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, role, first_name, last_name, phone, city, address)
  values (
    new.id,
    case when new.raw_user_meta_data->>'role' = 'seller' then 'seller' else 'customer' end,
    coalesce(new.raw_user_meta_data->>'first_name', ''),
    coalesce(new.raw_user_meta_data->>'last_name', ''),
    coalesce(new.raw_user_meta_data->>'phone', ''),
    coalesce(new.raw_user_meta_data->>'city', ''),
    coalesce(new.raw_user_meta_data->>'address', '')
  );
  return new;
end;
$$;
