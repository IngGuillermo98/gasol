-- Pruebas de permisos y reglas de aportes. Ejecutar: supabase test db
begin;
create extension if not exists pgtap with schema extensions;
select plan(24);

-- Datos de prueba (dentro de la transacción; se descartan al final).
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@prueba.test'),
  ('00000000-0000-0000-0000-00000000000b', 'b@prueba.test'),
  ('00000000-0000-0000-0000-00000000000c', 'c@prueba.test'),
  ('00000000-0000-0000-0000-00000000000d', 'mod@prueba.test');
update profiles set role = 'moderator' where user_id = '00000000-0000-0000-0000-00000000000d';
insert into stations (cne_place_id, permit_number, name, location)
values ('t1', 'PL/T1/EXP/ES/2020', 'Estación prueba', extensions.st_makepoint(-103.35, 20.67)::extensions.geography);
insert into official_prices (station_id, fuel, price_mxn)
select id, 'regular', 24.00 from stations where cne_place_id = 't1';
create temp table ids as select id as sid from stations where cne_place_id = 't1';
grant select on ids to anon, authenticated;

-- Visitante
set local role anon;
select is((select count(*)::int from stations_in_bbox(-103.4, 20.6, -103.3, 20.7) where name = 'Estación prueba'), 1,
  'visitante: ve estaciones por área visible');
select is((select (station_detail(sid)->'prices') from ids), '{}'::jsonb, 'visitante: estación sin precios = sin información');
select throws_ok($$ insert into price_observations (station_id, fuel, price_mxn) select sid, 'regular', 24 from ids $$,
  '42501', null, 'visitante: no puede insertar observaciones directamente');
select throws_ok($$ select submit_observation((select sid from ids), 'regular', 24) $$,
  '42501', null, 'visitante: no puede usar la función de aportes');
select throws_ok($$ select * from official_prices $$, '42501', null, 'visitante: no ve precios internos de la CNE');
select throws_ok($$ select moderation_queue() $$, '42501', null, 'visitante: no accede a moderación');
reset role;

-- Colaborador A propone
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}';
select is((select submit_observation(sid, 'regular', 24.10)->>'status' from ids), 'pending', 'aporte normal queda pendiente');
select throws_ok($$ select submit_observation((select sid from ids), 'regular', 24.20) $$,
  '54000', null, 'límite: no repite el mismo combustible en 30 minutos');
select is((select (submit_observation(sid, 'premium', 45)->>'needs_review')::boolean from ids), true,
  'precio atípico se marca para revisión');
select is((select submit_observation(sid, 'diesel', null, false)->>'status' from ids), 'pending',
  'puede marcar un combustible como no disponible');
select throws_ok($$ select submit_observation((select sid from ids), 'regular', 5) $$,
  '22023', null, 'rechaza precios imposibles');
select throws_ok($$ update price_observations set status = 'published' $$, '42501', null,
  'colaborador: no puede publicar directamente');
select throws_ok($$ select moderation_queue() $$, '42501', null, 'colaborador: no accede a moderación');
reset role;
create temp table obs as select id, fuel from price_observations;
grant select on obs to anon, authenticated;
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}';
select throws_ok($$ select confirm_observation((select id from obs where fuel = 'regular'), 'confirm') $$,
  '42501', null, 'no puede confirmar su propio aporte');
reset role;

-- Colaborador B confirma: se publica
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-00000000000b","role":"authenticated"}';
select is((select confirm_observation((select id from obs where fuel = 'regular'), 'confirm')->>'status'),
  'published', 'una confirmación independiente publica el precio');
select is((select (station_detail(sid)->'prices'->'regular'->>'price')::numeric from ids), 24.10, 'el precio publicado se muestra');
select is((select (confirm_observation((select id from obs where fuel = 'premium'), 'confirm')->>'status')),
  'pending', 'un atípico no se publica solo con confirmaciones');
select lives_ok($$ select vote_station((select sid from ids), 1) $$, 'puede dar like');
select is((select (station_detail(sid)->>'likes')::int from ids), 1, 'el like se cuenta aparte del precio');
select lives_ok($$ select submit_report('station', (select sid from ids), 'wrong_location', 'Está en la otra esquina') $$, 'puede reportar');
reset role;

-- Moderador
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-00000000000d","role":"authenticated"}';
select ok((select jsonb_array_length(moderation_queue()->'reports') = 1), 'moderador: ve la cola de reportes');
select lives_ok($$ select moderate_observation((select id from obs where fuel = 'regular'), 'reject', 'Prueba de reversión') $$,
  'moderador: puede revertir un precio publicado');
select lives_ok($$ select sanction_user('00000000-0000-0000-0000-00000000000c', 'suspension', 7, 'Prueba') $$, 'moderador: puede suspender');
reset role;

-- Usuario suspendido
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-00000000000c","role":"authenticated"}';
select throws_ok($$ select submit_observation((select sid from ids), 'regular', 24) $$, '42501', null,
  'suspendido: no puede aportar');
reset role;

select * from finish();
rollback;
