import { readFile } from 'node:fs/promises';
import pg from 'pg';
import { config } from '../src/config.js';

// Override credentials, migrations require superuser while the app uses regular user
const pool = new pg.Pool({
  host: config.pg.host,
  port: config.pg.port,
  database: config.pg.database,
  user: config.pg.adminUser,
  password: config.pg.adminPassword,
});

const file = process.argv[2];
const sql = await readFile(file, 'utf8');
await pool.query(sql);
console.log(`✔ ran ${file}`);
await pool.end();
