-- Run this once in Supabase Dashboard -> SQL Editor -> New query -> Run

create policy "Users can create their own seller listing" on sellers
  for insert with check (auth.uid() = owner_id);
