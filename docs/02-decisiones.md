# Registro de decisiones

| ID | Fecha | Decisión | Razón | Alternativa / salida | Estado |
|---|---|---|---|---|---|
| D-01 | 2026-11-02 | Monolito modular en Next.js 16 + TypeScript, desplegado en Vercel | Un solo proyecto para web, API y SSR; equipo pequeño | Cualquier host Node | Propuesta |
| D-02 | 2026-11-02 | PostgreSQL + PostGIS en Supabase (BD, Auth, Storage, RLS) | Consultas geográficas y permisos en un servicio; Postgres estándar | Neon/RDS + Auth aparte | Propuesta |
| D-03 | 2026-11-02 | MapLibre GL JS para el mapa | Abierto, sin bloqueo de proveedor | Leaflet | Propuesta |
| D-04 | 2026-11-02 | MapTiler Free solo en prototipo privado; antes del piloto público decidir entre MapTiler Flex y Protomaps autoalojado | El plan Free no permite uso comercial; el costo por sesión escala mal | Protomaps (OSM) | Pendiente antes de fase 3 |
| D-05 | 2026-11-02 | Los usuarios crean observaciones; nunca sobrescriben el precio | Historial, moderación y reversión | n/a | Propuesta |
| D-06 | 2026-11-02 | Fuente base: XML diario de la CNE; Profeco solo como referencia | Única fuente oficial por estación conocida hasta ahora | Comunidad | Pendiente de licencia |
| D-07 | 2026-11-02 | Segmento piloto: conductores de alto kilometraje urbano | Frecuencia de carga y comunidades organizadas | Transportistas | Supuesto, a confirmar |
| D-08 | 2026-11-02 | TypeScript 5.9 (el que fija create-next-app 16.4.4), no 7.0 aún | Compatibilidad con herramientas | Migrar a 7 con rama de prueba | Propuesta |
| D-09 | 2026-11-02 | Sin IA dentro del producto en el MVP | No resuelve un problema del MVP | n/a | Decidida por el prompt maestro |
| D-10 | 2026-11-02 | Monitor de la CNE en GitHub Actions programado, con resultados en la rama `cne-monitor` | Gratis, sin servidor y con historial en git; no ensucia `main` | Tarea programada en Supabase o Vercel Cron | Propuesta |
| D-11 | 2026-11-02 | Piloto sin precios de la CNE: los precios los capturan los usuarios. Se usa el catálogo de estaciones de la CNE (nombre, permiso, ubicación) para que haya dónde capturar | Decisión de Guillermo; evita depender de la licencia mientras se pide | Importar precios de la CNE (diseño listo en `03`) | Decidida |
