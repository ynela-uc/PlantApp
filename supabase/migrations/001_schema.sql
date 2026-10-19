-- Run this once in Supabase Dashboard -> SQL Editor -> New query -> Run

create extension if not exists "pgcrypto";

create table if not exists sellers (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references auth.users(id),
  name text not null,
  city text not null,
  delivery_scope text not null check (delivery_scope in ('nationwide', 'local')),
  delivers_to text[],
  rating numeric not null default 0,
  plants_offered text[] not null default '{}',
  phone text not null,
  bio text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists orders (
  id uuid primary key default gen_random_uuid(),
  buyer_id uuid not null references auth.users(id),
  seller_id uuid not null references sellers(id),
  seller_name text not null,
  items jsonb not null,
  payment_method text not null check (payment_method in ('cod', 'card')),
  status text not null default 'placed' check (status in ('placed', 'confirmed', 'delivered', 'cancelled')),
  city text not null,
  address text not null,
  created_at timestamptz not null default now()
);

alter table sellers enable row level security;
alter table orders enable row level security;

create policy "Anyone can view sellers" on sellers
  for select using (true);

create policy "Owners can update their own seller listing" on sellers
  for update using (auth.uid() = owner_id);

create policy "Buyers can view their own orders" on orders
  for select using (auth.uid() = buyer_id);

create policy "Sellers can view orders placed with them" on orders
  for select using (
    exists (select 1 from sellers where sellers.id = orders.seller_id and sellers.owner_id = auth.uid())
  );

create policy "Buyers can insert their own orders" on orders
  for insert with check (auth.uid() = buyer_id);

create policy "Sellers can update status of their own orders" on orders
  for update using (
    exists (select 1 from sellers where sellers.id = orders.seller_id and sellers.owner_id = auth.uid())
  );

insert into sellers (name, city, delivery_scope, delivers_to, rating, plants_offered, phone, bio) values
  ('Al-Zahra Nursery', 'Baghdad', 'nationwide', null, 4.8, array['Monstera','Snake Plant','Pothos','Ficus'], '+964 770 000 0001', 'Family-run nursery in Baghdad, delivering indoor plants across Iraq for 10+ years.'),
  ('Erbil Green House', 'Erbil', 'local', array['Erbil'], 4.6, array['Cactus','Succulents','Aloe Vera'], '+964 750 000 0002', 'Specialists in desert plants and succulents, local delivery only within Erbil.'),
  ('Basra Botanicals', 'Basra', 'nationwide', null, 4.5, array['Palm','Rubber Plant','Peace Lily','Fern'], '+964 771 000 0003', 'Wide selection of tropical and indoor plants, ships to all provinces.'),
  ('Najaf Plant Corner', 'Najaf', 'local', array['Najaf','Karbala'], 4.3, array['Jasmine','Rose','Mint','Basil'], '+964 772 000 0004', 'Herbs, flowering plants and garden essentials, delivering to Najaf and Karbala.'),
  ('Sulaymaniyah Flora', 'Sulaymaniyah', 'nationwide', null, 4.9, array['Monstera','Bonsai','Orchid','Snake Plant'], '+964 773 000 0005', 'Premium indoor plants and bonsai trees, nationwide shipping available.')
on conflict do nothing;
