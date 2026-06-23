import 'dotenv/config';

export const config = {
  port: Number(process.env.PORT ?? 3001),
  pg: {
    host: process.env.PGHOST ?? 'localhost',
    port: Number(process.env.PGPORT ?? 55432),
    user: process.env.PGUSER ?? 'burza_app',
    password: process.env.PGPASSWORD ?? 'burza_app_pw',
    database: process.env.PGDATABASE ?? 'kbbs2',
  },
  corsOrigin: process.env.CORS_ORIGIN ?? 'http://localhost:5173',
};
