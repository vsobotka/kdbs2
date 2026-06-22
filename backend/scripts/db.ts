import { readFile } from 'node:fs/promises';
import { pool } from '../src/db.js';

const file = process.argv[2];
const sql = await readFile(file, 'utf8');
await pool.query(sql);
console.log(`✔ ran ${file}`);
await pool.end();

