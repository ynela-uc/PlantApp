-- 020: the admin reviews new shops inside the app (no more dashboard work).
--
--   * sellers.review_status: 'pending' (waiting for the admin), 'changes_requested' (the admin asked the shop to fix or add
--     something, see review_note), 'rejected' (final, see review_note), 'approved'. `approved` stays the switch that makes a
--     shop visible to customers; review_status explains where the shop is in the process.
--   * is_admin(): true for the account saved in internal_config 'admin_user_id'.
--   * admin_pending_shops(): shops that are not approved yet, for the admin's Approvals screen.
--   * admin_review_shop(shop, decision, note): decision 'approve' | 'changes' | 'reject'. A note is required for the last two.
--   * resubmit_shop(): the owner of a shop in 'changes_requested' sends it back for review (it becomes 'pending' again).
--   * Pushes: shop owner when changes are requested / rejected / approved; admin when a shop is sent back for review.
--   * Apps still cannot change any of these columns themselves (guard trigger); only the functions above can.

alter table sellers add column if not exists review_status text not null default 'pending';
alter table sellers add column if not exists review_note text;
alter table sellers add column if not exists reviewed_at timestamptz;
alter table sellers drop constraint if exists sellers_review_status_check;
alter table sellers add constraint sellers_review_status_check
  check (review_status in ('pending', 'changes_requested', 'rejected', 'approved'));
update sellers set review_status = 'approved' where approved and review_status <> 'approved';

-- ------------------------------------------------------------ guard: apps cannot touch approval or review columns
create or replace function public.sellers_guard_approval() returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if coalesce(auth.role(), 'service_role') = 'authenticated' then
    if tg_op = 'INSERT' then
      new.approved := false;
      new.approved_at := null;
      new.review_status := 'pending';
      new.review_note := null;
      new.reviewed_at := null;
      new.rating := 0;
      new.rating_count := 0;
    else
      if coalesce(current_setting('app.deleting_account', true), '') <> 'on'
         and coalesce(current_setting('app.shop_review', true), '') <> 'on' then
        new.approved := old.approved;
        new.approved_at := old.approved_at;
        new.review_status := old.review_status;
        new.review_note := old.review_note;
        new.reviewed_at := old.reviewed_at;
      end if;
      if coalesce(current_setting('app.rating_update', true), '') <> 'on' then
        new.rating := old.rating;
        new.rating_count := old.rating_count;
      end if;
    end if;
  end if;
  return new;
end;
$$;

-- ------------------------------------------------------------ who is the admin
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (select 1 from internal_config where key = 'admin_user_id' and value = auth.uid()::text);
$$;

revoke all on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;

-- ------------------------------------------------------------ the admin's list
create or replace function public.admin_pending_shops()
returns table (
  id uuid, name text, city text, phone text, bio text, shop_types text[], delivery_scope text,
  review_status text, review_note text, owner_name text, owner_email text, created_at timestamptz
)
language plpgsql stable security definer set search_path = public
as $$
begin
  if not is_admin() then raise exception 'not admin'; end if;
  return query
    select s.id, s.name, s.city, s.phone, s.bio, s.shop_types, s.delivery_scope, s.review_status, s.review_note,
           trim(coalesce(p.first_name, '') || ' ' || coalesce(p.last_name, '')),
           u.email::text, s.created_at
    from sellers s
    left join profiles p on p.id = s.owner_id
    left join auth.users u on u.id = s.owner_id
    where not s.approved and s.owner_id is not null
    order by (s.review_status = 'pending') desc, s.created_at desc;
end;
$$;

revoke all on function public.admin_pending_shops() from public, anon;
grant execute on function public.admin_pending_shops() to authenticated;

-- ------------------------------------------------------------ the admin's decision
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
end;
$$;

revoke all on function public.admin_review_shop(uuid, text, text) from public, anon;
grant execute on function public.admin_review_shop(uuid, text, text) to authenticated;

-- ------------------------------------------------------------ the owner sends the shop back for review
create or replace function public.resubmit_shop() returns void
language plpgsql security definer set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if not exists (select 1 from sellers where owner_id = auth.uid() and review_status = 'changes_requested') then
    raise exception 'nothing to resubmit';
  end if;
  perform set_config('app.shop_review', 'on', true);
  update sellers set review_status = 'pending', reviewed_at = null
  where owner_id = auth.uid() and review_status = 'changes_requested';
  perform set_config('app.shop_review', 'off', true);
end;
$$;

revoke all on function public.resubmit_shop() from public, anon;
grant execute on function public.resubmit_shop() to authenticated;

-- ------------------------------------------------------------ pushes
create or replace function public.sellers_push_events() returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    if not new.approved and new.owner_id is not null then
      perform push_shop_event('new_shop', new.id);
    end if;
  elsif new.approved and not old.approved then
    perform push_shop_event('shop_approved', new.id);
  elsif new.review_status is distinct from old.review_status then
    if new.review_status = 'changes_requested' then
      perform push_shop_event('shop_changes_requested', new.id);
    elsif new.review_status = 'rejected' then
      perform push_shop_event('shop_rejected', new.id);
    elsif new.review_status = 'pending' and old.review_status = 'changes_requested' then
      perform push_shop_event('new_shop', new.id);
    end if;
  end if;
  return null;
end;
$$;

drop trigger if exists sellers_push_events on sellers;
create trigger sellers_push_events
  after insert or update of approved, review_status on sellers
  for each row execute function public.sellers_push_events();
