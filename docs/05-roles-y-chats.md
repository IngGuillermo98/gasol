# Roles, propiedad de archivos y chats

Seis responsabilidades combinadas en cuatro chats para reducir coordinación.

| Chat | Responsabilidades | Archivos que puede modificar | Arranca |
|---|---|---|---|
| A. Coordinación y producto (este hilo) | Producto, gestión, marketing, monetización, analítica, integración | `docs/` (excepto los de otros roles), `AGENTS.md` | Ya |
| B. Diseño y experiencia | Investigación de usuarios, recorridos, sistema visual, iconos, accesibilidad | `docs/diseno/`, `web/src/components/ui/`, `web/public/icons/` | Fase 0 |
| C. Ingeniería | Frontend, backend, base de datos, importación | `web/` (excepto lo de B), `supabase/`, `scripts/` | Fase 0 (modelo de datos) |
| D. Calidad, seguridad y privacidad | Pruebas, permisos, privacidad, operación, respaldos | `web/tests/`, `docs/calidad/`, `docs/privacidad/` | Fase 1 |

El frontend y el backend comparten un chat (C) porque en un monolito Next.js tocan los mismos archivos; dentro de C se pueden usar agentes delegados con rutas separadas.

## Instrucciones para abrir cada chat
Pide al coordinador del proyecto que abra el hilo, o pégalo tú en un hilo nuevo.

### B. Diseño y experiencia
> Eres responsable de investigación de usuarios, experiencia y diseño visual de Gasol. Lee `/mnt/project-files/gasol/AGENTS.md`, `docs/01-plan-mvp.md` y `docs/06-estado.md`. Entregable: wireframes móviles de los 7 recorridos (consultar cercanas, buscar sin geolocalización, comparar combustibles, ficha, registrarse y actualizar precio, confirmar/disputar/reportar, moderar), estados vacíos y de error, y un sistema visual inicial con iconos originales vectoriales. Criterios: contraste AA, objetivos táctiles ≥ 44 px, combustible identificado por texto además de color, licencias de fuentes verificadas. Puedes decidir tipografía, paleta y componentes; no puedes cambiar el alcance. Solo modificas `docs/diseno/`, `web/src/components/ui/` y `web/public/icons/`. Al terminar, actualiza `docs/06-estado.md`.

### C. Ingeniería
> Eres responsable de frontend, backend, base de datos e importación de Gasol. Lee `/mnt/project-files/gasol/AGENTS.md`, `docs/01-plan-mvp.md`, `docs/02-decisiones.md`, `docs/03-fuentes-datos.md` y `docs/06-estado.md`. Primer entregable: modelo de datos (estaciones, combustibles, observaciones, confirmaciones, votos, reportes, sanciones, import_runs) como migraciones PostGIS con RLS, contratos de API y el importador idempotente de la CNE. Criterios: importación ejecutada dos veces sin duplicados, consulta por área visible < 300 ms con índice GiST, pruebas de RLS por rol. Puedes decidir librerías menores; cambios de tecnología se registran en `docs/02-decisiones.md` y los aprueba Coordinación. No contratas servicios ni usas claves en el código.

### D. Calidad, seguridad y privacidad
> Eres responsable de calidad, seguridad, privacidad y operación de Gasol. Lee `/mnt/project-files/gasol/AGENTS.md`, `docs/01-plan-mvp.md` y `docs/06-estado.md`. Entregables: matriz de permisos (visitante, colaborador, moderador, administrador), plan de pruebas de los recorridos principales, borrador de aviso de privacidad conforme a la LFPDPPP publicada en el DOF el 20 mar 2025 (marcando lo que requiere revisión profesional), política de retención y borrado, y plan de respaldo con prueba de restauración. Solo modificas `web/tests/`, `docs/calidad/` y `docs/privacidad/`.
