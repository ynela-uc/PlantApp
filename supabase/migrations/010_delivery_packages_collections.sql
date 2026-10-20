-- 010: what shops like Whites & Wicks need (Instagram-style handmade shops):
--  * a delivery fee per shop (with different fees for some cities, e.g. Erbil 4,000) so the customer sees the
--    total including delivery before ordering;
--  * packages and options on a product (piece count, colour/scent choices, a "was" price for discounts);
--  * collections (autumn, Ramadan, ...) so a shop page can group its products.
-- Orders remember the delivery fee that was charged.

alter table sellers add column if not exists delivery_fee_iqd integer not null default 0;
-- {"Erbil": 4000, "Basra": 6000}: city code -> fee; cities not listed use delivery_fee_iqd.
alter table sellers add column if not exists delivery_fees jsonb not null default '{}'::jsonb;

alter table listings add column if not exists old_price_iqd integer;
alter table listings add column if not exists pieces integer;
-- [{"name": "Colour", "values": ["Blue", "Black"]}, ...]: choices the customer makes before adding to the cart.
alter table listings add column if not exists options jsonb not null default '[]'::jsonb;
alter table listings add column if not exists collection text;

alter table orders add column if not exists delivery_fee_iqd integer not null default 0;

create index if not exists listings_seller_collection_idx on listings (seller_id, collection);
