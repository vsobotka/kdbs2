import express from 'express';
import cors from 'cors';
import { config } from './config.js';
import { pool } from './db.js';

const app = express();

app.use(cors({ origin: config.corsOrigin }));
app.use(express.json());

app.get('/api/health', async (_req, res) => {
  try {
    const { rows } = await pool.query<{ now: Date }>('SELECT NOW() as now');
    res.json({ ok: true, db: rows[0]?.now });
  } catch (err) {
    res.status(500).json({ ok: false, error: (err as Error).message });
  }
});

app.get('/api/commodities', async (_req, res) => {
  try {
    const { rows } = await pool.query(
      'SELECT id, symbol, name, unit FROM commodity ORDER BY symbol'
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ ok: false, error: (err as Error).message });
  }
});

app.post('/api/orders', async (req, res) => {
  const { commodityId, userId, side, quantity, price } = req.body;
  try {
    const { rows } = await pool.query(
      `INSERT INTO trade_order (commodity_id, user_id, side, quantity, price)
       VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [commodityId, userId, side, quantity, price]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    // CHECK / foreign-key violations land here (pg error codes start '23')
    res.status(400).json({ error: (err as Error).message });
  }
});

app.post('/api/login', async (req, res) => {
  const { username, password } = req.body;
  try {
    const { rows } = await pool.query(
      `SELECT id FROM app_user
        WHERE username = $1
          AND password_hash = crypt($2, password_hash)`,   // ← verify in SQL
      [username, password]
    );
    if (rows.length === 0)
      return res.status(401).json({ error: 'Invalid credentials' });   // generic on purpose

    const { rows: s } = await pool.query(
      `INSERT INTO session (user_id) VALUES ($1) RETURNING id, expires_at`,
      [rows[0].id]
    );
    res.json({ token: s[0].id, expiresAt: s[0].expires_at });
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
});

app.get('/api/me', async (req, res) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'no session' });
  try {
    const { rows } = await pool.query(
      `SELECT u.id, u.username, u.balance
         FROM session s
         JOIN app_user u ON u.id = s.user_id
        WHERE s.id = $1 AND s.expires_at > now()`,        // ← join + expiry check
      [token]
    );
    if (rows.length === 0) return res.status(401).json({ error: 'invalid session' });
    res.json(rows[0]);
  } catch (err) { res.status(500).json({ error: (err as Error).message }); }
});

app.post('/api/logout', async (req, res) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (token) await pool.query('DELETE FROM session WHERE id = $1', [token]);  // revoke
  res.json({ ok: true });
});

app.get('/api/commodities/:symbol', async (req, res) => {
  try {
    const { rows } = await pool.query(
      'SELECT id, symbol, name, unit FROM commodity WHERE symbol = $1',
      [req.params.symbol]
    );
    if (rows.length === 0) return res.status(404).json({ error: 'not found' });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
});

app.get('/api/orders/:symbol', async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT o.id, o.side, o.quantity, o.price, o.created_at
        FROM trade_order o
        JOIN commodity c ON o.commodity_id = c.id
        WHERE c.symbol = $1
        ORDER BY o.price asc
      `, [req.params.symbol]);
    if (rows.length === 0) return res.status(404).json({ error: 'no orders' });
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
})

app.listen(config.port, () => {
  console.log(`backend listening on http://localhost:${config.port}`);
});
