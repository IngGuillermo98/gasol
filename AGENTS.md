# AGENTS.md: reglas compartidas para todos los agentes de Gasol

1. **Fuente de verdad:** la carpeta `docs/`. No dependas de memoria de otros chats. Lee `docs/06-estado.md` al empezar y actualízalo al terminar.
2. **Idioma:** documentos y mensajes a Guillermo en español claro. Código, nombres de tablas y commits en inglés.
3. **Propiedad de archivos:** cada rol modifica solo sus rutas (ver `docs/05-roles-y-chats.md`). Si necesitas tocar otra ruta, pídelo a Coordinación.
4. **Datos:** nunca muestres datos ficticios como reales. Todo precio lleva fuente, fecha y estado. Los datos de demostración se marcan `is_demo = true` y no llegan a producción.
5. **Seguridad:** nunca escribas claves, contraseñas ni datos personales en código, docs, registros o chats. Usa `.env.local` (ignorado por git) y los gestores de secretos del proveedor.
6. **Permisos:** se aplican en servidor y en la base de datos (RLS). Una comprobación solo en el cliente no cuenta.
7. **Decisiones:** toda decisión de tecnología, datos o política se registra en `docs/02-decisiones.md` con fecha, razón y alternativa.
8. **Entregas:** una tarea está terminada solo con su criterio de aceptación verificado (prueba, comando o captura), sin pasos manuales ocultos. Di qué es demostración visual y qué está conectado y probado.
9. **Gasto y publicación:** no contrates servicios, gastes dinero, publiques la app ni campañas sin autorización expresa de Guillermo.
10. **Comandos:** `pnpm --dir web lint`, `pnpm --dir web build`, `pnpm --dir web test` (cuando exista). Deben pasar antes de abrir un PR.
