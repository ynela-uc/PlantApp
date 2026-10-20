-- 011: customers can now edit their own profile in the app. The profile update policy lets a user update their own
-- row, which would also include the `role` column (customer -> seller). Keep the role as it was unless the change
-- is made by an administrator (SQL editor / service role); app users can never change it.

create or replace function profiles_keep_role()
returns trigger
language plpgsql
as $$
begin
  if new.role is distinct from old.role and coalesce(auth.role(), 'service_role') = 'authenticated' then
    new.role := old.role;
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_keep_role on profiles;
create trigger profiles_keep_role
  before update on profiles
  for each row execute function profiles_keep_role();
