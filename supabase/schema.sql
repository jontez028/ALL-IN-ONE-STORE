-- All In One Store: database setup for Supabase
-- Paste this whole file into Supabase > SQL Editor and press Run.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null default '',
  phone text not null default '',
  email text not null default '',
  county text not null default 'Nairobi',
  address text not null default '',
  is_admin boolean not null default false,
  created_at timestamptz not null default now()
);

create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, name, phone, email)
  values (new.id,
          coalesce(new.raw_user_meta_data->>'name',''),
          coalesce(new.raw_user_meta_data->>'phone',''),
          coalesce(new.raw_user_meta_data->>'email',''));
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute function public.handle_new_user();
revoke execute on function public.handle_new_user() from public, anon, authenticated;

create or replace function public.is_admin() returns boolean
language sql security definer stable set search_path = public as $$
  select coalesce((select is_admin from public.profiles where id = auth.uid()), false)
$$;

create table if not exists public.products (
  id integer primary key,
  name text not null,
  cat text not null,
  price integer not null check (price > 0),
  old integer not null default 0,
  stock integer not null default 0 check (stock >= 0),
  rating numeric not null default 4.5,
  spec jsonb not null default '[]',
  hidden boolean not null default false,
  image text not null default ''
);

create table if not exists public.orders (
  id text primary key,
  user_id uuid not null references public.profiles(id),
  contact_name text,
  contact_phone text,
  items jsonb not null,
  fee integer not null default 0,
  county text,
  address text,
  pay text,
  total integer not null,
  stage integer not null default 0 check (stage between 0 and 4),
  times jsonb not null default '{}',
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.products enable row level security;
alter table public.orders enable row level security;

-- profiles: you read and edit your own delivery details; nobody can make themselves admin
drop policy if exists "read own profile" on public.profiles;
create policy "read own profile" on public.profiles for select using (id = auth.uid() or public.is_admin());
drop policy if exists "update own profile" on public.profiles;
create policy "update own profile" on public.profiles for update using (id = auth.uid()) with check (id = auth.uid());
revoke insert, update, delete on public.profiles from anon, authenticated;
grant update (name, phone, email, county, address) on public.profiles to authenticated;

-- products: everyone sees live products, only the admin sees hidden ones and changes anything
drop policy if exists "read live products" on public.products;
create policy "read live products" on public.products for select using (not hidden or public.is_admin());
drop policy if exists "admin adds products" on public.products;
create policy "admin adds products" on public.products for insert with check (public.is_admin());
drop policy if exists "admin edits products" on public.products;
create policy "admin edits products" on public.products for update using (public.is_admin()) with check (public.is_admin());
drop policy if exists "admin removes products" on public.products;
create policy "admin removes products" on public.products for delete using (public.is_admin());

-- orders: customers place and read their own, the admin reads all and updates the status
drop policy if exists "read own orders" on public.orders;
create policy "read own orders" on public.orders for select using (user_id = auth.uid() or public.is_admin());
drop policy if exists "place own order" on public.orders;
drop policy if exists "admin updates orders" on public.orders;
create policy "admin updates orders" on public.orders for update using (public.is_admin()) with check (public.is_admin());
revoke insert, delete on public.orders from public, anon, authenticated;

create or replace function public.place_customer_order(
  p_items jsonb,
  p_county text,
  p_address text,
  p_contact_name text,
  p_contact_phone text,
  p_pay text
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_item jsonb;
  v_product_id integer;
  v_quantity integer;
  v_product record;
  v_order_items jsonb := '[]'::jsonb;
  v_seen_ids integer[] := array[]::integer[];
  v_subtotal bigint := 0;
  v_fee integer;
  v_total bigint;
  v_order_id text;
  v_item_count integer;
begin
  if v_user_id is null then
    raise exception 'Sign in before placing an order.';
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' then
    raise exception 'Order items must be a list.';
  end if;
  v_item_count := jsonb_array_length(p_items);
  if v_item_count < 1 or v_item_count > 50 then
    raise exception 'An order must contain between 1 and 50 products.';
  end if;
  if p_county is null or p_county not in ('Nairobi', 'Kiambu', 'Nakuru', 'Mombasa', 'Kisumu', 'Tharaka-Nithi', 'Other county') then
    raise exception 'Choose a valid delivery county.';
  end if;
  if p_address is null or length(btrim(p_address)) < 5 or length(p_address) > 500 then
    raise exception 'Enter a valid delivery address.';
  end if;
  if p_contact_name is null or length(btrim(p_contact_name)) < 2 or length(p_contact_name) > 120 then
    raise exception 'Enter a valid contact name.';
  end if;
  if p_contact_phone is null or length(btrim(p_contact_phone)) < 7 or length(p_contact_phone) > 20 then
    raise exception 'Enter a valid contact phone number.';
  end if;
  if p_pay is null or p_pay not in ('M-Pesa (demo)', 'Pay on delivery') then
    raise exception 'Choose a valid payment method.';
  end if;

  for v_item in select value from jsonb_array_elements(p_items) as items(value)
  loop
    if jsonb_typeof(v_item) <> 'object'
       or coalesce(v_item->>'id', '') !~ '^[1-9][0-9]*$'
       or coalesce(v_item->>'q', '') !~ '^[1-9][0-9]*$' then
      raise exception 'Each order item must have a valid product and quantity.';
    end if;
    if (v_item->>'id')::numeric > 2147483647 or (v_item->>'q')::numeric > 2147483647 then
      raise exception 'A product or quantity is out of range.';
    end if;
    v_product_id := (v_item->>'id')::integer;
    if v_product_id = any(v_seen_ids) then
      raise exception 'A product may only appear once in the order.';
    end if;
    v_seen_ids := array_append(v_seen_ids, v_product_id);
  end loop;

  for v_item in
    select value
    from jsonb_array_elements(p_items) as items(value)
    order by (value->>'id')::integer
  loop
    v_product_id := (v_item->>'id')::integer;
    v_quantity := (v_item->>'q')::integer;
    select name, price, stock, hidden
      into v_product
      from public.products
      where id = v_product_id
      for update;
    if not found or v_product.hidden then
      raise exception 'A product in this order is unavailable.';
    end if;
    if v_quantity > v_product.stock then
      raise exception 'There is not enough stock for a product in this order.';
    end if;
    v_subtotal := v_subtotal + v_product.price::bigint * v_quantity::bigint;
    v_order_items := v_order_items || jsonb_build_array(jsonb_build_object(
      'id', v_product_id,
      'q', v_quantity,
      'name', v_product.name,
      'price', v_product.price
    ));
  end loop;

  v_fee := case
    when v_subtotal >= 15000 then 0
    else case p_county
      when 'Nairobi' then 250
      when 'Kiambu' then 300
      when 'Nakuru' then 350
      when 'Mombasa' then 450
      when 'Kisumu' then 450
      when 'Tharaka-Nithi' then 400
      else 500
    end
  end;
  v_total := v_subtotal + v_fee;
  if v_total > 2147483647 then
    raise exception 'The order total is out of range.';
  end if;

  v_order_id := 'AIO-' || upper(gen_random_uuid()::text);
  insert into public.orders (
    id, user_id, contact_name, contact_phone, items, fee, county, address, pay, total, stage, times
  ) values (
    v_order_id, v_user_id, btrim(p_contact_name), btrim(p_contact_phone),
    v_order_items, v_fee, p_county, btrim(p_address), p_pay, v_total, 0,
    jsonb_build_object('0', now())
  );

  return jsonb_build_object('id', v_order_id, 'total', v_total, 'pay', p_pay);
end;
$$;

revoke all on function public.place_customer_order(jsonb, text, text, text, text, text) from public, anon, authenticated;
grant execute on function public.place_customer_order(jsonb, text, text, text, text, text) to authenticated;

-- product photos
insert into storage.buckets (id, name, public) values ('products', 'products', true) on conflict (id) do nothing;
drop policy if exists "admin adds product photos" on storage.objects;
create policy "admin adds product photos" on storage.objects for insert to authenticated with check (bucket_id = 'products' and public.is_admin());
drop policy if exists "admin edits product photos" on storage.objects;
create policy "admin edits product photos" on storage.objects for update to authenticated using (bucket_id = 'products' and public.is_admin());
drop policy if exists "admin removes product photos" on storage.objects;
create policy "admin removes product photos" on storage.objects for delete to authenticated using (bucket_id = 'products' and public.is_admin());

-- starter products
insert into public.products (id, name, cat, price, old, stock, rating, spec, hidden, image) values
  (1,'Android smartphone 6.7" 8GB / 256GB','phones',28900,34500,12,4.6,'["6.7-inch AMOLED display", "8GB RAM, 256GB storage", "5000mAh battery, fast charging", "Dual SIM, 1-year warranty"]'::jsonb,false,''),
  (2,'Budget smartphone 6.5" 4GB / 128GB','phones',12500,0,25,4.3,'["6.5-inch HD+ display", "4GB RAM, 128GB storage", "5000mAh battery", "Dual SIM, 1-year warranty"]'::jsonb,false,''),
  (3,'Wireless earbuds with noise cancelling','electronics',4200,5800,18,4.4,'["Active noise cancelling", "Up to 24 hours with case", "Touch controls", "Charging case included"]'::jsonb,false,''),
  (4,'Laptop 15.6" Core i5, 16GB, 512GB SSD','computers',68000,74500,6,4.7,'["15.6-inch Full HD display", "Core i5, 16GB RAM", "512GB SSD", "Windows 11, 1-year warranty"]'::jsonb,false,''),
  (5,'Student laptop 14" 8GB / 256GB','computers',38500,0,14,4.4,'["14-inch Full HD display", "8GB RAM, 256GB SSD", "Lightweight, 8-hour battery", "1-year warranty"]'::jsonb,false,''),
  (6,'Tablet 10.4" 4GB / 64GB','computers',19800,23000,9,4.3,'["10.4-inch display", "4GB RAM, 64GB storage", "Wi-Fi and SIM slot", "Cover included"]'::jsonb,false,''),
  (7,'Laptop backpack, water-resistant','computers',2400,0,40,4.5,'["Fits up to 15.6-inch laptops", "Water-resistant fabric", "Padded back and straps", "USB charging pass-through"]'::jsonb,false,''),
  (8,'43" smart LED TV','electronics',28500,33900,8,4.5,'["43-inch Full HD", "Built-in apps, Wi-Fi", "3 HDMI, 2 USB ports", "Wall bracket included"]'::jsonb,false,''),
  (9,'55" 4K smart TV','electronics',52000,0,5,4.6,'["55-inch 4K UHD", "HDR, built-in apps", "Voice remote", "1-year warranty"]'::jsonb,false,''),
  (10,'Soundbar 2.1 with Bluetooth','electronics',11500,0,3,4.4,'["2.1 channel with subwoofer", "Bluetooth, HDMI ARC, USB", "120W peak output", "Remote included"]'::jsonb,false,''),
  (11,'Power bank 20,000mAh','electronics',2900,3600,35,4.5,'["20,000mAh capacity", "Fast charging, 2 outputs", "Digital battery display", "Charges a phone 4 to 5 times"]'::jsonb,false,''),
  (12,'Front-load washing machine 8kg','appliances',62500,0,4,4.6,'["8kg capacity", "15 wash programs", "Energy-saving motor", "2-year warranty"]'::jsonb,false,''),
  (13,'Double-door fridge 250L','appliances',54900,59000,7,4.5,'["250 litres, frost-free", "Adjustable shelves", "Low-noise compressor", "2-year warranty"]'::jsonb,false,''),
  (14,'Microwave oven 25L','appliances',11800,0,15,4.3,'["25 litres, 900W", "Grill function", "Digital controls", "1-year warranty"]'::jsonb,false,''),
  (15,'Electric kettle 1.8L','appliances',1650,0,60,4.4,'["1.8 litre capacity", "Auto shut-off", "Boil-dry protection", "Stainless steel body"]'::jsonb,false,''),
  (16,'Air fryer 5L','appliances',7900,9500,16,4.7,'["5 litre basket", "Temperature control to 200 degrees", "Timer and auto shut-off", "Dishwasher-safe basket"]'::jsonb,false,''),
  (17,'Non-stick cookware set, 12 pieces','home',6800,0,20,4.4,'["12 pieces with lids", "Non-stick coating", "Works on gas and electric", "Heat-resistant handles"]'::jsonb,false,''),
  (18,'Cotton bedding set, queen size','home',4500,0,22,4.5,'["Duvet cover, sheet, 2 pillowcases", "100% cotton", "Machine washable", "Several colours"]'::jsonb,false,''),
  (19,'Rechargeable LED lantern','home',1350,0,45,4.2,'["USB rechargeable", "Up to 12 hours light", "3 brightness modes", "Useful during power cuts"]'::jsonb,false,''),
  (20,'Storage organiser set, 6 pieces','home',1900,0,30,4.1,'["6 stackable boxes", "Clear lids", "Fits shelves and wardrobes", "Easy to clean"]'::jsonb,false,''),
  (21,'Men''s cotton polo shirt','clothing',1200,0,80,4.3,'["100% cotton", "Sizes S to XXL", "Machine washable", "Navy, black, white, grey"]'::jsonb,false,''),
  (22,'Women''s casual dress','clothing',2300,2900,24,4.5,'["Soft, breathable fabric", "Sizes S to XL", "Knee length", "Several prints"]'::jsonb,false,''),
  (23,'Unisex fleece hoodie','clothing',2600,0,3,4.6,'["Brushed fleece lining", "Sizes S to XXL", "Front pocket", "Machine washable"]'::jsonb,false,''),
  (24,'Running sneakers','clothing',4400,5500,17,4.4,'["Cushioned sole", "Sizes 38 to 45", "Breathable mesh upper", "Non-slip grip"]'::jsonb,false,'')
on conflict (id) do nothing;
