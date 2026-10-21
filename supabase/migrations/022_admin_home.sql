-- 022: the admin account gets its own home in the apps: all shops, decisions on any shop, and moderation of products and reviews.
--
--   * admin_shops(): every shop that has an owner (approved or not), with approval state and rating, for the admin's list.
--   * admin_review_shop(): same as before, and now writes every decision to admin_actions (an audit log nobody can read through the apps).
--   * admin_delete_listing(listing, reason): removes a product that breaks the rules; the shop owner gets a push.
--   * admin_shop_ratings(shop) / admin_delete_rating(rating, reason): the admin reads and removes abusive reviews.
--   * ratings_refresh() now also works when a rating is deleted (it used NEW, which does not exist for deletes).
-- Everything here refuses everybody except the admin account (internal_config 'admin_user_id').

create table if not exists admin_actions (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid,
  action text not null,
  shop_id uuid,
  target_id uuid,
  note text,
  created_at timestamptz not null default now()
);
alter table admin_actions enable row level security;

-- ------------------------------------------------------------ all shops
create or replace function public.admin_shops()
returns table (
  id uuid, name text, city text, phone text, bio text, shop_types text[], delivery_scope text,
  review_status text, review_note text, owner_name text, owner_email text, created_at timestamptz,
  delivers_to text[], delivery_fee_iqd integer, delivery_fees jsonb, product_count integer,
  approved boolean, rating numeric, rating_count integer
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
           s.approved, s.rating, s.rating_count
    from sellers s
    left join profiles p on p.id = s.owner_id
    left join auth.users u on u.id = s.owner_id
    where s.owner_id is not null
    order by (s.review_status = 'pending') desc, s.created_at desc;
end;
$$;

revoke all on function public.admin_shops() from public, anon;
grant execute on function public.admin_shops() to authenticated;

-- ------------------------------------------------------------ decisions are logged
create or replace function public.admin_review_shop(p_shop_id uuid, p_decision text, p_note text default null)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  note text := nullif(left(trim(coalesce(p_note, '')), 500), '');
begin
  if not is_admin() then raise exception 'not admin'; end if;
  if not exists (select 1 from sellers where id = p_shop_id and owner_id is not null) then raise exception 'shop not found'; end if;
  if p_decision not in ('approve', 'changes', 'reject') then raise exception 'invalid decision'; end if;
  if p_decision <> 'approve' and (note is null or char_length(note) < 3) then raise exception 'note required'; end if;

  perform set_config('app.shop_review', 'on', true);
  if p_decision = 'approve' then
    update sellers set approved = true, approved_at = now(), review_status = 'approved', review_note = null, reviewed_at = now()
    where id = p_shop_id;
  elsif p_decision = 'changes' then
    update sellers set approved = false, approved_at = null, review_status = 'changes_requested', review_note = note, reviewed_at = now()
    where id = p_shop_id;
  else
    update sellers set approved = false, approved_at = null, review_status = 'rejected', review_note = note, reviewed_at = now()
    where id = p_shop_id;
  end if;
  perform set_config('app.shop_review', 'off', true);

  insert into admin_actions (admin_id, action, shop_id, note) values (auth.uid(), 'shop_' || p_decision, p_shop_id, note);
end;
$$;

-- ------------------------------------------------------------ products
create or replace function public.admin_delete_listing(p_listing_id uuid, p_reason text)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  sid uuid;
  note text := nullif(left(trim(coalesce(p_reason, '')), 500), '');
begin
  if not is_admin() then raise exception 'not admin'; end if;
  if note is null or char_length(note) < 3 then raise exception 'note required'; end if;
  select seller_id into sid from listings where id = p_listing_id;
  if sid is null then raise exception 'product not found'; end if;
  delete from listings where id = p_listing_id;
  insert into admin_actions (admin_id, action, shop_id, target_id, note) values (auth.uid(), 'listing_deleted', sid, p_listing_id, note);
  perform push_shop_event('product_removed', sid);
end;
$$;

revoke all on function public.admin_delete_listing(uuid, text) from public, anon;
grant execute on function public.admin_delete_listing(uuid, text) to authenticated;

-- ------------------------------------------------------------ reviews
create or replace function public.admin_shop_ratings(p_shop_id uuid)
returns setof ratings
language plpgsql stable security definer set search_path = public
as $$
begin
  if not is_admin() then raise exception 'not admin'; end if;
  return query select * from ratings where seller_id = p_shop_id order by created_at desc;
end;
$$;

revoke all on function public.admin_shop_ratings(uuid) from public, anon;
grant execute on function public.admin_shop_ratings(uuid) to authenticated;

create or replace function public.admin_delete_rating(p_rating_id uuid, p_reason text default null)
returns void
language plpgsql security definer set search_path = public
as $$
declare sid uuid;
begin
  if not is_admin() then raise exception 'not admin'; end if;
  select seller_id into sid from ratings where id = p_rating_id;
  if sid is null then raise exception 'rating not found'; end if;
  delete from ratings where id = p_rating_id;
  insert into admin_actions (admin_id, action, shop_id, target_id, note)
  values (auth.uid(), 'rating_deleted', sid, p_rating_id, nullif(left(trim(coalesce(p_reason, '')), 500), ''));
end;
$$;

revoke all on function public.admin_delete_rating(uuid, text) from public, anon;
grant execute on function public.admin_delete_rating(uuid, text) to authenticated;

-- the average and count must follow when a rating disappears (a DELETE trigger has no NEW row)
create or replace function public.ratings_refresh() returns trigger
language plpgsql security definer set search_path = public
as $$
declare sid uuid;
begin
  if tg_op = 'DELETE' then sid := old.seller_id; else sid := new.seller_id; end if;
  perform set_config('app.rating_update', 'on', true);
  update sellers set
    rating = coalesce((select round(avg(stars)::numeric, 1) from ratings where seller_id = sid), 0),
    rating_count = (select count(*) from ratings where seller_id = sid)
  where id = sid;
  perform set_config('app.rating_update', 'off', true);
  return null;
end;
$$;
