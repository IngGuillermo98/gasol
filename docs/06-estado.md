# Estado actual y próximos pasos

Última actualización: 2 nov 2026, hilo "Planificar MVP de Gasol y herramientas".

## Listo
- Contexto revisado: el prompt maestro es `Gasol.txt` en la carpeta compartida.
- Plan del MVP v0.1 (`01-plan-mvp.md`), decisiones (`02`), fuentes (`03`), herramientas (`04`), roles y chats (`05`).
- Esqueleto `web/` instalado y compilado (build y lint en verde). Solo la página inicial de Next.js; no hay funciones de Gasol aún.
- `AGENTS.md` con reglas para todos los agentes.

## Bloqueado por acciones de Guillermo
1. Conectar GitHub y crear el repositorio privado `gasol` (después Claude sube el esqueleto y los docs).
2. Permitir en el entorno de nube el dominio `publicacionexterna.azurewebsites.net` (descarga de datos de la CNE).

## Preguntas abiertas para Guillermo
1. ¿Qué ciudad o zona metropolitana usamos como piloto, y confirmas el segmento de conductores de alto kilometraje urbano?
2. ¿Cuál es el tope de gasto mensual para el piloto? (propuesta: hasta 2,000 MXN/mes) ¿Y hay presupuesto para revisión legal única (8,000 a 25,000 MXN)?
3. ¿Quién modera durante el piloto y cuántas horas por semana?
4. ¿Gasol opera como persona física o como empresa? (define titular de cuentas, aviso de privacidad y facturación)
5. ¿Ya tienes dominio o registro de marca para "Gasol"?

## Siguiente
- Al tener red: 14 días de descargas de la CNE e informe de calidad (tarea 0.2).
- Al tener repo: subir código, CI de lint y build (0.1).
- Sin depender de nada: modelo de datos (0.4), plan de eventos (0.6), revisión de competidores (0.8).

## Avance posterior (2 nov 2026)
- Borrador del modelo de datos en `supabase/migrations/20261102000000_init.sql` (tarea 0.4, sin aplicar: falta Docker o un proyecto Supabase de desarrollo para probarlo). Pendiente: políticas de moderador, límites de frecuencia y función de "precio mostrado".
