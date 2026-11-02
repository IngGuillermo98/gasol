# Herramientas: disponibles y faltantes

Revisión del 2 nov 2026.

## Disponibles y probadas en el entorno de trabajo de Claude
| Herramienta | Versión | Uso |
|---|---|---|
| Node.js | 22.23 | Ejecutar Next.js |
| pnpm | 10.28 | Gestor de paquetes |
| git | 2.43 | Control de versiones (repositorio local creado) |
| PostgreSQL (cliente psql) | 16.15 | Consultas a la BD |
| Python | 3.13 | Scripts de análisis de datos |
| Chromium + Playwright | 1.64 | Pruebas de recorridos móviles |
| Búsqueda web | n/a | Investigación |

Esqueleto instalado en `web/`: Next.js 16.4.4, React 19.3, Tailwind 4.3.3, TypeScript 5.9.3, MapLibre 6.16.0, supabase-js 2.118.0, @supabase/ssr 0.12.7, Zod 4.6.7, Vitest 5.1.0, Playwright 1.64.1, Supabase CLI 3.0.0. `pnpm build` y `pnpm lint` pasan.

## Limitaciones encontradas
- **GitHub:** no hay cuenta conectada, por eso el código vive por ahora en la carpeta compartida del proyecto. El entorno es temporal: sin repositorio, el trabajo local puede perderse.
- **Red:** la política de red del entorno bloquea la descarga directa de `publicacionexterna.azurewebsites.net` (CNE).
- **Docker:** el cliente existe pero el servicio no corre, así que no se puede levantar Supabase local con `supabase start`. Alternativa: proyecto Supabase gratuito de desarrollo.
- **Conectores:** ninguno conectado.

## Faltantes (las cuentas se abren a tu nombre; tú inicias sesión, nunca compartes contraseñas)
| Herramienta | Para qué | Costo inicial | Cuándo |
|---|---|---|---|
| GitHub (repositorio privado `gasol`) | Código, tareas, revisión | $0 | Ya (fase 0) |
| Permiso de red para la CNE | Descargar datos oficiales | $0 | Ya (fase 0) |
| Supabase (proyecto de desarrollo, plan Free) | BD, Auth | $0 | Fase 0 a 1 |
| Vercel (Hobby, privado) | Vistas previas | $0 | Fase 1 |
| MapTiler (Free, clave restringida por dominio) | Teselas y búsqueda | $0 | Fase 1 |
| Sentry y PostHog (gratuitos) | Errores y analítica | $0 | Fase 1 a 3 |
| Dominio | Lanzamiento | ≈ 500 a 900 MXN/año | Antes del piloto, con autorización |
