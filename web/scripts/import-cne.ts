// Importa el catálogo de estaciones de la CNE (y sus precios, solo para uso interno).
// Uso:
//   pnpm import:cne                      descarga los XML de la CNE
//   pnpm import:cne --dir ruta/carpeta   usa places.xml(.gz) y prices.xml(.gz) locales
// Variables: DATABASE_URL (por defecto, la base local de Supabase).
// Es idempotente: correrlo dos veces no duplica estaciones ni precios.
import { readFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { gunzipSync } from "node:zlib";
import path from "node:path";
import pg from "pg";
import { parsePlaces, parsePrices, type ParseIssue } from "../src/lib/cne.ts";

const BASE = "https://publicacionexterna.azurewebsites.net/publicaciones";
const DB = process.env.DATABASE_URL ?? "postgresql://postgres:postgres@127.0.0.1:54322/postgres";

async function load(name: "places" | "prices", dir?: string): Promise<string> {
  if (dir) {
    for (const file of [`${name}.xml`, `${name}.xml.gz`]) {
      const p = path.join(dir, file);
      if (existsSync(p)) {
        const buf = await readFile(p);
        return (file.endsWith(".gz") ? gunzipSync(buf) : buf).toString("utf8");
      }
    }
    throw new Error(`No encontré ${name}.xml ni ${name}.xml.gz en ${dir}`);
  }
  const res = await fetch(`${BASE}/${name}`, { headers: { "User-Agent": "gasol-import/1.0" } });
  if (!res.ok) throw new Error(`La CNE respondió ${res.status} para ${name}`);
  return await res.text();
}

async function main() {
  const dirFlag = process.argv.indexOf("--dir");
  const dir = dirFlag > -1 ? process.argv[dirFlag + 1] : undefined;
  const [placesXml, pricesXml] = await Promise.all([load("places", dir), load("prices", dir)]);
  const { places, issues: placeIssues } = parsePlaces(placesXml);
  const { prices, issues: priceIssues } = parsePrices(pricesXml);
  const issues: ParseIssue[] = [...placeIssues, ...priceIssues];

  const client = new pg.Client({ connectionString: DB });
  await client.connect();
  try {
    await client.query("begin");
    const run = await client.query(
      "insert into import_runs (source) values ($1) returning id",
      [dir ? `cne:file:${dir}` : "cne:url"],
    );
    const runId: number = run.rows[0].id;

    // Historial de cambios de nombre antes del upsert.
    await client.query(
      `insert into station_history (station_id, field, old_value, new_value, changed_by)
       select s.id, 'name', s.name, n.name, 'import'
       from unnest($1::text[], $2::text[]) as n(place_id, name)
       join stations s on s.cne_place_id = n.place_id
       where s.name is distinct from n.name`,
      [places.map((p) => p.placeId), places.map((p) => p.name)],
    );

    const up = await client.query(
      `insert into stations (cne_place_id, permit_number, name, location, location_precision, last_seen_in_import, status)
       select place_id, permit, name,
              case when lon is null then null
                   else extensions.st_setsrid(extensions.st_makepoint(lon, lat), 4326)::extensions.geography end,
              prec::loc_precision, now(), 'active'
       from unnest($1::text[], $2::text[], $3::text[], $4::float8[], $5::float8[], $6::text[])
            as t(place_id, permit, name, lon, lat, prec)
       on conflict (cne_place_id) do update set
         permit_number = excluded.permit_number,
         name = excluded.name,
         location = excluded.location,
         location_precision = excluded.location_precision,
         last_seen_in_import = excluded.last_seen_in_import,
         status = case when stations.status = 'possibly_closed' then 'active' else stations.status end,
         updated_at = case when (stations.name, stations.location_precision) is distinct from (excluded.name, excluded.location_precision)
                             or not extensions.st_equals(coalesce(stations.location::extensions.geometry, 'POINT EMPTY'), coalesce(excluded.location::extensions.geometry, 'POINT EMPTY'))
                           then now() else stations.updated_at end
       returning (xmax = 0) as inserted`,
      [
        places.map((p) => p.placeId),
        places.map((p) => p.permit),
        places.map((p) => p.name),
        places.map((p) => p.lon),
        places.map((p) => p.lat),
        places.map((p) => p.precision),
      ],
    );
    const inserted = up.rows.filter((r) => r.inserted).length;

    await client.query(
      `insert into official_prices (station_id, fuel, price_mxn)
       select s.id, t.fuel::fuel_type, t.price
       from unnest($1::text[], $2::text[], $3::numeric[]) as t(place_id, fuel, price)
       join stations s on s.cne_place_id = t.place_id
       on conflict (station_id, fuel) do update set
         first_seen = case when official_prices.price_mxn <> excluded.price_mxn then now() else official_prices.first_seen end,
         price_mxn = excluded.price_mxn,
         last_seen = now()`,
      [prices.map((p) => p.placeId), prices.map((p) => p.fuel), prices.map((p) => p.price)],
    );

    // Estaciones que dejaron de aparecer 30 días: posible cierre (no se borran).
    await client.query(
      `update stations set status = 'possibly_closed'
       where status = 'active' and last_seen_in_import < now() - interval '30 days'`,
    );

    if (issues.length) {
      await client.query(
        `insert into import_errors (run_id, record_ref, message)
         select $1, ref, msg from unnest($2::text[], $3::text[]) as t(ref, msg)`,
        [runId, issues.map((i) => i.ref), issues.map((i) => i.message)],
      );
    }

    await client.query(
      `update import_runs set finished_at = now(), stations_seen = $2, stations_inserted = $3,
         stations_updated = $4, prices_seen = $5, errors = $6 where id = $1`,
      [runId, places.length, inserted, places.length - inserted, prices.length, issues.length],
    );
    await client.query("commit");

    const mapped = places.filter((p) => p.lon !== null).length;
    console.log(
      `Importación ${runId}: ${places.length} estaciones (${inserted} nuevas, ${mapped} con ubicación), ` +
        `${prices.length} precios internos, ${issues.length} incidencias registradas.`,
    );
  } catch (err) {
    await client.query("rollback");
    throw err;
  } finally {
    await client.end();
  }
}

main().catch((err) => {
  console.error("La importación falló:", err instanceof Error ? err.message : err);
  process.exit(1);
});
