-- All In One Store: shop till (point of sale). Already applied to the live project.
-- Adds staff accounts, shop sales, shared stock, and the server-side sale rules.
alter table public.profiles add column if not exists is_staff boolean not null default false;
create table if not exists public.branches (id text primary key, name text not null);
insert into public.branches (id, name) values ('main','Main shop') on conflict (id) do nothing;
create sequence if not exists public.shop_sale_seq start 1;
create table if not exists public.shop_sales (
  id text primary key,
  branch_id text not null default 'main' references public.branches(id),
  staff_id uuid not null references public.profiles(id),
  staff_name text not null default '',
  items jsonb not null,
  subtotal integer not null, discount integer not null default 0, total integer not null,
  pay text not null check (pay in ('cash','mpesa')),
  cash_given integer, change_given integer, mpesa_phone text, mpesa_code text, note text,
  status text not null default 'paid' check (status in ('paid','void')),
  created_at timestamptz not null default now(), voided_at timestamptz, voided_by uuid
);
alter table public.shop_sales enable row level security;
alter table public.branches enable row level security;
-- The functions record_shop_sale, void_shop_sale, set_staff, is_staff and the trigger
-- orders_take_stock are defined in the Supabase project (migration "shop_pos").
