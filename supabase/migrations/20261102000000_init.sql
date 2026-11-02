-- Gasol: esquema inicial del MVP.
-- Principios: los usuarios crean observaciones (nunca sobrescriben); las lecturas públicas pasan por
-- funciones que no exponen datos personales; los permisos se aplican aquí (RLS + funciones), no en el cliente.

create extension if not exists postgis with schema extensions;

create type fuel_type as enum ('regular', 'premium', 'diesel');
create type obs_status as enum ('pending', 'published', 'disputed', 'rejected');
create type app_role as enum ('contributor', 'moderator', 'admin');
create type loc_precision as enum ('exact', 'approx', 'missing');

-- ---------------------------------------------------------------- catálogo de estaciones (CNE)
create table stations (
  id bigint generated always as identity primary key,
  cne_place_id text unique not null,
  permit_number text unique not null,
  name text not null,
  location extensions.geography(point, 4326),
  location_precision loc_precision not null default 'exact',
  status text not null default 'active' check (status in ('active', 'possibly_closed', 'closed')),
  last_seen_in_import timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index stations_location_gix on stations using gist (location);

create table station_history (
  id bigint generated always as identity primary key,
  station_id bigint not null references stations(id) on delete cascade,
  field text not null,
  old_value text,
  new_value text,
  changed_by text not null,
  changed_at timestamptz not null default now()
);

-- Precios reportados a la CNE: solo uso interno (detección de atípicos). No se muestran en el piloto (D-10).
create table official_prices (
  station_id bigint references stations(id) on delete cascade,
  fuel fuel_type,
  price_mxn numeric(6, 2) not null,
  first_seen timestamptz not null default now(),
  last_seen timestamptz not null default now(),
  primary key (station_id, fuel)
);

create table import_runs (
  id bigint generated always as identity primary key,
  source text not null,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  stations_seen int,
  stations_inserted int,
  stations_updated int,
  prices_seen int,
  errors int
);
create table import_errors (
  id bigint generated always as identity primary key,
  run_id bigint references import_runs(id) on delete cascade,
  record_ref text,
  message text not null
);

-- ---------------------------------------------------------------- personas
create table profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text check (char_length(display_name) <= 40),
  role app_role not null default 'contributor',
  reputation int not null default 0,
  created_at timestamptz not null default now()
);

create function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (user_id) values (new.id) on conflict do nothing;
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function handle_new_user();

-- ---------------------------------------------------------------- aportes comunitarios
create table price_observations (
  id bigint generated always as identity primary key,
  station_id bigint not null references stations(id) on delete cascade,
  fuel fuel_type not null,
  available boolean not null default true,
  price_mxn numeric(6, 2),
  status obs_status not null default 'pending',
  outlier_flag boolean not null default false,
  outlier_reason text,
  reported_by uuid references auth.users(id) on delete set null,
  observed_at timestamptz not null default now(),
  published_at timestamptz,
  created_at timestamptz not null default now(),
  constraint price_matches_availability check (
    (available and price_mxn is not null and price_mxn between 10 and 60)
    or (not available and price_mxn is null)
  )
);
create index price_obs_current on price_observations (station_id, fuel, status, observed_at desc);
create index price_obs_user on price_observations (reported_by, created_at desc);

create table price_confirmations (
  observation_id bigint references price_observations(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  verdict text not null check (verdict in ('confirm', 'dispute')),
  created_at timestamptz not null default now(),
  primary key (observation_id, user_id)
);

-- Opinión sobre la estación. Independiente de la exactitud del precio.
create table station_votes (
  station_id bigint references stations(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  value smallint not null check (value in (-1, 1)),
  created_at timestamptz not null default now(),
  primary key (station_id, user_id)
);

create table reports (
  id bigint generated always as identity primary key,
  target_type text not null check (target_type in ('station', 'observation')),
  target_id bigint not null,
  reason text not null check (reason in ('wrong_price', 'wrong_location', 'closed', 'inappropriate', 'spam', 'other')),
  details text check (char_length(details) <= 500),
  reported_by uuid references auth.users(id) on delete set null,
  status text not null default 'open' check (status in ('open', 'resolved', 'dismissed')),
  resolution_note text,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

create table moderation_actions (
  id bigint generated always as identity primary key,
  moderator_id uuid references auth.users(id) on delete set null,
  target_type text not null,
  target_id text not null,
  action text not null,
  reason text not null,
  created_at timestamptz not null default now()
);

create table sanctions (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in ('warning', 'restriction', 'suspension')),
  reason text not null,
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  lifted_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  appeal_text text check (char_length(appeal_text) <= 1000),
  appeal_status text check (appeal_status in ('open', 'upheld', 'overturned')),
  appealed_at timestamptz
);

-- ---------------------------------------------------------------- RLS
alter table stations enable row level security;
alter table station_history enable row level security;
alter table official_prices enable row level security;
alter table import_runs enable row level security;
alter table import_errors enable row level security;
alter table profiles enable row level security;
alter table price_observations enable row level security;
alter table price_confirmations enable row level security;
alter table station_votes enable row level security;
alter table reports enable row level security;
alter table moderation_actions enable row level security;
alter table sanctions enable row level security;

-- Lectura directa permitida solo donde no hay datos personales ni internos.
create policy "estaciones: lectura pública" on stations for select using (true);
create policy "perfil: leer el propio" on profiles for select to authenticated using (user_id = auth.uid());
create policy "sanciones: leer las propias" on sanctions for select to authenticated using (user_id = auth.uid());
-- Todo lo demás (escrituras y lecturas sensibles) pasa por las funciones de abajo.

-- ---------------------------------------------------------------- utilidades de permisos
create function is_moderator() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where user_id = auth.uid() and role in ('moderator', 'admin'));
$$;

create function active_sanction(p_user uuid) returns text
language sql stable security definer set search_path = public as $$
  select kind from sanctions
  where user_id = p_user and kind in ('restriction', 'suspension') and lifted_at is null
    and starts_at <= now() and (ends_at is null or ends_at > now())
  order by case kind when 'suspension' then 0 else 1 end limit 1;
$$;

create function require_contributor() returns uuid
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'Necesitas iniciar sesión' using errcode = '42501'; end if;
  if active_sanction(uid) is not null then
    raise exception 'Tu cuenta tiene una restricción activa' using errcode = '42501';
  end if;
  return uid;
end $$;

create function log_action(p_target_type text, p_target_id text, p_action text, p_reason text) returns void
language sql security definer set search_path = public as $$
  insert into moderation_actions (moderator_id, target_type, target_id, action, reason)
  values (auth.uid(), p_target_type, p_target_id, p_action, p_reason);
$$;

-- ---------------------------------------------------------------- precio mostrado
-- Regla: por estación y combustible, la observación publicada más reciente.
-- "No disponible" también es una observación publicada (available = false).
create view current_prices as
select distinct on (station_id, fuel)
  station_id, fuel, available, price_mxn, observed_at, id as observation_id
from price_observations
where status = 'published'
order by station_id, fuel, observed_at desc, id desc;
revoke all on current_prices from anon, authenticated;

create function price_summary(p_station bigint) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_object_agg(fuel, jsonb_build_object(
    'available', available, 'price', price_mxn, 'observed_at', observed_at,
    'age_days', floor(extract(epoch from now() - observed_at) / 86400)::int)), '{}'::jsonb)
  from current_prices where station_id = p_station;
$$;

-- ---------------------------------------------------------------- lectura pública
create function stations_in_bbox(
  min_lon double precision, min_lat double precision,
  max_lon double precision, max_lat double precision,
  max_rows int default 800
) returns table (id bigint, name text, lon double precision, lat double precision,
                 location_precision loc_precision, prices jsonb)
language sql stable security definer set search_path = public, extensions as $$
  select s.id, s.name, st_x(s.location::geometry), st_y(s.location::geometry), s.location_precision,
         price_summary(s.id)
  from stations s
  where s.location is not null and s.status <> 'closed'
    and s.location && st_makeenvelope(min_lon, min_lat, max_lon, max_lat, 4326)::geography
  limit least(greatest(max_rows, 1), 2000);
$$;

create function station_detail(p_station bigint) returns jsonb
language sql stable security definer set search_path = public, extensions as $$
  select jsonb_build_object(
    'id', s.id, 'name', s.name, 'permit_number', s.permit_number, 'status', s.status,
    'lon', st_x(s.location::geometry), 'lat', st_y(s.location::geometry),
    'location_precision', s.location_precision,
    'prices', price_summary(s.id),
    'unconfirmed', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', o.id, 'fuel', o.fuel, 'available', o.available, 'price', o.price_mxn,
        'observed_at', o.observed_at,
        'confirmations', (select count(*) from price_confirmations c where c.observation_id = o.id and verdict = 'confirm'),
        'disputes', (select count(*) from price_confirmations c where c.observation_id = o.id and verdict = 'dispute'),
        'mine', coalesce(o.reported_by = auth.uid(), false),
        'my_verdict', (select verdict from price_confirmations c where c.observation_id = o.id and c.user_id = auth.uid())
      ) order by o.observed_at desc)
      from price_observations o
      where o.station_id = s.id and o.status = 'pending' and not o.outlier_flag
        and o.observed_at > now() - interval '7 days'), '[]'::jsonb),
    'published', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', cp.observation_id, 'fuel', cp.fuel,
        'confirmations', (select count(*) from price_confirmations c where c.observation_id = cp.observation_id and verdict = 'confirm'),
        'mine', coalesce((select reported_by = auth.uid() from price_observations where id = cp.observation_id), false),
        'my_verdict', (select verdict from price_confirmations c where c.observation_id = cp.observation_id and c.user_id = auth.uid())))
      from current_prices cp where cp.station_id = s.id), '[]'::jsonb),
    'likes', (select count(*) from station_votes v where v.station_id = s.id and value = 1),
    'dislikes', (select count(*) from station_votes v where v.station_id = s.id and value = -1),
    'my_vote', (select value from station_votes v where v.station_id = s.id and v.user_id = auth.uid())
  )
  from stations s where s.id = p_station;
$$;

-- ---------------------------------------------------------------- aportes
create function submit_observation(p_station bigint, p_fuel fuel_type, p_price numeric, p_available boolean default true)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := require_contributor();
  v_official numeric;
  v_outlier boolean := false;
  v_reason text;
  v_status obs_status := 'pending';
  v_rep int;
  v_id bigint;
begin
  if not exists (select 1 from stations where id = p_station and status <> 'closed') then
    raise exception 'Estación no encontrada' using errcode = 'P0002';
  end if;
  if p_available and (p_price is null or p_price < 10 or p_price > 60) then
    raise exception 'El precio debe estar entre 10 y 60 MXN por litro' using errcode = '22023';
  end if;
  if (select count(*) from price_observations where reported_by = uid and created_at > now() - interval '24 hours') >= 30 then
    raise exception 'Llegaste al límite de 30 aportes por día' using errcode = '54000';
  end if;
  if exists (select 1 from price_observations where reported_by = uid and station_id = p_station and fuel = p_fuel
             and created_at > now() - interval '30 minutes') then
    raise exception 'Ya registraste este combustible en esta estación hace menos de 30 minutos' using errcode = '54000';
  end if;

  if p_available then
    select price_mxn into v_official from official_prices where station_id = p_station and fuel = p_fuel;
    if p_price < 15 or p_price > 40 then
      v_outlier := true; v_reason := 'Fuera del rango nacional habitual (15 a 40 MXN)';
    elsif v_official is not null and abs(p_price - v_official) > greatest(3, v_official * 0.12) then
      v_outlier := true; v_reason := format('Difiere más de 12 %% del precio reportado a la CNE (%s)', v_official);
    end if;
  end if;

  select reputation into v_rep from profiles where user_id = uid;
  if not v_outlier and coalesce(v_rep, 0) >= 10 then v_status := 'published'; end if;

  insert into price_observations (station_id, fuel, available, price_mxn, status, outlier_flag, outlier_reason,
                                  reported_by, published_at)
  values (p_station, p_fuel, p_available, case when p_available then round(p_price, 2) end, v_status,
          v_outlier, v_reason, uid, case when v_status = 'published' then now() end)
  returning id into v_id;

  return jsonb_build_object('id', v_id, 'status', v_status, 'needs_review', v_outlier);
end $$;

create function confirm_observation(p_observation bigint, p_verdict text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := require_contributor();
  o price_observations;
  v_conf int; v_disp int;
begin
  if p_verdict not in ('confirm', 'dispute') then raise exception 'Respuesta no válida' using errcode = '22023'; end if;
  select * into o from price_observations where id = p_observation for update;
  if not found or o.status not in ('pending', 'published') then
    raise exception 'Observación no disponible' using errcode = 'P0002';
  end if;
  if o.reported_by = uid then raise exception 'No puedes confirmar tu propio aporte' using errcode = '42501'; end if;

  insert into price_confirmations (observation_id, user_id, verdict) values (p_observation, uid, p_verdict)
  on conflict (observation_id, user_id) do update set verdict = excluded.verdict, created_at = now();

  select count(*) filter (where verdict = 'confirm'), count(*) filter (where verdict = 'dispute')
    into v_conf, v_disp from price_confirmations where observation_id = p_observation;

  if o.status = 'pending' and not o.outlier_flag and v_conf >= 1 and v_disp = 0 then
    update price_observations set status = 'published', published_at = now() where id = o.id;
    update profiles set reputation = reputation + 1 where user_id = o.reported_by;
  elsif v_disp >= 2 and v_disp > v_conf then
    update price_observations set status = 'disputed' where id = o.id;
  end if;

  return jsonb_build_object('status', (select status from price_observations where id = o.id),
                            'confirmations', v_conf, 'disputes', v_disp);
end $$;

create function vote_station(p_station bigint, p_value int) returns void
language plpgsql security definer set search_path = public as $$
declare uid uuid := require_contributor();
begin
  if p_value = 0 then
    delete from station_votes where station_id = p_station and user_id = uid;
  elsif p_value in (-1, 1) then
    insert into station_votes (station_id, user_id, value) values (p_station, uid, p_value)
    on conflict (station_id, user_id) do update set value = excluded.value, created_at = now();
  else
    raise exception 'Voto no válido' using errcode = '22023';
  end if;
end $$;

create function submit_report(p_target_type text, p_target_id bigint, p_reason text, p_details text default null)
returns bigint
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); v_id bigint;
begin
  if uid is null then raise exception 'Necesitas iniciar sesión' using errcode = '42501'; end if;
  if (select count(*) from reports where reported_by = uid and created_at > now() - interval '24 hours') >= 10 then
    raise exception 'Llegaste al límite de 10 reportes por día' using errcode = '54000';
  end if;
  insert into reports (target_type, target_id, reason, details, reported_by)
  values (p_target_type, p_target_id, p_reason, nullif(trim(p_details), ''), uid) returning id into v_id;
  return v_id;
end $$;

create function appeal_sanction(p_sanction bigint, p_text text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if coalesce(trim(p_text), '') = '' then raise exception 'Explica por qué apelas' using errcode = '22023'; end if;
  update sanctions set appeal_text = p_text, appeal_status = 'open', appealed_at = now()
  where id = p_sanction and user_id = auth.uid() and appeal_status is null;
  if not found then raise exception 'No se puede apelar esta sanción' using errcode = '42501'; end if;
end $$;

create function my_account() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'role', p.role, 'reputation', p.reputation, 'display_name', p.display_name,
    'restriction', active_sanction(p.user_id),
    'contributions', (select count(*) from price_observations where reported_by = p.user_id),
    'sanctions', coalesce((select jsonb_agg(to_jsonb(s) - 'created_by' order by s.starts_at desc)
                           from sanctions s where s.user_id = p.user_id), '[]'::jsonb))
  from profiles p where p.user_id = auth.uid();
$$;

-- ---------------------------------------------------------------- moderación
create function require_moderator() returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_moderator() then raise exception 'Solo moderadores' using errcode = '42501'; end if;
end $$;

create function moderation_queue() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform require_moderator();
  return jsonb_build_object(
    'observations', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', o.id, 'station_id', o.station_id, 'station_name', s.name, 'fuel', o.fuel,
        'available', o.available, 'price', o.price_mxn, 'status', o.status,
        'outlier_reason', o.outlier_reason, 'observed_at', o.observed_at,
        'reporter', o.reported_by, 'reporter_reputation', p.reputation,
        'confirmations', (select count(*) from price_confirmations c where c.observation_id = o.id and verdict = 'confirm'),
        'disputes', (select count(*) from price_confirmations c where c.observation_id = o.id and verdict = 'dispute'),
        'official_price', (select price_mxn from official_prices op where op.station_id = o.station_id and op.fuel = o.fuel)
      ) order by o.created_at)
      from price_observations o join stations s on s.id = o.station_id
      left join profiles p on p.user_id = o.reported_by
      where o.status in ('pending', 'disputed')), '[]'::jsonb),
    'reports', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', r.id, 'target_type', r.target_type, 'target_id', r.target_id, 'reason', r.reason,
        'details', r.details, 'created_at', r.created_at, 'reporter', r.reported_by,
        'station_id', case when r.target_type = 'station' then r.target_id
                           else (select station_id from price_observations where id = r.target_id) end,
        'station_name', case when r.target_type = 'station' then (select name from stations where id = r.target_id)
                             else (select s.name from price_observations o join stations s on s.id = o.station_id where o.id = r.target_id) end,
        'observation_author', case when r.target_type = 'observation' then (select reported_by from price_observations where id = r.target_id) end
      ) order by r.created_at)
      from reports r where r.status = 'open'), '[]'::jsonb),
    'appeals', coalesce((
      select jsonb_agg(to_jsonb(s) order by s.appealed_at) from sanctions s where s.appeal_status = 'open'), '[]'::jsonb),
    'recent_actions', coalesce((
      select jsonb_agg(to_jsonb(a) order by a.created_at desc)
      from (select * from moderation_actions order by created_at desc limit 30) a), '[]'::jsonb)
  );
end $$;

create function moderate_observation(p_observation bigint, p_action text, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
declare o price_observations;
begin
  perform require_moderator();
  if coalesce(trim(p_reason), '') = '' then raise exception 'Escribe un motivo' using errcode = '22023'; end if;
  select * into o from price_observations where id = p_observation for update;
  if not found then raise exception 'Observación no encontrada' using errcode = 'P0002'; end if;
  if p_action = 'publish' then
    update price_observations set status = 'published', published_at = now(), outlier_flag = false where id = o.id;
    if o.status <> 'published' then update profiles set reputation = reputation + 1 where user_id = o.reported_by; end if;
  elsif p_action = 'reject' then
    -- También sirve para revertir un precio publicado: el mapa vuelve a mostrar el anterior.
    update price_observations set status = 'rejected' where id = o.id;
    if o.status = 'published' then update profiles set reputation = reputation - 1 where user_id = o.reported_by; end if;
  else
    raise exception 'Acción no válida' using errcode = '22023';
  end if;
  perform log_action('observation', o.id::text, p_action, p_reason);
end $$;

create function resolve_report(p_report bigint, p_status text, p_note text) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform require_moderator();
  if p_status not in ('resolved', 'dismissed') then raise exception 'Estado no válido' using errcode = '22023'; end if;
  update reports set status = p_status, resolution_note = p_note, resolved_at = now() where id = p_report;
  perform log_action('report', p_report::text, p_status, coalesce(p_note, ''));
end $$;

create function sanction_user(p_user uuid, p_kind text, p_days int, p_reason text) returns bigint
language plpgsql security definer set search_path = public as $$
declare v_id bigint;
begin
  perform require_moderator();
  if p_user = auth.uid() then raise exception 'No puedes sancionarte a ti mismo' using errcode = '42501'; end if;
  if coalesce(trim(p_reason), '') = '' then raise exception 'Escribe un motivo' using errcode = '22023'; end if;
  insert into sanctions (user_id, kind, reason, ends_at, created_by)
  values (p_user, p_kind, p_reason, case when p_days > 0 then now() + make_interval(days => p_days) end, auth.uid())
  returning id into v_id;
  perform log_action('user', p_user::text, 'sanction:' || p_kind, p_reason);
  return v_id;
end $$;

create function decide_appeal(p_sanction bigint, p_overturn boolean, p_note text) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform require_moderator();
  update sanctions set appeal_status = case when p_overturn then 'overturned' else 'upheld' end,
                       lifted_at = case when p_overturn then now() else lifted_at end
  where id = p_sanction and appeal_status = 'open';
  if not found then raise exception 'Apelación no encontrada' using errcode = 'P0002'; end if;
  perform log_action('sanction', p_sanction::text, case when p_overturn then 'appeal_overturned' else 'appeal_upheld' end, coalesce(p_note, ''));
end $$;

-- ---------------------------------------------------------------- permisos de ejecución
revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function stations_in_bbox, station_detail to anon, authenticated;
grant execute on function submit_observation, confirm_observation, vote_station, submit_report,
  appeal_sanction, my_account, is_moderator, moderation_queue, moderate_observation, resolve_report,
  sanction_user, decide_appeal to authenticated;

-- Las escrituras de la app pasan solo por funciones; las tablas internas no se leen desde el cliente.
revoke insert, update, delete, truncate on all tables in schema public from anon, authenticated;
revoke all on official_prices, import_runs, import_errors, station_history, moderation_actions,
  price_confirmations, station_votes, reports, price_observations from anon, authenticated;
