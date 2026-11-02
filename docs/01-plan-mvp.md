# Gasol: plan del MVP

Versión 0.1 · 2 de noviembre de 2026 · Estado: propuesta para aprobación de Guillermo

Convención: **[H]** hecho comprobado (con fuente), **[S]** supuesto o hipótesis, **[P]** decisión pendiente.

## 1. Producto e hipótesis

**Problema.** Quien carga combustible en México no sabe, antes de llegar, cuánto cobra cada estación ni si el dato es reciente. El gobierno publica los precios que reportan los permisionarios, pero en formatos poco usables (XML diario, búsqueda por estado y municipio) y sin confirmación de lo que se cobra en bomba.

**Propuesta de valor.** Una web móvil, gratuita y sin registro, que muestra en mapa y lista las estaciones cercanas con el precio por litro de regular, premium y diésel, siempre con fecha, fuente y nivel de confianza; y que permite a la comunidad confirmar o corregir esos precios.

**Diferenciación frente a lo existente.** Ya existen el buscador oficial de la CNE, los reportes semanales "Quién es Quién" de Profeco y apps comerciales. La oportunidad de Gasol está en: (1) transparencia sobre procedencia y antigüedad de cada precio, (2) confirmación comunitaria separada de las opiniones sobre la estación, (3) experiencia móvil cuidada y rápida, (4) más adelante, funciones para transportistas (diésel por corredor). [S] La revisión de competidores se completa en la fase 0.

**Hipótesis a validar con el MVP**

| # | Hipótesis | Cómo se mide | Umbral para seguir |
|---|---|---|---|
| H1 | La gente consulta precios antes de cargar si el dato es claro y reciente | % de visitantes que abren una ficha o la lista con precios | ≥ 40 % de sesiones |
| H2 | Los usuarios vuelven | Retención semana 4 por cohorte | ≥ 15 % |
| H3 | Una parte de usuarios aporta o confirma precios | % de usuarios activos que confirman o proponen al menos 1 precio al mes | ≥ 3 % |
| H4 | El precio reportado a la CNE difiere a veces del de bomba, y eso le importa al usuario | % de observaciones que difieren > 0.30 MXN/L del reporte oficial | Se mide; no tiene umbral |
| H5 | Podemos mantener precios recientes en la zona piloto | % de estaciones del piloto con precio de ≤ 7 días | ≥ 80 % (oficial o comunitario) |

**Métrica principal (North Star) propuesta:** *consultas útiles semanales*: sesiones en las que el usuario vio al menos una estación con precio de ≤ 7 días del combustible que filtró, y abrió su ficha o inició navegación. No cuenta visitas sin información útil.

## 2. Segmento y piloto

**Segmento prioritario [S, propuesta]: conductores de alto kilometraje urbano** (repartidores, choferes de plataforma, taxistas). Razones: cargan varias veces por semana, son sensibles al precio, están concentrados en una ciudad y organizados en grupos de WhatsApp y Facebook, lo que facilita conseguir colaboradores iniciales. Los transportistas de carga son el segundo segmento: su necesidad (diésel en carretera, por ruta) pide funciones que no entran en el MVP.

**Piloto geográfico [P]:** una zona metropolitana donde Guillermo pueda hacer entrevistas y visitas. Los datos oficiales cubren todo el país desde el primer día; el piloto define dónde se recluta comunidad, se mide y se modera.

**Datos y colaboradores antes de tener comunidad:** precios oficiales de la CNE como base; 10 a 20 colaboradores fundadores reclutados en grupos de conductores; recorridos de verificación propios en una muestra de 30 estaciones para medir la diferencia entre el reporte oficial y la bomba.

## 3. Alcance

**MVP**
- Mapa mundial; fuera de México, aviso claro "todavía no hay servicio aquí".
- Estaciones cargadas por área visible, con agrupación de marcadores y alternativa en lista.
- Búsqueda por ubicación sin compartir geolocalización, y "cerca de mí" opcional.
- Filtro por combustible (regular, premium, diésel), con etiqueta de texto además de color.
- Ficha de estación: precios con fecha, fuente y confianza; estados "no disponible", "sin información" y precio válido; botón de indicaciones en servicio externo.
- Registro (correo con enlace o código) para proponer, confirmar o disputar precios.
- Like o dislike de la estación, separado del precio.
- Reportar error o contenido inapropiado.
- Panel privado de moderación: cola de observaciones y reportes, decisiones con historial, advertencias y suspensiones temporales, apelación básica.
- Importación diaria automática de estaciones y precios oficiales.
- PWA instalable; sin conexión solo muestra la última consulta, marcada con su fecha y "sin conexión".
- Aviso de privacidad, términos de uso y analítica sin ubicación precisa.

**Siguiente versión:** fotografía opcional como evidencia (con borrado de metadatos y difuminado), reputación avanzada y detección de cuentas coordinadas, cálculo de ahorro con supuestos visibles, alertas de precio, búsqueda por ruta o corredor para transportistas.

**Futuro:** servicios para flotillas, patrocinios identificados, otros combustibles (gas LP, eléctrico), otros países, app nativa.

**Fuera del MVP de forma explícita:** IA dentro del producto, publicidad, cálculo de rutas propio.

## 4. Tecnología (decisión temprana)

Versiones comprobadas el 2 nov 2026 instalando y compilando un esqueleto (`pnpm build` y `pnpm lint` sin errores).

| Capa | Elección | Versión | Razón | Salida si falla |
|---|---|---|---|---|
| Lenguaje | TypeScript | 5.9.3 (la que fija create-next-app; TS 7 se evalúa después) | Tipos compartidos entre front y back | n/a |
| Web | Next.js (App Router) + React | 16.4.4 + 19.3 | SSR para SEO de fichas, rutas de API, un solo proyecto | Cualquier host Node; o Vite + API aparte |
| Estilos | Tailwind CSS + componentes accesibles (Radix/React Aria, por decidir en diseño) | 4.3.3 | Rapidez y consistencia | CSS propio |
| Mapa | MapLibre GL JS | 6.16.0 | Abierto, sin bloqueo de proveedor | Leaflet |
| Teselas y búsqueda | MapTiler (prototipo) → evaluar Protomaps autoalojado para piloto | n/a | MapTiler Free no permite uso comercial | Protomaps (OSM) en almacenamiento propio |
| BD | PostgreSQL + PostGIS en Supabase | Supabase CLI 3.0.0 | Consultas por área, Auth, almacenamiento y RLS en un servicio | Postgres gestionado (Neon, RDS) + Auth aparte; es Postgres estándar |
| Cliente BD | @supabase/supabase-js + @supabase/ssr | 2.118.0 / 0.12.7 | Sesiones en servidor | n/a |
| Validación | Zod | 4.6.7 | Validar entradas en servidor | n/a |
| Tareas | Cron de Supabase (pg_cron) o de Vercel para la importación diaria | n/a | Sin servidores extra | GitHub Actions programado |
| Pruebas | Vitest + Playwright | 5.1.0 / 1.64.1 | Unitarias y recorridos móviles | n/a |
| Código | GitHub (repositorio privado) | n/a | Código, tareas, revisión | n/a |
| Hosting | Vercel | n/a | Integración nativa con Next.js | Netlify, Railway, Fly |
| Analítica / errores | PostHog / Sentry (planes gratuitos, por verificar) | n/a | Eventos y errores desde el día 1 | Plausible / GlitchTip |

Arquitectura: un monolito modular de Next.js (módulos: mapa, estaciones, precios, contribuciones, moderación, cuentas, importación) sobre una base de datos Postgres. Permisos aplicados en servidor y con Row Level Security. Sin microservicios.

**Regla para el precio mostrado (borrador):** por estación y combustible se muestra la observación publicada más reciente dentro de su vigencia (oficial: fecha del reporte; comunitaria: publicada con 2 confirmaciones independientes o colaborador de confianza). Más de 7 días: "precio antiguo". Más de 30 días: "sin información reciente". Todo cambio queda en historial y se puede revertir.

## 5. Fuentes de datos (plan de verificación)

Detalle en `03-fuentes-datos.md`. Fuente principal: publicación diaria de la **CNE** (antes CRE) con precios por estación en XML (`publicacionexterna.azurewebsites.net/publicaciones/prices` y `/places`), actualizada a las 18:00 (GMT-6) según [la página de la CNE](https://www.cne.gob.mx/ConsultaPrecios/GasolinasyDiesel/GasolinasyDiesel.html). [H] El endpoint de precios respondió hoy con datos. [P] Licencia de reutilización no indicada en esa página; hay que confirmarla en datos.gob.mx o pedirla por escrito. Profeco publica cada semana el reporte "Quién es Quién en los Precios", útil como referencia, no por estación.

## 6. Presupuesto preliminar

Tipo de cambio: 18.65 MXN/USD (FIX Banxico reportado el 28 oct 2026, [fuente](https://www.elcongresista.mx/dolar-en-mexico-28-octubre-2026)). Precios en USD sin IVA; [S] los precios de terceros vienen de reseñas de 2026 y se confirman en las páginas oficiales antes de contratar.

| Concepto | Prototipo (privado, ~20 usuarios) | Piloto (≈ 2,000 usuarios activos/mes, 30k sesiones de mapa) | Crecimiento (≈ 20,000 usuarios/mes, 300k sesiones) |
|---|---|---|---|
| Hosting Vercel | Hobby $0 (no comercial) | Pro $20 | Pro $20 + uso ≈ $20 |
| Supabase | Free $0 (se pausa tras 1 semana sin uso) | Pro $25 | Pro $25 + cómputo ≈ $15 + almacenamiento |
| Mapas | MapTiler Free $0 (5k sesiones, no comercial) | MapTiler Flex $30 + excedente ≈ $12.50; o Protomaps ≈ $0 a $5 | Protomaps autoalojado ≈ $5 a $20 (con MapTiler serían ≈ $700) |
| Correo transaccional | $0 | $0 a $20 | $20 |
| Analítica y errores | $0 | $0 | $0 a $50 |
| **Mensual fijo + variable** | **$0** | **≈ $45 a $110 (≈ 840 a 2,050 MXN)** | **≈ $100 a $170 (≈ 1,900 a 3,200 MXN)** |
| Dominio (.mx, anual) | ≈ 500 a 900 MXN [S] | igual | igual |
| Revisión legal (aviso de privacidad, términos) | n/a | 8,000 a 25,000 MXN, única vez [S] | n/a |
| Desarrollo y diseño | Trabajo con Claude dentro de tu plan actual [P] | igual | igual |
| Moderación y soporte | Guillermo, horas propias [P] | 3 a 5 h/semana | Requiere apoyo |
| Marketing (experimentos) | $0 | ≤ 3,000 MXN/mes, solo con autorización | Por resultados |
| Contingencia | n/a | 20 % del mensual | 20 % |

Supuestos de uso (piloto): 15 sesiones de mapa por usuario al mes, 3 búsquedas por usuario al mes, 0 fotos (fuera del MVP), transferencia < 50 GB/mes. Alertas: tope de gasto en Vercel, alertas de uso en Supabase y MapTiler al 50 %, 80 % y 100 %; al 80 % se reduce la carga (zoom mínimo para mostrar estaciones, caché de teselas). Nadie garantiza operar gratis indefinidamente.

## 7. Riesgos principales

| Riesgo | Cómo lo comprobamos | Mitigación |
|---|---|---|
| La fuente oficial cambia, se cae o su licencia no permite reutilizar | Descargar 14 días seguidos y registrar disponibilidad; confirmar licencia | Guardar históricos propios; aviso claro de fuente; contacto con CNE |
| Coordenadas o identificadores de estaciones con errores | Muestreo de 100 estaciones del piloto contra mapa y visita | Reportes de ubicación; corrección moderada |
| Pocos colaboradores | Reclutar 10 a 20 fundadores antes del piloto | Datos oficiales como base, confirmación en 1 toque |
| Abuso o manipulación de precios | Pruebas de límites, cola de moderación, valores atípicos | Observaciones en vez de sobrescritura, confirmaciones independientes |
| Costos de mapas al crecer | Medir sesiones reales en el piloto | Teselas autoalojadas |
| Obligaciones legales (LFPDPPP 2025, publicidad, contenido de usuarios) | Revisión profesional antes del lanzamiento público | Minimizar datos; aviso de privacidad |

## 8. Fases y criterios de verificación

| Fase | Duración estimada | Entregables | Criterios de aceptación |
|---|---|---|---|
| **0. Descubrimiento y fundaciones** | 1 a 2 semanas | Repositorio con AGENTS.md y docs; verificación de fuentes (14 días de descargas); modelo de datos y contratos de API; recorridos y wireframes móviles; plan de eventos; aviso de privacidad borrador | Fuentes documentadas con licencia o pendiente explícito; modelo de datos revisado; wireframes de los 7 recorridos aprobados por Guillermo |
| **1. Consulta (alfa privada)** | 2 a 3 semanas | Importación diaria idempotente; mapa y lista por área visible; búsqueda; filtros; ficha; navegación externa; aviso fuera de cobertura; PWA | La importación corre 2 veces sin duplicados y registra errores; consulta por área < 300 ms en BD; Lighthouse móvil ≥ 85 en rendimiento y ≥ 95 en accesibilidad; Playwright cubre consulta, búsqueda y ficha en viewport móvil; ningún dato de demostración se muestra como real |
| **2. Contribución** | 2 a 3 semanas | Registro; proponer, confirmar y disputar; reportes; like/dislike; límites de frecuencia; historial | Pruebas automáticas de permisos (visitante, colaborador, moderador, admin) contra RLS; un usuario no puede sobrescribir precios; límites de frecuencia probados; estados de observación correctos |
| **3. Moderación y piloto cerrado** | 2 semanas + 4 semanas de piloto | Panel de moderación; sanciones y apelación; valores atípicos; analítica; monitoreo; respaldo y prueba de restauración | Caso de moderación completo verificado de punta a punta; restauración probada; tablero con métricas H1 a H5; **lanzamiento público solo con autorización de Guillermo** |

## 9. Primera fase: tareas

| # | Tarea | Responsable | Prioridad | Depende de | Criterio de aceptación |
|---|---|---|---|---|---|
| 0.1 | Crear repositorio y subir esqueleto + docs | Guillermo (crear repo) y Coordinación | P0 | Conectar GitHub | Repo privado con `main` protegido y CI de lint y build en verde |
| 0.2 | Habilitar descarga de la CNE y registrar 14 días | Datos | P0 | Permiso de red | Informe con disponibilidad, número de estaciones, campos y calidad |
| 0.3 | Confirmar licencia de los datos de la CNE | Producto | P0 | n/a | Licencia citada con enlace o solicitud enviada (con autorización) |
| 0.4 | Modelo de datos y migraciones PostGIS | Backend | P0 | 0.2 | Migraciones aplicadas en local; consultas por área probadas |
| 0.5 | Wireframes de los 7 recorridos y sistema visual inicial | Diseño | P0 | n/a | Aprobados por Guillermo |
| 0.6 | Plan de eventos de analítica | Producto | P1 | n/a | Cada evento con propósito, propiedades y datos prohibidos |
| 0.7 | Borrador de aviso de privacidad y términos | Calidad y privacidad | P1 | n/a | Listo para revisión profesional |
| 0.8 | Revisión de competidores | Producto | P2 | n/a | Tabla con 5 alternativas y diferencias |
