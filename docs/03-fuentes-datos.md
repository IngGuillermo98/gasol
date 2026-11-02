# Fuentes de datos

Estado de verificación al 2 nov 2026. [H] hecho comprobado, [S] supuesto, [P] pendiente.

## 1. CNE: precios y estaciones (fuente principal)

- **Responsable:** Comisión Nacional de Energía (CNE), que asumió funciones de la antigua CRE.
- **Página:** https://www.cne.gob.mx/ConsultaPrecios/GasolinasyDiesel/GasolinasyDiesel.html
- **Descarga:** XML en `https://publicacionexterna.azurewebsites.net/publicaciones/prices` (precios) y `/publicaciones/places` (estaciones y coordenadas) [S: la ruta `/places` viene de versiones anteriores; se confirma al descargar].
- **Contenido [H]:** precios comerciales que reportan los permisionarios de regular, premium y diésel por estación (número de permiso, nombre, dirección, producto, subproducto, precio). Base: Acuerdo A/041/2018.
- **Frecuencia [H según la página]:** diaria, 18:00 (GMT-6). Frecuencia real: [P] medir 14 días.
- **Acceso [H]:** el endpoint de precios respondió el 2 nov 2026 con datos. Desde el entorno de trabajo de Claude, la descarga directa con `curl` fue bloqueada por la política de red del entorno (no por la CNE).
- **Licencia [P]:** la página no la indica. Revisar datos.gob.mx (conjunto "Estaciones de servicio (gasolineras) y precios finales de gasolina y diésel") y, si no está, solicitarla por escrito.
- **Calidad de coordenadas e identificadores [P]:** el número de permiso (PL/XXXXX/EXP/ES/AAAA) es el identificador estable candidato. Muestreo de 100 estaciones en el piloto.
- **Riesgos:** cambio de dominio o formato (está en un subdominio de Azure), reorganización institucional, precios reportados que no coinciden con bomba.

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
