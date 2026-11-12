# Agendi

Turnos online para barberías y peluquerías. El cliente reserva solo y el barbero ve sus próximos turnos en su panel.

- `index.html?b=<slug>`: página pública de reservas de cada negocio.
- `barbero.html`: panel del barbero (login, siguiente turno, confirmar o recordar por WhatsApp, marcar atendido, cancelar, editar horarios). El dueño ve a todos los barberos.
- `supabase/schema.sql`: base de datos y reglas de seguridad. Los clientes nunca ven datos de otros clientes; solo ven qué horarios están ocupados.
- `supabase/seed-demo.sql`: barbería de ejemplo (`el-puerto`).

## Puesta en marcha

1. **Supabase** (supabase.com, gratis): New project, región São Paulo. En SQL Editor pegar y correr `supabase/schema.sql` y después `supabase/seed-demo.sql`.
2. En Project Settings > API copiar la Project URL y la anon public key en `config.js`.
3. **Usuarios**: Authentication > Users > Add user (email y contraseña, con "Auto confirm"). Para vincularlos, correr en SQL Editor:
   ```sql
   -- dueño del negocio
   update businesses set owner_id = (select id from auth.users where email = 'dueno@mail.com') where slug = 'el-puerto';
   -- un barbero
   update barbers set user_id = (select id from auth.users where email = 'fede@mail.com') where name = 'Fede';
   ```
4. **Vercel** (vercel.com, gratis, entrar con GitHub): Add New > Project > importar este repositorio > Deploy. No hace falta configurar nada: es un sitio estático.

## Agregar un negocio nuevo

Copiar `seed-demo.sql`, cambiar slug, nombre, servicios, barberos y horarios, y correrlo. Su link queda en `https://<tu-sitio>/?b=<slug>`.

## Próximo paso

WhatsApp automático con la API oficial de Meta (WhatsApp Cloud API). Requiere cuenta de empresa en Meta, un número dedicado y tiene costo por mensaje.
