-- Create a profiles table that extends the auth.users table
create table public.profiles (
    id uuid references auth.users on delete cascade primary key,
    username text unique not null,
    email text unique not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable Row Level Security
alter table public.profiles enable row level security;

-- Create policies
create policy "Anyone can view profiles"
    on public.profiles for select
    using ( true );

create policy "Users can create their own profile"
    on public.profiles for insert
    with check ( auth.uid() = id );

create policy "Users can update their own profile"
    on public.profiles for update
    using ( auth.uid() = id );

-- Create function to handle user creation
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
    insert into public.profiles (id, username, email)
    values (
        new.id,
        coalesce(new.raw_user_meta_data->>'username', new.email),
        new.email
    );
    return new;
end;
$$;

-- Create trigger for new user creation
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();

-- Create function to handle profile updates
create or replace function public.handle_user_update()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
    update public.profiles
    set updated_at = now()
    where id = new.id;
    return new;
end;
$$;

-- Create trigger for user updates
drop trigger if exists on_auth_user_updated on auth.users;
create trigger on_auth_user_updated
    after update on auth.users
    for each row execute function public.handle_user_update();

-- Create products table
create table public.products (
    id uuid default gen_random_uuid() primary key,
    name text not null,
    description text,
    price decimal(10,2) not null,
    image_url text,
    stock_quantity integer not null default 0,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Create cart table
create table public.cart_items (
    id uuid default gen_random_uuid() primary key,
    user_id uuid references auth.users on delete cascade not null,
    product_id uuid references public.products on delete cascade not null,
    quantity integer not null default 1,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
    unique(user_id, product_id)
);

-- Create order status type
create type order_status as enum ('pending', 'processing', 'shipped', 'delivered', 'cancelled');

-- Create orders table with delivery information
create table public.orders (
    id uuid default gen_random_uuid() primary key,
    user_id uuid references auth.users on delete cascade not null,
    status order_status not null default 'pending',
    total_amount decimal(10,2) not null,
    delivery_address text not null,
    estimated_delivery timestamp with time zone,
    actual_delivery timestamp with time zone,
    tracking_number text,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Create order items table
create table public.order_items (
    id uuid default gen_random_uuid() primary key,
    order_id uuid references public.orders on delete cascade not null,
    product_id uuid references public.products on delete cascade not null,
    quantity integer not null,
    unit_price decimal(10,2) not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS for all tables
alter table public.products enable row level security;
alter table public.cart_items enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;

-- Policies for products
create policy "Anyone can view products"
    on public.products for select
    using ( true );

-- Policies for cart
create policy "Users can view their own cart"
    on public.cart_items for select
    using ( auth.uid() = user_id );

create policy "Users can insert into their own cart"
    on public.cart_items for insert
    with check ( auth.uid() = user_id );

create policy "Users can update their own cart"
    on public.cart_items for update
    using ( auth.uid() = user_id );

create policy "Users can delete from their own cart"
    on public.cart_items for delete
    using ( auth.uid() = user_id );

-- Policies for orders
create policy "Users can view their own orders"
    on public.orders for select
    using ( auth.uid() = user_id );

create policy "Users can create their own orders"
    on public.orders for insert
    with check ( auth.uid() = user_id );

-- Policies for order items
create policy "Users can view their own order items"
    on public.order_items for select
    using ( exists (
        select 1 from public.orders
        where orders.id = order_items.order_id
        and orders.user_id = auth.uid()
    ) );

-- Function to estimate delivery date (3-5 business days from order date)
create or replace function estimate_delivery_date(order_date timestamp with time zone)
returns timestamp with time zone as $$
begin
    -- Add 3-5 days to the order date
    return order_date + (floor(random() * 3 + 3) || ' days')::interval;
end;
$$ language plpgsql;

-- Function to automatically set estimated delivery date on order creation
create or replace function set_estimated_delivery()
returns trigger as $$
begin
    new.estimated_delivery := estimate_delivery_date(new.created_at);
    return new;
end;
$$ language plpgsql;

-- Trigger to set estimated delivery date
create trigger set_order_delivery_date
    before insert on public.orders
    for each row execute function set_estimated_delivery();

-- Insert sample products
insert into public.products (name, description, price, image_url, stock_quantity)
values 
    ('Smartphone', 'Latest model with high-end features', 999.99, 'https://example.com/smartphone.jpg', 50),
    ('Laptop', 'Powerful laptop for work and gaming', 1499.99, 'https://example.com/laptop.jpg', 30),
    ('Headphones', 'Wireless noise-canceling headphones', 199.99, 'https://example.com/headphones.jpg', 100),
    ('Smartwatch', 'Fitness tracking and notifications', 299.99, 'https://example.com/smartwatch.jpg', 75),
    ('Tablet', '10-inch display with stylus support', 699.99, 'https://example.com/tablet.jpg', 45);
