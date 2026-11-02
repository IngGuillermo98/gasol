import { describe, expect, it } from "vitest";
import { parsePlaces, parsePrices } from "../cne";

const places = `<?xml version="1.0" encoding="utf-8"?><places>
<place place_id="1"><name>ESTACION A</name><cre_id>PL/1/EXP/ES/2015</cre_id><location><x>-103.35123</x><y>20.67456</y></location></place>
<place place_id="2"><name>ESTACION B</name><cre_id>PL/2/EXP/ES/2015</cre_id><location><x>-103.3</x><y>20.6</y></location></place>
<place place_id="3"><name>ESTACION C</name><cre_id>CNE/PL/3/EXP/ES/2025</cre_id><location><x></x><y></y></location></place>
<place place_id="4"><name>ESTACION D</name><cre_id>PL/4/EXP/ES/2015</cre_id><location><x>0</x><y>0</y></location></place>
</places>`;

const prices = `<places>
<place place_id="1"><gas_price type="regular">23.99</gas_price><gas_price type="premium">28.5</gas_price></place>
<place place_id="1"><gas_price type="diesel">27</gas_price></place>
<place place_id="2"><gas_price type="regular">24</gas_price></place>
<place place_id="2"><gas_price type="regular">24.5</gas_price></place>
<place place_id="3"><gas_price type="regular">0.01</gas_price></place>
</places>`;

describe("parsePlaces", () => {
  const { places: out } = parsePlaces(places);
  it("lee todas las estaciones con su permiso", () => {
    expect(out.map((p) => p.permit)).toEqual([
      "PL/1/EXP/ES/2015", "PL/2/EXP/ES/2015", "CNE/PL/3/EXP/ES/2025", "PL/4/EXP/ES/2015",
    ]);
  });
  it("clasifica la precisión de la ubicación", () => {
    expect(out.map((p) => p.precision)).toEqual(["exact", "approx", "missing", "missing"]);
    expect(out[0]).toMatchObject({ lon: -103.35123, lat: 20.67456 });
    expect(out[2].lon).toBeNull();
  });
});

describe("parsePrices", () => {
  const { prices: out, issues } = parsePrices(prices);
  it("une bloques repetidos de la misma estación", () => {
    expect(out.filter((p) => p.placeId === "1").map((p) => p.fuel).sort()).toEqual(["diesel", "premium", "regular"]);
  });
  it("no publica precios contradictorios ni fuera de rango y los registra", () => {
    expect(out.some((p) => p.placeId === "2" || p.placeId === "3")).toBe(false);
    expect(issues).toHaveLength(2);
  });
});
