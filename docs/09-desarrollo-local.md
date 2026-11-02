# Correr Gasol en tu computadora

Todo es gratuito y local. No se crea ninguna cuenta en servicios externos.

## Requisitos (una sola vez)
1. **Docker Desktop** (gratuito para uso personal): https://www.docker.com/products/docker-desktop/ Ábrelo y espera a que diga "running".
2. **Node.js 22 o más reciente** y **pnpm 10**: `npm install -g pnpm@10`.
3. Clonar el repositorio: `git clone https://github.com/IngGuillermo98/gasol.git` y entrar a la carpeta.

## Arrancar
```bash
pnpm --dir web install
pnpm --dir web exec supabase start      # base de datos, autenticación y correo de prueba (la primera vez tarda unos minutos)
pnpm --dir web import:cne               # carga el catálogo real de estaciones de la CNE (~15,000)
cp web/.env.example web/.env.local      # claves locales de desarrollo, no son secretas
pnpm --dir web dev                      # abre http://localhost:3000
```

- Correos de inicio de sesión: http://127.0.0.1:54324 (buzón de prueba local; no se envía nada a internet).
- Volverte moderador: `pnpm --dir web make-admin tu@correo.com` después de iniciar sesión una vez.
- Apagar: `pnpm --dir web exec supabase stop`.

## Pruebas
```bash
pnpm --dir web lint && pnpm --dir web test && pnpm --dir web build
pnpm --dir web exec supabase test db    # permisos y reglas de aportes en la base de datos
```
