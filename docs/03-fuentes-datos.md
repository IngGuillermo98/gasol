# Fuentes de datos

Estado de verificación al 2 nov 2026 (descarga real de la CNE hecha ese día). [H] hecho comprobado, [S] supuesto, [P] pendiente.

## 1. CNE: precios y estaciones (fuente principal)

- **Responsable:** Comisión Nacional de Energía (CNE), que asumió funciones de la antigua CRE.
- **Página:** https://www.cne.gob.mx/ConsultaPrecios/GasolinasyDiesel/GasolinasyDiesel.html
- **Descarga [H, 2 nov 2026]:** dos XML públicos, sin clave ni registro, solo `GET`:
  - `https://publicacionexterna.azurewebsites.net/publicaciones/places` (estaciones y coordenadas, 3.2 MB, 380 KB comprimido).
  - `https://publicacionexterna.azurewebsites.net/publicaciones/prices` (precios, 2.4 MB, 100 KB comprimido).
  - Ambos respondieron 200 en menos de 1 s. El servidor (IIS/ASP.NET en Azure) no envía `Last-Modified` ni `ETag`, así que **el archivo no dice cuándo se publicó**: la fecha del dato la ponemos nosotros (hora de descarga) y detectamos actualizaciones comparando contra la descarga anterior.
- **Base legal [H]:** Acuerdo A/041/2018 (los permisionarios reportan sus precios).
- **Frecuencia [H según la página]:** diaria, 18:00 (GMT-6). Frecuencia real: [P] se mide con el monitor de 14 días (ver abajo).

### Estructura del XML [H]

`places` (raíz `<places>`):

```xml
<place place_id="2039">
  <name>ESTACION HIPODROMO SA DE CV</name>
  <cre_id>PL/658/EXP/ES/2015</cre_id>
  <location><x>-116.9214</x><y>32.47641</y></location>   <!-- x = longitud, y = latitud, WGS84 -->
</place>
```

`prices` (raíz también `<places>`):

```xml
<place place_id="11702">
  <gas_price type="regular">24.5</gas_price>
  <gas_price type="premium">30.5</gas_price>
  <gas_price type="diesel">27</gas_price>
</place>
```

- Los dos archivos se unen por `place_id`. El número de permiso (`cre_id`) solo está en `places`.
- `type` toma solo tres valores: `regular`, `premium`, `diesel`. Precio en MXN por litro, con IVA [S: la página habla de precio al público].
- **No incluye:** dirección, municipio, estado, marca, horario, servicios ni fecha de reporte. La plantilla anterior de este documento decía que traía dirección; es incorrecto. Municipio y estado se obtendrán por coordenadas (geocodificación inversa) o de otra fuente.

### Conteos y calidad (descarga del 2 nov 2026, 18:45 UTC) [H]

| Indicador | Valor |
|---|---|
| Estaciones en `places` | 15,046 (`place_id` y permiso únicos, sin duplicados) |
| Estaciones con al menos un precio | 13,852 |
| Estaciones sin ningún precio | 1,194 (8 %) |
| Precios cuyo `place_id` no existe en `places` | 0 |
| Estaciones con precio de regular / premium / diésel | 13,785 / 12,996 / 10,521 |
| Mediana regular / premium / diésel (MXN/l) | 23.99 / 28.79 / 27.00 |
| Rango p1 a p99 regular / premium / diésel | 19.29 a 25.39 / 23.49 a 30.24 / 25.35 a 28.59 |
| Precios sospechosos (< 15 o > 40 MXN) | 21 en total (p. ej. 0.01, 1.00, 49.49) |
| Estaciones repetidas en varios bloques `<place>` de `prices` | 1,340 estaciones (1,624 bloques extra), casi siempre con un combustible por bloque |
| Mismo combustible con dos precios distintos en la misma estación | 11 |

**Coordenadas:**

- 5 estaciones sin coordenadas (`x` e `y` vacías) y 85 con coordenada en 0.
- Ninguna coordenada cae fuera de México; no hay latitud y longitud invertidas.
- Precisión por decimales (el menor de x e y): 5 decimales 5,521 (≈1 m); 4 decimales 8,410 (≈11 m); 3 decimales 902 (≈110 m); 2 o menos 123 (≥1 km). Es decir, **~92 % con precisión de calle**; ~7 % aproximadas a la cuadra; <1 % inutilizables para "la más cercana".
- 8 estaciones comparten exactamente la misma coordenada con otra.
- Esto mide precisión numérica, no exactitud. [P] Validar exactitud con una muestra de 100 estaciones de la ciudad piloto contra OSM e imagen satelital.

**Permisos (`cre_id`):** 14,250 con el formato clásico `PL/12345/EXP/ES/2015`. El resto: 359 `PL/…/EXP/ESA/…`, 433 con prefijo `CNE/PL/…` (permisos nuevos de la CNE, supuesto), 3 `PL/…/EXP/ES/MM/…` y 1 `PL/…/TRA/OM/…`. Todos son únicos, así que sirven como identificador estable; el validador debe aceptar estas variantes en lugar de rechazarlas.

### Reglas de importación que se derivan

1. Unir `prices` por `place_id`, fusionando los bloques repetidos de una misma estación.
2. Si un combustible trae dos precios distintos en la misma descarga, guardar ambos en `import_errors` y no publicar ninguno hasta revisar.
3. Precios fuera de 15 a 40 MXN/l: no se muestran; van a `import_errors`.
4. Estaciones sin coordenadas o en 0: se guardan pero no aparecen en el mapa. Coordenadas con 2 decimales o menos: se muestran como "ubicación aproximada".
5. Fecha del precio = fecha de la descarga en que cambió por última vez (el XML no trae fecha). Mostrar "reportado a la CNE, visto por Gasol el …".

### Licencia [P]

- La página de la CNE no indica licencia.
- 2 nov 2026: datos.gob.mx fue rediseñado; la ruta de búsqueda anterior (`/busca/dataset`) da 404 y el buscador del portal nuevo devuelve trámites, no el conjunto de datos. Desde el entorno de Claude el sitio responde 403 (bloqueo del CDN). No se encontró una licencia publicada para estos datos.
- [S] Los conjuntos de datos.gob.mx solían publicarse bajo los **Términos de Libre Uso MX** (uso y redistribución con atribución, sin aparentar respaldo oficial). Fuente secundaria: [wiki de OpenStreetMap, LIBRE USO MX](https://wiki.openstreetmap.org/wiki/ES:LIBRE_USO_MX).
- **Acción:** antes del piloto público, pedir por escrito a la CNE (o por solicitud de transparencia) los términos de uso de los XML. Mientras tanto, mostrar siempre la atribución "Fuente: Comisión Nacional de Energía" con la fecha de consulta.

### Monitor de 14 días [H: script probado; P: corrida programada]

- Script: `scripts/cne_snapshot.py` (solo biblioteca estándar de Python). Descarga ambos XML con reintentos, guarda una copia comprimida del último y escribe `AAAA-MM-DD/summary.json` y una línea en `summaries.jsonl` con: estado HTTP, tamaño, SHA-256, tiempo, conteos, problemas de coordenadas y permisos, estadísticas por combustible y, frente a la corrida anterior, estaciones nuevas, desaparecidas y con precio cambiado.
- Uso local: `python3 scripts/cne_snapshot.py --out data/cne-monitor`.
- Programación: `.github/workflows/cne-monitor.yml`, diario a las 01:30 UTC (19:30 en CDMX, después de la publicación de las 18:00). Guarda los resultados en la rama `cne-monitor` (no toca `main`) y se detiene sola tras 14 corridas. GitHub solo ejecuta tareas programadas desde la rama principal, así que empieza al aprobar el PR; también se puede lanzar a mano desde la pestaña Actions. Usa minutos gratuitos de GitHub Actions (~1 min al día), sin costo.
- Al terminar: informe con frecuencia real de actualización, % de estaciones que cambian por día, estabilidad de conteos y fallas de descarga.

### Riesgos

Cambio de dominio o formato (está en un subdominio de Azure sin versión), reorganización institucional, precios reportados que no coinciden con bomba, ausencia de fecha de publicación en el archivo.

## 2. Profeco: Quién es Quién en los Precios (referencia)
- Reporte semanal en PDF (ej. https://combustibles.profeco.gob.mx/qqpgasolina/2026/QQPGASOLINA_041326.pdf). Útil para validar rangos por región y detectar valores atípicos. No sirve como precio por estación.

## 3. OpenStreetMap (complementaria)
- Mapa base (vía MapTiler o Protomaps) y, opcionalmente, POIs `amenity=fuel` para contrastar ubicaciones. Licencia ODbL: requiere atribución y compartir mejoras a la base.

## 4. Comunidad
- Observaciones con usuario, fecha y estado (pendiente, publicada, disputada, rechazada). Se guardan aparte de los datos oficiales.

## 5. Descartadas por ahora
- Extractores de terceros (p. ej. actores de Apify que reempaquetan los datos de la CNE): agregan dependencia y costo sin dar más derechos.

## Diseño de importación (borrador)
1. Descargar XML a almacenamiento con fecha (respaldo bruto).
2. Parsear y validar con Zod; errores a la tabla `import_errors`.
3. `upsert` de estaciones por número de permiso; cambios de nombre o marca guardados en historial.
4. Insertar precios oficiales como observaciones `source = 'cne'` con su fecha, sin duplicar (clave única estación + combustible + fecha de reporte).
5. Estaciones ausentes 30 días seguidos: marcar "posible cierre" para revisión, no borrar.
6. Registro de corrida (`import_runs`) con conteos; alerta si cae > 10 % el número de estaciones.
