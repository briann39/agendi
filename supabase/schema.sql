-- Agendi: esquema de base de datos para Supabase
-- Pegar entero en Supabase > SQL Editor > New query > Run.

create extension if not exists pgcrypto;

-- ---------- Tablas ----------
create table if not exists public.businesses (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null check (slug ~ '^[a-z0-9-]{3,40}$'),
  name text not null,
  tagline text,
  address text,
  whatsapp text,                       -- ej 59899123456
  currency text not null default '$',
  slot_minutes int not null default 30 check (slot_minutes between 10 and 120),
  timezone text not null default 'America/Montevideo',
  owner_id uuid references auth.users on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.services (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses on delete cascade,
  name text not null,
  minutes int not null default 30 check (minutes between 5 and 480),
  price numeric not null default 0,
  position int not null default 0,
  active boolean not null default true
);

create table if not exists public.barbers (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses on delete cascade,
  name text not null,
  note text,
  whatsapp text,
  user_id uuid references auth.users on delete set null,
  -- {"1":[10,18],"2":[10,18]} : 0=domingo ... 6=sábado, [abre, cierra] en horas
  hours jsonb not null default '{}'::jsonb,
  position int not null default 0,
  active boolean not null default true
);

create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses on delete cascade,
  barber_id uuid not null references public.barbers on delete cascade,
  service_id uuid references public.services on delete set null,
  service_name text not null,
  day date not null,
  start_min int not null check (start_min between 0 and 1439),
  minutes int not null,
  client_name text not null check (length(client_name) between 1 and 80),
  client_phone text not null check (length(client_phone) between 8 and 20),
  note text check (note is null or length(note) <= 300),
  status text not null default 'pendiente' check (status in ('pendiente','confirmado','cancelado','completado')),
  created_at timestamptz not null default now()
);
create index if not exists bookings_barber_day on public.bookings (barber_id, day);

-- ---------- Seguridad (RLS) ----------
alter table public.businesses enable row level security;
alter table public.services   enable row level security;
alter table public.barbers    enable row level security;
alter table public.bookings   enable row level security;

create or replace function public.is_owner(bid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists(select 1 from businesses where id = bid and owner_id = auth.uid());
$$;

create or replace function public.is_staff(bid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select public.is_owner(bid) or exists(select 1 from barbers where business_id = bid and user_id = auth.uid());
$$;

drop policy if exists biz_read on public.businesses;
create policy biz_read on public.businesses for select to authenticated using (public.is_staff(id));
drop policy if exists biz_write on public.businesses;
create policy biz_write on public.businesses for update to authenticated using (owner_id = auth.uid());

drop policy if exists svc_read on public.services;
create policy svc_read on public.services for select to authenticated using (public.is_staff(business_id));
drop policy if exists svc_write on public.services;
create policy svc_write on public.services for all to authenticated using (public.is_owner(business_id)) with check (public.is_owner(business_id));

drop policy if exists barber_read on public.barbers;
create policy barber_read on public.barbers for select to authenticated using (public.is_staff(business_id));
drop policy if exists barber_update on public.barbers;
create policy barber_update on public.barbers for update to authenticated
  using (user_id = auth.uid() or public.is_owner(business_id))
  with check (user_id = auth.uid() or public.is_owner(business_id));

-- Un barbero ve sus turnos; el dueño ve todos los del negocio
drop policy if exists booking_read on public.bookings;
create policy booking_read on public.bookings for select to authenticated using (
  public.is_owner(business_id) or exists(select 1 from barbers b where b.id = barber_id and b.user_id = auth.uid()));
drop policy if exists booking_update on public.bookings;
create policy booking_update on public.bookings for update to authenticated using (
  public.is_owner(business_id) or exists(select 1 from barbers b where b.id = barber_id and b.user_id = auth.uid()));

-- Los usuarios logueados solo pueden cambiar estas columnas
revoke insert, update, delete on public.bookings from anon, authenticated;
grant select on public.bookings to authenticated;
grant update (status) on public.bookings to authenticated;
revoke insert, update, delete on public.barbers from anon, authenticated;
grant select on public.barbers to authenticated;
grant update (hours, note, whatsapp) on public.barbers to authenticated;
revoke all on public.businesses, public.services, public.barbers, public.bookings from anon;

-- ---------- Funciones públicas (las usa la página de reservas) ----------

-- Datos del negocio para la página pública (sin datos privados)
create or replace function public.public_business(p_slug text) returns json
language sql stable security definer set search_path = public as $$
  select json_build_object(
    'id', b.id, 'slug', b.slug, 'name', b.name, 'tagline', b.tagline, 'address', b.address,
    'whatsapp', b.whatsapp, 'currency', b.currency, 'slot_minutes', b.slot_minutes, 'timezone', b.timezone,
    'today', (now() at time zone b.timezone)::date,
    'now_min', extract(hour from now() at time zone b.timezone)::int * 60 + extract(minute from now() at time zone b.timezone)::int,
    'services', coalesce((select json_agg(json_build_object('id', s.id, 'name', s.name, 'minutes', s.minutes, 'price', s.price) order by s.position, s.name)
                 from services s where s.business_id = b.id and s.active), '[]'::json),
    'barbers', coalesce((select json_agg(json_build_object('id', x.id, 'name', x.name, 'note', x.note, 'hours', x.hours) order by x.position, x.name)
                 from barbers x where x.business_id = b.id and x.active), '[]'::json)
  ) from businesses b where b.slug = p_slug;
$$;

-- Horarios ocupados (solo horas, sin nombres ni teléfonos)
create or replace function public.public_busy(p_business uuid, p_from date, p_to date)
returns table(barber_id uuid, day date, start_min int, minutes int)
language sql stable security definer set search_path = public as $$
  select k.barber_id, k.day, k.start_min, k.minutes from bookings k
  where k.business_id = p_business and k.day between p_from and least(p_to, p_from + 31)
    and k.status <> 'cancelado';
$$;

-- Reservar. p_barber null = cualquiera disponible.
create or replace function public.book(
  p_slug text, p_service uuid, p_barber uuid, p_day date, p_start int,
  p_name text, p_phone text, p_note text default null
) returns json
language plpgsql security definer set search_path = public as $$
declare
  biz businesses; svc services; br barbers; h jsonb; today date; now_min int; chosen barbers; new_id uuid;
begin
  select * into biz from businesses where slug = p_slug;
  if not found then raise exception 'negocio_no_existe'; end if;
  select * into svc from services where id = p_service and business_id = biz.id and active;
  if not found then raise exception 'servicio_no_existe'; end if;
  today := (now() at time zone biz.timezone)::date;
  now_min := extract(hour from now() at time zone biz.timezone)::int * 60 + extract(minute from now() at time zone biz.timezone)::int;
  if p_day < today or p_day > today + 60 or (p_day = today and p_start <= now_min) then raise exception 'horario_pasado'; end if;
  if length(trim(coalesce(p_name,''))) = 0 then raise exception 'falta_nombre'; end if;
  if length(regexp_replace(coalesce(p_phone,''), '\D', '', 'g')) < 8 then raise exception 'telefono_invalido'; end if;

  for br in select * from barbers where business_id = biz.id and active
            and (p_barber is null or id = p_barber) order by position, name loop
    h := br.hours -> extract(dow from p_day)::int::text;
    continue when h is null;
    continue when p_start < (h->>0)::int * 60 or p_start + svc.minutes > (h->>1)::int * 60;
    perform pg_advisory_xact_lock(hashtext(br.id::text || p_day::text));
    continue when exists(select 1 from bookings k where k.barber_id = br.id and k.day = p_day and k.status <> 'cancelado'
                         and k.start_min < p_start + svc.minutes and p_start < k.start_min + k.minutes);
    chosen := br; exit;
  end loop;
  if chosen.id is null then raise exception 'horario_ocupado'; end if;

  insert into bookings(business_id, barber_id, service_id, service_name, day, start_min, minutes, client_name, client_phone, note)
  values (biz.id, chosen.id, svc.id, svc.name, p_day, p_start, svc.minutes, trim(p_name), trim(p_phone), nullif(trim(coalesce(p_note,'')), ''))
  returning id into new_id;

  return json_build_object('id', new_id, 'barber', chosen.name, 'barber_whatsapp', coalesce(chosen.whatsapp, biz.whatsapp));
end;
$$;

grant execute on function public.public_business(text) to anon, authenticated;
grant execute on function public.public_busy(uuid, date, date) to anon, authenticated;
grant execute on function public.book(text, uuid, uuid, date, int, text, text, text) to anon, authenticated;
