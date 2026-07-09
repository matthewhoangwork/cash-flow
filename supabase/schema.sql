-- Run this once in the Supabase SQL editor (Project -> SQL Editor -> New query)
-- for the money_tracking app's offline-first sync layer.

create table public.wallets (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  is_default boolean not null default false,
  is_archived boolean not null default false,
  is_deleted boolean not null default false,
  updated_at timestamptz not null default now()
);

create table public.categories (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  type text not null check (type in ('income', 'expense')),
  icon_key text not null,
  palette_index integer not null,
  is_archived boolean not null default false,
  is_deleted boolean not null default false,
  updated_at timestamptz not null default now()
);

create table public.transactions (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  type text not null check (type in ('income', 'expense')),
  amount double precision not null,
  category_id uuid not null references public.categories(id),
  wallet_id uuid not null references public.wallets(id),
  date timestamptz not null,
  note text not null default '',
  is_deleted boolean not null default false,
  updated_at timestamptz not null default now()
);

create index wallets_user_id_idx on public.wallets(user_id);
create index categories_user_id_idx on public.categories(user_id);
create index transactions_user_id_idx on public.transactions(user_id);
create index transactions_user_id_date_idx on public.transactions(user_id, date desc);

alter table public.wallets enable row level security;
alter table public.categories enable row level security;
alter table public.transactions enable row level security;

create policy "wallets_owner_all" on public.wallets
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "categories_owner_all" on public.categories
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "transactions_owner_all" on public.transactions
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Rejects an incoming UPDATE that is older than what's already stored, so an
-- out-of-order push from a long-offline device can't clobber a newer edit
-- that already landed from another device (backstop for client-side
-- last-write-wins, which compares `updated_at` before ever sending the row).
create or replace function public.reject_stale_write() returns trigger
language plpgsql as $$
begin
  if new.updated_at < old.updated_at then
    return old;
  end if;
  return new;
end;
$$;

create trigger wallets_reject_stale before update on public.wallets
  for each row execute function public.reject_stale_write();
create trigger categories_reject_stale before update on public.categories
  for each row execute function public.reject_stale_write();
create trigger transactions_reject_stale before update on public.transactions
  for each row execute function public.reject_stale_write();
