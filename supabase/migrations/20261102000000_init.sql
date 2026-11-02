-- Gasol: modelo de datos inicial (borrador fase 0, sin aplicar en ningún proyecto remoto)
create extension if not exists postgis;

create type fuel_type as enum ('regular', 'premium', 'diesel');
create type obs_source as enum ('cne', 'community', 'demo');
create type obs_status as enum ('pending', 'published', 'disputed', 'rejected');
create type app_role as enum ('contributor', 'moderator', 'admin');

create table stations (
  id bigint generated always as identity primary key,
  permit_number text unique not null,          -- PL/XXXXX/EXP/ES/AAAA
  cne_place_id text unique,
  name text not null,
  brand text,
  address text,
  location geography(point, 4326) not null,
  status text not null default 'active' check (status in ('active','possibly_closed','closed')),
  last_seen_in_import date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index stations_location_gix on stations using gist (location);

create table station_history (
  id bigint generated always as identity primary key,
  station_id bigint not null references stations(id),
  field text not null, old_value text, new_value text,
  changed_by text not null,                     -- 'import' o id de moderador
  changed_at timestamptz not null default now()
);

-- Disponibilidad declarada: distingue "no disponible" de "sin información" (ausencia de fila)
create table station_fuels (
  station_id bigint references stations(id),
  fuel fuel_type,
  available boolean not null,
  primary key (station_id, fuel)
);

create table profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  role app_role not null default 'contributor',
  reputation int not null default 0,
  created_at timestamptz not null default now()
);

create table price_observations (
  id bigint generated always as identity primary key,
  station_id bigint not null references stations(id),
  fuel fuel_type not null,
  price_mxn numeric(6,2) not null check (price_mxn > 0 and price_mxn < 100),
  source obs_source not null,
  status obs_status not null default 'pending',
  observed_at timestamptz not null,
  reported_by uuid references auth.users(id),   -- null para fuente oficial
  import_run_id bigint,
  outlier_flag boolean not null default false,
  created_at timestamptz not null default now(),
  unique (station_id, fuel, source, observed_at)
);
create index price_obs_lookup on price_observations (station_id, fuel, status, observed_at desc);

create table price_confirmations (
  observation_id bigint references price_observations(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  verdict text not null check (verdict in ('confirm','dispute')),
  created_at timestamptz not null default now(),
  primary key (observation_id, user_id)
);

-- Opinión sobre la estación: independiente de la exactitud del precio
create table station_votes (
  station_id bigint references stations(id),
  user_id uuid references auth.users(id) on delete cascade,
  value smallint not null check (value in (-1, 1)),
  created_at timestamptz not null default now(),
  primary key (station_id, user_id)
);

create table reports (
  id bigint generated always as identity primary key,
  target_type text not null check (target_type in ('station','observation','user')),
  target_id text not null,
  reason text not null check (reason in ('wrong_data','inappropriate','spam','other')),
  details text check (char_length(details) <= 1000),
  reported_by uuid references auth.users(id),
  status text not null default 'open' check (status in ('open','resolved','dismissed')),
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

create table moderation_actions (
  id bigint generated always as identity primary key,
  moderator_id uuid not null references auth.users(id),
  target_type text not null, target_id text not null,
  action text not null,   -- publish, reject, revert, warn, restrict, suspend, lift
  reason text not null,
  report_id bigint references reports(id),
  created_at timestamptz not null default now()
);

create table sanctions (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id),
  kind text not null check (kind in ('warning','restriction','suspension')),
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  action_id bigint references moderation_actions(id),
  appeal_text text, appeal_status text check (appeal_status in ('open','upheld','overturned'))
);

create table import_runs (
  id bigint generated always as identity primary key,
  source text not null, started_at timestamptz not null default now(), finished_at timestamptz,
  stations_seen int, prices_inserted int, errors int, raw_file_path text
);
create table import_errors (
  id bigint generated always as identity primary key,
  run_id bigint references import_runs(id), record_ref text, message text not null
);

-- RLS: lectura pública de datos publicados; escritura solo por funciones del servidor o el propio usuario
alter table stations enable row level security;
alter table station_fuels enable row level security;
alter table price_observations enable row level security;
alter table price_confirmations enable row level security;
alter table station_votes enable row level security;
alter table reports enable row level security;
alter table profiles enable row level security;
alter table moderation_actions enable row level security;
alter table sanctions enable row level security;
alter table station_history enable row level security;
alter table import_runs enable row level security;
alter table import_errors enable row level security;

create policy "stations public read" on stations for select using (true);
create policy "fuels public read" on station_fuels for select using (true);
create policy "published prices public read" on price_observations for select
  using (status = 'published' and source <> 'demo');
create policy "own observations insert" on price_observations for insert to authenticated
  with check (reported_by = auth.uid() and source = 'community' and status = 'pending');
create policy "own confirmations" on price_confirmations for insert to authenticated
  with check (user_id = auth.uid());
create policy "own votes" on station_votes for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own reports insert" on reports for insert to authenticated
  with check (reported_by = auth.uid());
create policy "own profile read" on profiles for select to authenticated using (user_id = auth.uid());
-- Moderación, sanciones e importación: solo service role (funciones del servidor). Pendiente: políticas de moderador.
