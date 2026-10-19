-- 006: orders for the native apps: photo-approval statuses, gift mode, delivery time, totals
-- Run once in Supabase Dashboard -> SQL Editor.
--
-- orders.items is now a list of {listing_id, name:{en,ar,ckb}, qty, unit_price_iqd}.
-- Older prototype rows keep their old shape; the apps read them tolerantly.

alter table orders drop constraint if exists orders_status_check;

-- Old prototype status 'confirmed' becomes 'preparing'.
update orders set status = 'preparing' where status = 'confirmed';

alter table orders add constraint orders_status_check check (
  status in ('placed', 'preparing', 'photo_sent', 'approved', 'out_for_delivery', 'delivered', 'cancelled')
);

alter table orders
  add column if not exists total_iqd integer not null default 0,
  add column if not exists delivery_fee_iqd integer not null default 0,
  add column if not exists buyer_name text not null default '',
  add column if not exists buyer_phone text not null default '',
  add column if not exists is_gift boolean not null default false,
  add column if not exists recipient_name text,
  add column if not exists recipient_phone text,
  add column if not exists gift_note text,
  add column if not exists delivery_date date,
  add column if not exists delivery_window text not null default 'any'
    check (delivery_window in ('any', 'morning', 'afternoon', 'evening')),
  add column if not exists preparation_photo_path text;
