import pg from 'pg';
import { config } from './config.js';

export const pool = new pg.Pool({
  host: config.pg.host,
  port: config.pg.port,
  user: config.pg.user,
  password: config.pg.password,
  database: config.pg.database,
});

pool.on('error', (err) => console.error('PG pool error', err));
