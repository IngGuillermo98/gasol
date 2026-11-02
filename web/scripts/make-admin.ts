// Da rol de administrador (moderación) a una cuenta existente. Uso: pnpm make-admin correo@ejemplo.com
import pg from "pg";

const email = process.argv[2];
if (!email) {
  console.error("Uso: pnpm make-admin correo@ejemplo.com");
  process.exit(1);
}
const client = new pg.Client({
  connectionString: process.env.DATABASE_URL ?? "postgresql://postgres:postgres@127.0.0.1:54322/postgres",
});
await client.connect();
const res = await client.query(
  `update profiles set role = 'admin' where user_id = (select id from auth.users where email = lower($1)) returning user_id`,
  [email],
);
await client.end();
if (res.rowCount === 0) {
  console.error(`No existe una cuenta con ${email}. Inicia sesión una vez en la app y vuelve a intentarlo.`);
  process.exit(1);
}
console.log(`${email} ahora es administrador.`);
