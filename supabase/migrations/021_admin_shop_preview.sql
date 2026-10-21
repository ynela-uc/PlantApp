-- 021: the admin can open a shop that is not approved yet and see everything customers would see before deciding.
--
--   * admin_pending_shops() now also returns the delivery details (cities, default fee, per-city fees) and the number of products.
--   * admin_shop_listings(shop): all products of any shop (customers cannot see products of unapproved shops, so the admin
--     needs this function). Photos are in the public plant-photos bucket, so their links work without anything else.
-- Both refuse everybody except the admin account.

drop function if exists public.admin_pending_shops();

create function public.admin_pending_shops()
returns table (
  id uuid, name text, city text, phone text, bio text, shop_types text[], delivery_scope text,
  review_status text, review_note text, owner_name text, owner_email text, created_at timestamptz,
  delivers_to text[], delivery_fee_iqd integer, delivery_fees jsonb, product_count integer
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
           (select count(*)::integer from listings l where l.seller_id = s.id)
    from sellers s
    left join profiles p on p.id = s.owner_id
    left join auth.users u on u.id = s.owner_id
    where not s.approved and s.owner_id is not null
    order by (s.review_status = 'pending') desc, s.created_at desc;
end;
$$;

revoke all on function public.admin_pending_shops() from public, anon;
grant execute on function public.admin_pending_shops() to authenticated;

create or replace function public.admin_shop_listings(p_shop_id uuid)
returns setof listings
language plpgsql stable security definer set search_path = public
as $$
begin
  if not is_admin() then raise exception 'not admin'; end if;
  return query select * from listings where seller_id = p_shop_id order by created_at desc;
end;
$$;

revoke all on function public.admin_shop_listings(uuid) from public, anon;
grant execute on function public.admin_shop_listings(uuid) to authenticated;
