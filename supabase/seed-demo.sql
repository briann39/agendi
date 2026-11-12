-- Negocio de ejemplo para probar Agendi. Correr después de schema.sql.
-- La página queda en: tu-sitio/?b=el-puerto
insert into public.businesses (slug, name, tagline, address, whatsapp)
values ('el-puerto', 'Barbería El Puerto', 'Cortes clásicos y modernos en Ciudad Vieja', 'Calle de ejemplo 1234, Montevideo', '59899592441')
on conflict (slug) do nothing;

with b as (select id from public.businesses where slug = 'el-puerto')
insert into public.services (business_id, name, minutes, price, position)
select b.id, s.name, s.minutes, s.price, s.pos from b, (values
  ('Corte de pelo', 30, 450, 1),
  ('Corte + barba', 60, 650, 2),
  ('Arreglo de barba', 30, 300, 3),
  ('Corte niños (hasta 12)', 30, 350, 4)
) as s(name, minutes, price, pos)
where not exists (select 1 from public.services x where x.business_id = b.id);

with b as (select id from public.businesses where slug = 'el-puerto')
insert into public.barbers (business_id, name, note, hours, position)
select b.id, x.name, x.note, x.hours::jsonb, x.pos from b, (values
  ('Nico', 'Degradés y diseños', '{"1":[10,18],"2":[10,18],"3":[10,18],"4":[10,18],"5":[10,18]}', 1),
  ('Fede', 'Clásicos y barba', '{"2":[12,20],"3":[12,20],"4":[12,20],"5":[12,21],"6":[9,18]}', 2),
  ('Santi', 'Solo fines de semana', '{"5":[14,21],"6":[9,18]}', 3)
) as x(name, note, hours, pos)
where not exists (select 1 from public.barbers y where y.business_id = b.id);
