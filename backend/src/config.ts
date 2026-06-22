import 'dotenv/config';

export const config = {
  port: Number(process.env.PORT ?? 3001),
  pg: {
    host: process.env.PGHOST ?? 'localhost',
    port: Number(process.env.PGPORT ?? 55432),
    user: process.env.PGUSER ?? 'postgres',
    password: process.env.PGPASSWORD ?? 'postgres',
    database: process.env.PGDATABASE ?? 'kbbs2',
  },
  corsOrigin: process.env.CORS_ORIGIN ?? 'http://localhost:5173',
};
