# Plan de eventos y métricas (borrador v0.1)

Reglas generales: nunca se envían coordenadas precisas, correo, nombre, IP completa ni texto libre a la analítica. La ubicación, si se usa, se reduce a la zona del piloto o al municipio. El identificador es anónimo por dispositivo hasta el registro; después, un id interno con seudónimo. Sin herramientas de publicidad en el MVP.

| Evento | Propósito | Propiedades permitidas | No recopilar |
|---|---|---|---|
| `map_viewed` | Activación y uso | zoom redondeado, municipio, `has_geolocation` (sí/no), combustible filtrado | coordenadas, bbox exacto |
| `search_performed` | Uso de búsqueda sin geolocalización | tipo de resultado (ciudad, colonia, calle), número de resultados | texto buscado |
| `station_opened` | Interés por estación | id de estación, combustible, antigüedad del precio mostrado (días), fuente | ubicación del usuario |
| `navigation_started` | Intención de ir (no es compra) | id de estación, proveedor de navegación | ruta, origen |
| `signup_started` / `signup_completed` | Conversión a colaborador | método (enlace, código) | correo |
| `observation_submitted` | Aporte | id de estación, combustible, diferencia con precio mostrado (rango), tiene foto (no en MVP) | precio exacto + ubicación juntos |
| `observation_resolved` | Calidad y tiempo de moderación | estado final, horas hasta resolver | identidad del moderador |
| `price_confirmed` / `price_disputed` | Confianza comunitaria | id de observación, antigüedad | n/a |
| `report_submitted` | Abuso o errores | tipo de reporte | texto del reporte |
| `station_voted` | Opinión sobre estación | valor (+1/-1) | n/a |
| `offline_viewed` | Uso sin conexión | antigüedad de los datos en caché | n/a |

## Métricas
- **Principal:** consultas útiles semanales (sesión con estación de precio ≤ 7 días del combustible filtrado y ficha abierta o navegación iniciada).
- Activación: % de nuevos visitantes con una consulta útil en su primera sesión.
- Retención semana 1 y 4 por cohorte semanal.
- Conversión a colaborador: % de usuarios activos con ≥ 1 aporte o confirmación al mes.
- Frescura: % de estaciones del piloto con precio ≤ 7 días, por combustible; mediana de antigüedad.
- Moderación: mediana de horas para resolver reportes; % de aportes aceptados, disputados y rechazados.
- Calidad técnica: LCP y INP p75 en móvil, tasa de errores (Sentry).
- Costo de operación por usuario activo mensual.
- Por canal (cuando haya experimentos): costo de adquisición y consultas útiles por canal.
