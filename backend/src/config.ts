import 'dotenv/config';

// Single place that reads the environment. Defaults match the bundled
// docker-compose database, so the app runs even without a .env file.
export const config = {
  port: Number(process.env.PORT ?? 3001),
  corsOrigin: process.env.CORS_ORIGIN ?? 'http://localhost:5173',
  pg: {
    host: process.env.PGHOST ?? 'localhost',
    port: Number(process.env.PGPORT ?? 55432),
    database: process.env.PGDATABASE ?? 'kdbs2',
    // App runtime: limited, non-superuser role.
    user: process.env.PGUSER ?? 'burza_app',
    password: process.env.PGPASSWORD ?? 'burza_app_pw',
    // Migrations only (db:reset): superuser.
    adminUser: process.env.PGADMINUSER ?? 'postgres',
    adminPassword: process.env.PGADMINPASSWORD ?? 'postgres',
  },
};
