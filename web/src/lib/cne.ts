// Parser del catálogo de la CNE. Sin dependencias de base de datos para poder probarlo aislado.
import { XMLParser } from "fast-xml-parser";

export type Fuel = "regular" | "premium" | "diesel";
export const FUELS: Fuel[] = ["regular", "premium", "diesel"];
export type LocationPrecision = "exact" | "approx" | "missing";

export interface CnePlace {
  placeId: string;
  name: string;
  permit: string;
  lon: number | null;
  lat: number | null;
  precision: LocationPrecision;
}

export interface CnePrice {
  placeId: string;
  fuel: Fuel;
  price: number;
}

export interface ParseIssue {
  ref: string;
  message: string;
}

const PRICE_MIN = 15;
const PRICE_MAX = 40;

const parser = new XMLParser({
  ignoreAttributes: false,
  attributeNamePrefix: "@",
  parseTagValue: false,
  isArray: (name) => name === "place" || name === "gas_price",
});

function decimals(raw: string): number {
  const i = raw.indexOf(".");
  return i === -1 ? 0 : raw.length - i - 1;
}

export function parsePlaces(xml: string): { places: CnePlace[]; issues: ParseIssue[] } {
  const doc = parser.parse(xml);
  const items: unknown[] = doc?.places?.place ?? [];
  const places: CnePlace[] = [];
  const issues: ParseIssue[] = [];
  for (const raw of items as Record<string, unknown>[]) {
    const placeId = String(raw["@place_id"] ?? "").trim();
    const name = String(raw.name ?? "").trim();
    const permit = String(raw.cre_id ?? "").trim();
    if (!placeId || !permit || !name) {
      issues.push({ ref: placeId || "?", message: "Estación sin place_id, nombre o permiso" });
      continue;
    }
    const loc = (raw.location ?? {}) as Record<string, unknown>;
    const xs = String(loc.x ?? "").trim();
    const ys = String(loc.y ?? "").trim();
    const x = Number(xs);
    const y = Number(ys);
    let lon: number | null = null;
    let lat: number | null = null;
    let precision: LocationPrecision = "missing";
    if (xs && ys && Number.isFinite(x) && Number.isFinite(y) && x !== 0 && y !== 0) {
      if (x < -118.5 || x > -86.5 || y < 14.4 || y > 32.8) {
        issues.push({ ref: placeId, message: `Coordenada fuera de México (${xs}, ${ys})` });
      } else {
        lon = x;
        lat = y;
        precision = Math.min(decimals(xs), decimals(ys)) <= 2 ? "approx" : "exact";
      }
    }
    places.push({ placeId, name, permit, lon, lat, precision });
  }
  return { places, issues };
}

export function parsePrices(xml: string): { prices: CnePrice[]; issues: ParseIssue[] } {
  const doc = parser.parse(xml);
  const items: unknown[] = doc?.places?.place ?? [];
  const seen = new Map<string, Set<number>>();
  for (const raw of items as Record<string, unknown>[]) {
    const placeId = String(raw["@place_id"] ?? "").trim();
    for (const gp of (raw.gas_price ?? []) as Record<string, unknown>[]) {
      const fuel = String(gp["@type"] ?? "") as Fuel;
      const value = Number(String(gp["#text"] ?? "").trim());
      if (!placeId || !FUELS.includes(fuel) || !Number.isFinite(value)) continue;
      const key = `${placeId}|${fuel}`;
      if (!seen.has(key)) seen.set(key, new Set());
      seen.get(key)!.add(value);
    }
  }
  const prices: CnePrice[] = [];
  const issues: ParseIssue[] = [];
  for (const [key, values] of seen) {
    const [placeId, fuel] = key.split("|") as [string, Fuel];
    if (values.size > 1) {
      issues.push({ ref: placeId, message: `${fuel}: precios distintos en la misma descarga (${[...values].join(", ")})` });
      continue;
    }
    const price = [...values][0];
    if (price < PRICE_MIN || price > PRICE_MAX) {
      issues.push({ ref: placeId, message: `${fuel}: precio fuera de rango (${price})` });
      continue;
    }
    prices.push({ placeId, fuel, price });
  }
  return { prices, issues };
}
